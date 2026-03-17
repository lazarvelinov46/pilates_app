import { onDocumentUpdated } from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";

admin.initializeApp();

const db = admin.firestore();

// Triggered whenever a session document is updated.
// When active flips true → false (admin cancels), this:
//   1. Marks every active booking as 'cancelled_by_admin'
//   2. Refunds the credit (promotion.booked -= 1) — always, no 12h restriction
//   3. Sends an FCM push to each affected user
export const onSessionCancelled = onDocumentUpdated(
  "sessions/{sessionId}",
  async (event) => {
    const before = event.data?.before?.data();
    const after  = event.data?.after?.data();

    if (!before || !after) return null;

    // Only react when active flips true → false
    if (before.active !== true || after.active !== false) return null;

    const sessionId = event.params.sessionId;

    const bookingsSnap = await db
      .collection("bookings")
      .where("sessionId", "==", sessionId)
      .where("status", "==", "active")
      .get();

    if (bookingsSnap.empty) return null;

    // ── Batch: cancel bookings + refund credits ───────────────────────────
    // Firestore hard limit is 500 writes per batch; keep chunks safe at 200.
    const CHUNK = 200;
    const docs = bookingsSnap.docs;

    for (let i = 0; i < docs.length; i += CHUNK) {
      const batch = db.batch();
      const chunk = docs.slice(i, i + CHUNK);

      for (const bookingDoc of chunk) {
        const { userId } = bookingDoc.data() as { userId: string };

        // Mark booking as admin-cancelled (different from user self-cancel)
        batch.update(bookingDoc.ref, {
          status: "cancelled_by_admin",
          cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
          cancelledByAdmin: true,
        });

        // Always refund the credit — admin cancellations have no time restriction
        batch.update(db.collection("users").doc(userId), {
          "promotion.booked": admin.firestore.FieldValue.increment(-1),
        });
      }

      await batch.commit();
    }

    // ── FCM: notify each affected user ────────────────────────────────────
    const sessionDate: Date = after.startsAt?.toDate
      ? after.startsAt.toDate()
      : new Date();

    const formattedDate = sessionDate.toLocaleDateString("en-GB", {
      weekday: "short",
      day: "2-digit",
      month: "short",
    });
    const formattedTime = sessionDate.toLocaleTimeString("en-GB", {
      hour: "2-digit",
      minute: "2-digit",
    });

    const messaging = admin.messaging();

    for (const bookingDoc of docs) {
      const { userId } = bookingDoc.data() as { userId: string };
      const userSnap = await db.collection("users").doc(userId).get();
      const fcmToken: string | undefined = userSnap.data()?.fcmToken;
      if (!fcmToken) continue;

      try {
        await messaging.send({
          token: fcmToken,
          notification: {
            title: "Session Cancelled",
            body:
              `Your session on ${formattedDate} at ${formattedTime} has been ` +
              `cancelled by the studio. Your credit has been refunded.`,
          },
          android: { priority: "high" },
          apns: { payload: { aps: { sound: "default" } } },
        });
      } catch (err) {
        console.error(`FCM send failed for user ${userId}:`, err);
      }
    }

    return null;
  }
);