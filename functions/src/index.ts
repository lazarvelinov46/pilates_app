import * as admin from "firebase-admin";
import {onSchedule} from "firebase-functions/v2/scheduler";

admin.initializeApp();

/**
 * Runs every 60 minutes.
 * Sends reminder 1 hour before session.
 * Sends only once (uses reminderSent flag).
 */
export const sessionReminder = onSchedule(
  {
    schedule: "every 60 minutes",
    timeZone: "Europe/Zagreb", // 🔁 CHANGE to your timezone
  },
  async () => {
    const now = new Date();
    const inOneHour = new Date(now.getTime() + 60 * 60 * 1000);

    const bookingsSnap = await admin.firestore()
      .collection("bookings")
      .where("status", "==", "active")
      .where("reminderSent", "==", false)
      .get();

    for (const doc of bookingsSnap.docs) {
      const data = doc.data();

      if (!data.sessionStartsAt) continue;

      const sessionTime = data.sessionStartsAt.toDate();

      if (sessionTime > now && sessionTime <= inOneHour) {
        const userSnap = await admin.firestore()
          .collection("users")
          .doc(data.userId)
          .get();

        const userData = userSnap.data();

        if (!userData?.fcmToken) continue;

        await admin.messaging().send({
          token: userData.fcmToken,
          notification: {
            title: "Upcoming Pilates Session",
            body: "Your session starts in one hour.",
          },
        });

        // ✅ Mark reminder as sent
        await doc.ref.update({reminderSent: true});

        console.log(`Reminder sent for booking ${doc.id}`);
      }
    }
  }
);
