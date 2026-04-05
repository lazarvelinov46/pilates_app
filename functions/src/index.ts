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
    if (before.active !== true || after.active !== false) return null;

    const sessionId = event.params.sessionId;

    const bookingsSnap = await db
      .collection("bookings")
      .where("sessionId", "==", sessionId)
      .where("status", "==", "active")
      .get();

    if (bookingsSnap.empty) return null;

    const docs = bookingsSnap.docs;

    const refundPromises = docs.map(async (bookingDoc) => {
      const bookingData = bookingDoc.data() as Record<string, unknown>;
      const userId = bookingData.userId as string;
      const userRef = db.collection("users").doc(userId);
      const isTrialBooking = bookingData.isTrialBooking === true;

      await db.runTransaction(async (tx) => {
        const userSnap = await tx.get(userRef);
        if (!userSnap.exists) return;

        const userData = userSnap.data() as Record<string, unknown>;

        // Cancel the booking.
        tx.update(bookingDoc.ref, {
          status: "cancelled_by_admin",
          cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
          cancelledByAdmin: true,
        });

        const promoCreatedAtTs =
          bookingData.promotionCreatedAt instanceof
          admin.firestore.Timestamp
            ? (bookingData.promotionCreatedAt as admin.firestore.Timestamp)
            : null;

        // ── Trial booking not yet absorbed by a promotion ────────────────
        if (isTrialBooking && !promoCreatedAtTs) {
          // Reset the trial slot so the user can book again.
          tx.update(userRef, {trialSessionUsed: false});
          return;
        }

        // ── Normal refund path (also covers absorbed trial bookings) ──────
        if (promoCreatedAtTs) {
          const targetMs = promoCreatedAtTs.toMillis();

          // First, try to find the promotion in the active promotions array.
          if (Array.isArray(userData.promotions)) {
            const promotions = (
              userData.promotions as Record<string, unknown>[]
            ).map((p) => ({...p}));

            const idx = promotions.findIndex(
              (p) =>
                p.createdAt instanceof admin.firestore.Timestamp &&
                (p.createdAt as admin.firestore.Timestamp).toMillis() ===
                  targetMs
            );

            if (idx !== -1) {
              const current = (promotions[idx].booked as number) ?? 0;
              promotions[idx].booked = Math.max(0, current - 1);
              tx.update(userRef, {promotions});
              return;
            }
          }

          // Promotion not found in active list — it may have been archived to
          // promotionHistory (happens when a promotion is expired AND fully
          // booked/attended at the time syncAttendedSessions runs, even if a
          // future session is still booked). Move it back and refund.
          if (Array.isArray(userData.promotionHistory)) {
            const history = (
              userData.promotionHistory as Record<string, unknown>[]
            ).map((p) => ({...p}));

            const idx = history.findIndex(
              (p) =>
                p.createdAt instanceof admin.firestore.Timestamp &&
                (p.createdAt as admin.firestore.Timestamp).toMillis() ===
                  targetMs
            );

            if (idx !== -1) {
              const current = (history[idx].booked as number) ?? 0;
              const restored = {
                ...history[idx],
                booked: Math.max(0, current - 1),
              };
              history.splice(idx, 1);

              const activePromotions = Array.isArray(userData.promotions)
                ? (
                    userData.promotions as Record<string, unknown>[]
                  ).map((p) => ({...p}))
                : [];
              activePromotions.push(restored);

              tx.update(userRef, {
                promotions: activePromotions,
                promotionHistory: history,
              });
              return;
            }
          }
        } else if (userData.promotion && !isTrialBooking) {
          // Legacy single-field path.
          tx.update(userRef, {
            "promotion.booked":
              admin.firestore.FieldValue.increment(-1),
          });
        }
      });
    });

    await Promise.all(refundPromises);

    // ── FCM notifications ────────────────────────────────────────────────
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

    const fcmPromises = docs.map(async (bookingDoc) => {
      const {userId} = bookingDoc.data() as {userId: string};
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
      `onSessionCancelled: cancelled ${docs.length} booking(s) ` +
        `for session ${sessionId}`
    );

    return null;
  }
);