/**
 * WhatMeal Cloud Functions
 *
 * Trigger: When a document is created in `users/{uid}/notifications/{notifId}`,
 *   read the user's FCM token(s) from Firestore and send push notification(s).
 *
 * Enhanced features:
 * - Supports multiple device tokens per user
 * - Includes navigation data for deep linking
 * - Removes invalid tokens automatically
 * - Duplicate prevention via notification document idempotency
 *
 * Deploy:
 *   firebase deploy --only functions
 */

const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();

exports.sendPushOnNotification = onDocumentCreated(
  "users/{uid}/notifications/{notifId}",
  async (event) => {
    const uid = event.params.uid;
    const notifId = event.params.notifId;
    const data = event.data?.data();

    if (!data) {
      console.log(`[FCM] No data in notification document for uid=${uid}`);
      return null;
    }

    const title = data.title ?? "WhatMeal";
    const body = data.body ?? "";

    // Extract navigation data for deep linking
    const navigationRoute = data.navigationRoute;
    const navigationParameters = data.navigationParameters;

    // Build FCM data payload for navigation
    const fcmData = {
      route: navigationRoute || "",
      ...(navigationParameters ? navigationParameters : {}),
    };

    // Retrieve the user's FCM tokens from Firestore
    // Support both single token (legacy) and multiple tokens (new)
    const userDoc = await getFirestore()
      .collection("users")
      .doc(uid)
      .get();

    const userData = userDoc.data();
    if (!userData) {
      console.log(`[FCM] No user document for uid=${uid}. Skipping push.`);
      return null;
    }

    // Collect all valid tokens
    let tokens = [];

    // Legacy single token
    if (userData.fcmToken) {
      tokens.push(userData.fcmToken);
    }

    // New multi-device tokens subcollection
    const tokensSnapshot = await getFirestore()
      .collection("users")
      .doc(uid)
      .collection("fcmTokens")
      .get();

    tokensSnapshot.forEach((doc) => {
      const tokenData = doc.data();
      if (tokenData.token) {
        tokens.push(tokenData.token);
      }
    });

    // Remove duplicates
    tokens = [...new Set(tokens)];

    if (tokens.length === 0) {
      console.log(`[FCM] No FCM tokens stored for uid=${uid}. Skipping push.`);
      return null;
    }

    // Build message with navigation data
    const message = {
      notification: { title, body },
      data: fcmData,
      android: {
        notification: {
          channelId: "whatmeal_channel",
          priority: "high",
          sound: "default",
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
    };

    // Send to all tokens
    const sendPromises = tokens.map(async (token) => {
      try {
        const response = await getMessaging().send({ ...message, token });
        console.log(`[FCM] Sent to uid=${uid}, token=${token.substring(0, 10)}...: ${response}`);
        return { success: true, token };
      } catch (err) {
        // If the token is no longer valid, mark it for removal
        if (
          err.code === "messaging/registration-token-not-registered" ||
          err.code === "messaging/invalid-registration-token"
        ) {
          console.log(
            `[FCM] Token invalid for uid=${uid}, will remove: ${token.substring(0, 10)}...`
          );
          return { success: false, token, remove: true };
        } else {
          console.error(`[FCM] Error sending to uid=${uid}:`, err);
          return { success: false, token, remove: false };
        }
      }
    });

    const results = await Promise.all(sendPromises);

    // Remove invalid tokens
    const tokensToRemove = results
      .filter((r) => r.remove)
      .map((r) => r.token);

    if (tokensToRemove.length > 0) {
      console.log(`[FCM] Removing ${tokensToRemove.length} invalid tokens for uid=${uid}`);

      // Remove from legacy single token
      if (userData.fcmToken && tokensToRemove.includes(userData.fcmToken)) {
        await getFirestore()
          .collection("users")
          .doc(uid)
          .update({ fcmToken: null });
      }

      // Remove from multi-device subcollection
      const batch = getFirestore().batch();
      const tokensSnapshot = await getFirestore()
        .collection("users")
        .doc(uid)
        .collection("fcmTokens")
        .get();

      tokensSnapshot.forEach((doc) => {
        const tokenData = doc.data();
        if (tokenData.token && tokensToRemove.includes(tokenData.token)) {
          batch.delete(doc.ref);
        }
      });

      await batch.commit();
    }

    console.log(`[FCM] Summary for uid=${uid}: ${results.filter(r => r.success).length} sent, ${tokensToRemove.length} removed`);
    return null;
  }
);
