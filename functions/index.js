const logger = require("firebase-functions/logger");
const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {initializeApp} = require("firebase-admin/app");
const {getMessaging} = require("firebase-admin/messaging");

initializeApp();

function announcementTopicForClub(clubId) {
  const cleaned = String(clubId)
      .trim()
      .toLowerCase()
      .replace(/[^a-z0-9\-_.~%]/g, "_");
  const normalized = cleaned.length === 0 ? "default" : cleaned;
  return `club_${normalized}_announcements`;
}

function formatScheduledAt(rawValue) {
  if (!rawValue) {
    return "";
  }

  const scheduledAt = new Date(rawValue);
  if (Number.isNaN(scheduledAt.getTime())) {
    return "";
  }

  return new Intl.DateTimeFormat("en-US", {
    weekday: "short",
    month: "short",
    day: "numeric",
    hour: "numeric",
    minute: "2-digit",
  }).format(scheduledAt);
}

exports.sendAnnouncementNotification = onDocumentCreated(
    {
      document: "announcements/{announcementId}",
      region: "us-central1",
      retry: false,
    },
    async (event) => {
      const snapshot = event.data;
      if (!snapshot) {
        logger.warn("Announcement trigger fired without snapshot data.");
        return;
      }

      const announcement = snapshot.data();
      const clubId = announcement.clubId;
      const title = String(announcement.title || "").trim();
      if (!clubId || !title) {
        logger.warn("Announcement missing clubId or title.", {
          announcementId: snapshot.id,
          clubId,
          title,
        });
        return;
      }

      const bodyParts = [];
      const scheduledLabel = formatScheduledAt(announcement.scheduledAt);
      const location = String(announcement.location || "").trim();

      if (scheduledLabel) {
        bodyParts.push(scheduledLabel);
      }
      if (location) {
        bodyParts.push(location);
      }

      const body = bodyParts.length > 0
          ? bodyParts.join(" • ")
          : "Open Rally Club to view the latest play details.";

      const topic = announcementTopicForClub(clubId);

      await getMessaging().send({
        topic,
        notification: {
          title,
          body,
        },
        data: {
          type: "announcement",
          announcementId: snapshot.id,
          clubId: String(clubId),
          title,
          body,
          location,
          scheduledAt: String(announcement.scheduledAt || ""),
        },
        android: {
          priority: "high",
          notification: {
            tag: snapshot.id,
          },
        },
        apns: {
          headers: {
            "apns-priority": "10",
          },
          payload: {
            aps: {
              sound: "default",
              badge: 1,
              category: "announcement",
            },
          },
        },
      });

      logger.info("Announcement notification sent.", {
        announcementId: snapshot.id,
        clubId,
        topic,
      });
    },
);