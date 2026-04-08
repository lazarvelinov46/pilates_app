import {onDocumentCreated, onDocumentUpdated} from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";

admin.initializeApp();

const db = admin.firestore();

// ─────────────────────────────────────────────────────────────────────────────
// Helper: write a notification document to users/{userId}/notifications
// ─────────────────────────────────────────────────────────────────────────────
async function storeNotification(
  userId: string,
  title: string,
  message: string,
  type: string
): Promise<void> {
  await db
    .collection("users")
    .doc(userId)
    .collection("notifications")
    .add({
      title,
      message,
      type,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      isRead: false,
    });
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper: send an FCM push if the user has notifications enabled and an FCM
// token stored. Silently skips if not.
// ─────────────────────────────────────────────────────────────────────────────
async function sendFCM(
  userId: string,
  title: string,
  body: string
): Promise<void> {
  const userSnap = await db.collection("users").doc(userId).get();
  const userData = userSnap.data();
  if (!userData) return;

  // Respect user preferences.
  const notificationsEnabled =
    userData?.preferences?.notifications !== false; // default true
  if (!notificationsEnabled) return;

  const fcmToken: string | undefined = userData?.fcmToken;
  if (!fcmToken) return;

  try {
    await admin.messaging().send({
      token: fcmToken,
      notification: {title, body},
      android: {priority: "high"},
      apns: {payload: {aps: {sound: "default"}}},
    });
  } catch (err) {
    console.error(`FCM send failed for user ${userId}:`, err);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Trigger: new booking created → send FCM push confirmation.
//
// The client already writes the in-app notification document immediately after
// booking, so this function only sends the FCM push (works on Spark plan
// because FCM is a Firebase/Google service).
// ─────────────────────────────────────────────────────────────────────────────
export const onBookingCreated = onDocumentCreated(
  "bookings/{bookingId}",
  async (event) => {
    const data = event.data?.data();
    if (!data) return null;

    // Only notify for new active bookings (skip admin-created test docs, etc.).
    if (data.status !== "active") return null;

    const userId = data.userId as string;
    const sessionStartsAt: Date = data.sessionStartsAt?.toDate
      ? data.sessionStartsAt.toDate()
      : new Date();

    const formattedDate = sessionStartsAt.toLocaleDateString("en-GB", {
      weekday: "short",
      day: "2-digit",
      month: "short",
    });
    const formattedTime = sessionStartsAt.toLocaleTimeString("en-GB", {
      hour: "2-digit",
      minute: "2-digit",
    });

    await sendFCM(
      userId,
      "Booking confirmed",
      `Your session on ${formattedDate} at ${formattedTime} is confirmed.`
    );

    console.log(`onBookingCreated: notified user ${userId}`);
    return null;
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// Trigger: session cancelled by admin (active → false).
//
// 1. Marks every active booking as 'cancelled_by_admin' and refunds credits.
// 2. Writes a notification doc to each user's notifications subcollection.
// 3. Sends an FCM push to each affected user.
// ─────────────────────────────────────────────────────────────────────────────
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

    // ── 1. Cancel bookings and refund credits ───────────────────────────────
    const refundPromises = docs.map(async (bookingDoc) => {
      const bookingData = bookingDoc.data() as Record<string, unknown>;
      const userId = bookingData.userId as string;
      const userRef = db.collection("users").doc(userId);
      const isTrialBooking = bookingData.isTrialBooking === true;

      await db.runTransaction(async (tx) => {
        const userSnap = await tx.get(userRef);
        if (!userSnap.exists) return;

        const userData = userSnap.data() as Record<string, unknown>;

        tx.update(bookingDoc.ref, {
          status: "cancelled_by_admin",
          cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
          cancelledByAdmin: true,
        });

        const promoCreatedAtTs =
          bookingData.promotionCreatedAt instanceof admin.firestore.Timestamp
            ? (bookingData.promotionCreatedAt as admin.firestore.Timestamp)
            : null;

        // Trial booking not yet absorbed by a promotion.
        if (isTrialBooking && !promoCreatedAtTs) {
          tx.update(userRef, {trialSessionUsed: false});
          return;
        }

        if (promoCreatedAtTs) {
          const targetMs = promoCreatedAtTs.toMillis();

          // Try active promotions array first.
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

          // Fall back to promotionHistory (promotion was archived).
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
            "promotion.booked": admin.firestore.FieldValue.increment(-1),
          });
        }
      });
    });

    await Promise.all(refundPromises);

    // ── 2. Format session date/time for notification messages ───────────────
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

    const notifTitle = "Session Cancelled";
    const notifBody =
      `Your session on ${formattedDate} at ${formattedTime} has been ` +
      "cancelled by the studio. Your credit has been refunded.";

    // ── 3. Write in-app notification + send FCM push to each affected user ──
    const notifyPromises = docs.map(async (bookingDoc) => {
      const {userId} = bookingDoc.data() as {userId: string};

      // Check preferences and send FCM (helper reads the user doc once).
      await sendFCM(userId, notifTitle, notifBody);

      // Always write the in-app notification (user can see it in the app
      // even if push notifications are disabled).
      await storeNotification(userId, notifTitle, notifBody, "sessionCancelled");
    });

    await Promise.all(notifyPromises);

    console.log(
      `onSessionCancelled: cancelled ${docs.length} booking(s) for session ${sessionId}`
    );

    return null;
  }
);

// ─────────────────────────────────────────────────────────────────────────────
// BLAZE PLAN ONLY — 2-hour reminder via Cloud Tasks
//
// Uncomment when you upgrade to the Blaze (pay-as-you-go) plan.
// This sends a server-side FCM reminder 2 hours before each session,
// which is more reliable than the client-side local notification used now.
//
// Steps to enable:
//   1. Upgrade to Blaze plan in Firebase console.
//   2. Enable the Cloud Tasks API in Google Cloud Console.
//   3. Uncomment the code below.
//   4. Run: firebase deploy --only functions
//
// import {onDocumentCreated as _onDocumentCreated} from "firebase-functions/v2/firestore";
// import {CloudTasksClient} from "@google-cloud/tasks";
//
// export const scheduleSessionReminder = _onDocumentCreated(
//   "bookings/{bookingId}",
//   async (event) => {
//     const data = event.data?.data();
//     if (!data || data.status !== "active") return null;
//
//     const userId = data.userId as string;
//     const sessionStartsAt: admin.firestore.Timestamp = data.sessionStartsAt;
//     const reminderTime = new Date(sessionStartsAt.toMillis() - 2 * 60 * 60 * 1000);
//     if (reminderTime <= new Date()) return null; // Already past
//
//     const tasksClient = new CloudTasksClient();
//     const project = process.env.GCLOUD_PROJECT!;
//     const queue = "session-reminders";
//     const location = "europe-west1"; // adjust to your region
//     const parent = tasksClient.queuePath(project, location, queue);
//
//     // The task payload calls the sendReminderFCM HTTP function below.
//     await tasksClient.createTask({
//       parent,
//       task: {
//         scheduleTime: {seconds: Math.floor(reminderTime.getTime() / 1000)},
//         httpRequest: {
//           httpMethod: "POST",
//           url: `https://${location}-${project}.cloudfunctions.net/sendReminderFCM`,
//           body: Buffer.from(JSON.stringify({userId, bookingId: event.params.bookingId})).toString("base64"),
//           headers: {"Content-Type": "application/json"},
//         },
//       },
//     });
//
//     return null;
//   }
// );
// ─────────────────────────────────────────────────────────────────────────────
