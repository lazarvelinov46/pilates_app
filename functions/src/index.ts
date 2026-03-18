import {onDocumentUpdated} from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";

admin.initializeApp();

const db = admin.firestore();

// Triggered whenever a session document is updated.
// When active flips true → false (admin cancels), this:
//   1. Marks every active booking as 'cancelled_by_admin'
//   2. Refunds the credit to the correct promotion — always, no 12h restriction
//   3. Sends an FCM push to each affected user
export const onSessionCancelled = onDocumentUpdated(
  "sessions/{sessionId}",
  async (event) => {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();

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

    const docs = bookingsSnap.docs;

    // ── Cancel bookings + refund credits ─────────────────────────────────
    // Each booking gets its own transaction so one bad user doc can't block
    // the rest. Firestore transactions support reads + writes together,
    // which we need to safely update the promotions array.
    const refundPromises = docs.map(async (bookingDoc) => {
      const bookingData = bookingDoc.data() as Record<string, unknown>;
      const userId = bookingData.userId as string;
      const userRef = db.collection("users").doc(userId);

      await db.runTransaction(async (tx) => {
        const userSnap = await tx.get(userRef);
        if (!userSnap.exists) return;

        const userData = userSnap.data() as Record<string, unknown>;

        // Mark booking as cancelled by admin
        tx.update(bookingDoc.ref, {
          status: "cancelled_by_admin",
          cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
          cancelledByAdmin: true,
        });

        // ── Refund to correct promotion ─────────────────────────────────
        const promoCreatedAtTs =
          bookingData.promotionCreatedAt instanceof admin.firestore.Timestamp?
            (bookingData.promotionCreatedAt as admin.firestore.Timestamp):
            null;

        if (Array.isArray(userData.promotions) && promoCreatedAtTs) {
        // New path: find the exact promotion by createdAt and decrement booked.
          const promotions = (
            userData.promotions as Record<string, unknown>[]
          ).map((p) => ({...p}));

          const targetMs = promoCreatedAtTs.toMillis();
          const idx = promotions.findIndex(
            (p) =>
              p.createdAt instanceof admin.firestore.Timestamp &&
              (p.createdAt as admin.firestore.Timestamp).toMillis() === targetMs
          );

          if (idx !== -1) {
            const current = (promotions[idx].booked as number) ?? 0;
            promotions[idx].booked = Math.max(0, current - 1);
            tx.update(userRef, {promotions});
          }
          // If promotion not found by createdAt, booking is still cancelled —
          // the credit is effectively left intact wherever it was.
        } else if (userData.promotion) {
          // Legacy path: single `promotion` field.
          tx.update(userRef, {
            "promotion.booked": admin.firestore.FieldValue.increment(-1),
          });
        }
      });
    });

    await Promise.all(refundPromises);

    // ── FCM: notify each affected user ────────────────────────────────────
    const sessionDate: Date = after.startsAt?.toDate?
      after.startsAt.toDate():
      new Date();

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

    const fcmPromises = docs.map(async (bookingDoc) => {
      const {userId} = bookingDoc.data() as { userId: string };
      const userSnap = await db.collection("users").doc(userId).get();
      const fcmToken: string | undefined = userSnap.data()?.fcmToken;
      if (!fcmToken) return;

      try {
        await messaging.send({
          token: fcmToken,
          notification: {
            title: "Session Cancelled",
            body:
              `Your session on ${formattedDate} at ${formattedTime} has been ` +
              "cancelled by the studio. Your credit has been refunded.",
          },
          android: {priority: "high"},
          apns: {payload: {aps: {sound: "default"}}},
        });
      } catch (err) {
        console.error(`FCM send failed for user ${userId}:`, err);
      }
    });

    await Promise.all(fcmPromises);

    console.log(
      `onSessionCancelled: cancelled ${docs.length}
       booking(s) for session ${sessionId}`
    );

    return null;
  }
);
