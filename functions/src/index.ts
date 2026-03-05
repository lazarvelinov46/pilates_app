import * as admin from "firebase-admin";
import {onDocumentUpdated} from "firebase-functions/v2/firestore";

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

/**
 * Triggered whenever a session document is updated.
 * If the session just became inactive (active: true → false), this function:
 *   1. Finds all active bookings for that session
 *   2. Cancels each booking and refunds the session credit to the user
 *   3. Sends an FCM push notification to each affected user
 *
 * All booking cancellations and credit refunds run inside a single
 * Firestore transaction to keep data consistent.
 */
export const onSessionCancelled = onDocumentUpdated(
  "sessions/{sessionId}",
  async (event) => {
    const before = event.data?.before?.data();
    const after = event.data?.after?.data();

    // Only act when active flips from true → false.
    if (!before || !after) return;
    if (before.active !== true || after.active !== false) return;

    const sessionId = event.params.sessionId;
    const sessionTime: admin.firestore.Timestamp = after.startsAt;
    const sessionDate = sessionTime.toDate();

    const pad = (n: number) => String(n).padStart(2, "0");
    const formattedTime = `${pad(sessionDate.getDate())} 
    ${sessionDate.toLocaleString("en", {month: "short"})} • 
    ${pad(sessionDate.getHours())}:${pad(sessionDate.getMinutes())}`;

    // ── 1. Find all active bookings for this session ──────────────────────
    const bookingsSnap = await db
      .collection("bookings")
      .where("sessionId", "==", sessionId)
      .where("status", "==", "active")
      .get();

    if (bookingsSnap.empty) return;

    // ── 2. Cancel bookings and refund credits in a transaction ────────────
    const affectedUserIds: string[] = [];

    await db.runTransaction(async (tx) => {
      for (const bookingDoc of bookingsSnap.docs) {
        const booking = bookingDoc.data();
        const userId: string = booking.userId;
        const userRef = db.collection("users").doc(userId);

        // Cancel the booking.
        tx.update(bookingDoc.ref, {
          status: "cancelled",
          cancelledAt: admin.firestore.Timestamp.now(),
          cancelledByAdmin: true,
        });

        // Refund the session credit unconditionally — the admin cancelled,
        // so the user is never at fault regardless of timing.
        tx.update(userRef, {
          "promotion.booked": admin.firestore.FieldValue.increment(-1),
        });

        affectedUserIds.push(userId);
      }

      // Decrement bookedCount by exactly the number of active bookings
      // being cancelled — safer than resetting to 0, which would be wrong
      // if any bookings were already cancelled before this point.
      tx.update(db.collection("sessions").doc(sessionId), {
        bookedCount: admin.firestore.FieldValue.increment(-bookingsSnap.size),
      });
    });

    // ── 3. Fetch FCM tokens for affected users and send notifications ─────
    if (affectedUserIds.length === 0) return;

    const userDocs = await Promise.all(
      affectedUserIds.map((uid) => db.collection("users").doc(uid).get())
    );

    const tokens: string[] = userDocs
      .map((doc) => doc.data()?.fcmToken as string | undefined)
      .filter((token): token is string => !!token);

    if (tokens.length === 0) return;

    // sendEachForMulticast is the v12+ replacement for sendMulticast.
    await messaging.sendEachForMulticast({
      tokens,
      notification: {
        title: "Session Cancelled",
        body: `Your session on ${formattedTime} has been cancelled
         by the studio. Your credit has been refunded.`,
      },
      android: {
        notification: {
          channelId: "pilates_sessions",
          priority: "high",
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
          },
        },
      },
    });
  }
);
