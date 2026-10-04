import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/app_notification.dart';
import '../../features/family/data/family_repository.dart';

// ---------------------------------------------------------------------------
// Top-level background message handler (must be a top-level function)
// ---------------------------------------------------------------------------

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase is already initialised before this handler runs.
  debugPrint('[FCM] Background message: ${message.notification?.title}');
}

// ---------------------------------------------------------------------------
// NotificationService
// ---------------------------------------------------------------------------

/// Handles both in-app notification history (Firestore) and device-level
/// push notifications (Firebase Cloud Messaging + flutter_local_notifications).
///
/// Usage:
/// ```dart
/// await NotificationService.instance.initialize();
/// NotificationService.instance.push(uid, title, body, type);
/// ```
class NotificationService extends ValueNotifier<List<AppNotification>> {
  NotificationService._() : super([]) {
    FirebaseAuth.instance.authStateChanges().listen((user) {
      _uid = user?.uid;
      if (_uid != null) {
        _listenToNotifications();
        _refreshFcmToken();
      } else {
        _sub?.cancel();
        _sub = null;
        value = [];
      }
    });
  }

  static final instance = NotificationService._();

  final _firestore = FirebaseFirestore.instance;
  final _messaging = FirebaseMessaging.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();

  String? _uid;
  StreamSubscription? _sub;
  bool _initialized = false;

  List<AppNotification> get notifications => value;

  int get unreadCount => value.where((n) => !n.read).length;

  /// Cleanup FCM tokens on logout
  Future<void> cleanupOnLogout() async {
    final uid = _uid;
    if (uid == null) return;

    try {
      // Remove legacy single token
      await _firestore.collection('users').doc(uid).update({
        'fcmToken': null,
      });

      // Remove all multi-device tokens
      final tokensSnapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('fcmTokens')
          .get();

      final batch = _firestore.batch();
      for (final doc in tokensSnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      debugPrint('[FCM] Tokens cleaned up on logout for $uid');
    } catch (e) {
      debugPrint('[FCM] Failed to cleanup tokens on logout: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // 1. Set up background message handler.
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // 2. Request notification permission.
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('[FCM] Permission: ${settings.authorizationStatus}');

    // 3. Initialise flutter_local_notifications (for foreground display).
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    await _localNotifications.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );

    // 4. Create Android notification channel.
    const channel = AndroidNotificationChannel(
      'whatmeal_channel',
      'WhatMeal Notifications',
      description: 'Alerts for meal plans, pantry, and grocery updates.',
      importance: Importance.high,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // 5. Show foreground FCM messages as local notifications.
    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      if (notification != null) {
        _localNotifications.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              channel.id,
              channel.name,
              channelDescription: channel.description,
              icon: '@mipmap/ic_launcher',
            ),
          ),
        );
      }
    });

    // 6. Handle FCM token refresh.
    _messaging.onTokenRefresh.listen(_saveFcmToken);
  }

  // ---------------------------------------------------------------------------
  // FCM token management
  // ---------------------------------------------------------------------------
  // Note: FCM tokens are saved to Firestore for future use.
  // On Firebase Spark (free) plan, server-side push notifications require Cloud Functions.
  // Current implementation uses Firestore realtime listeners for in-app notifications.
  // Foreground FCM messages are handled client-side via FirebaseMessaging.onMessage.

  Future<void> _refreshFcmToken() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) await _saveFcmToken(token);
    } catch (e) {
      debugPrint('[FCM] Failed to get token: $e');
    }
  }

  Future<void> _saveFcmToken(String token) async {
    final uid = _uid;
    if (uid == null) return;
    try {
      // Store token in multi-device subcollection for future multi-device support
      final tokenDocRef = _firestore
          .collection('users')
          .doc(uid)
          .collection('fcmTokens')
          .doc(token.hashCode.toString());

      await tokenDocRef.set({
        'token': token,
        'updatedAt': FieldValue.serverTimestamp(),
        'platform': 'unknown', // Could be enhanced to detect platform
      });

      // Also update legacy single token field for backward compatibility
      await _firestore.collection('users').doc(uid).set(
        {'fcmToken': token, 'fcmTokenUpdatedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );

      debugPrint('[FCM] Token saved for $uid (multi-device + legacy)');
    } catch (e) {
      debugPrint('[FCM] Failed to save token: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Firestore in-app notification feed
  // ---------------------------------------------------------------------------

  void _listenToNotifications() {
    _sub?.cancel();
    final uid = _uid;
    if (uid == null) return;

    _sub = _firestore
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .listen(
      (snapshot) {
        value = snapshot.docs
            .map((doc) => AppNotification.fromFirestore(doc))
            .toList();
      },
      onError: (e) => debugPrint('[NotifService] Firestore error: $e'),
    );
  }

  /// Write a notification to Firestore.
  ///
  /// This creates the notification document which is then received by authorized
  /// household members via Firestore realtime listeners (in-app notifications).
  Future<void> push(
    String uid,
    String title,
    String body,
    AppNotificationType type, {
    String? relatedPlanId,
    String? actorName,
    String? actorUid,
    String? actionType,
    String? targetName,
    String? targetId,
    String? navigationRoute,
    Map<String, dynamic>? navigationParameters,
  }) async {
    try {
      final notif = AppNotification(
        id: '',
        title: title,
        body: body,
        type: type,
        createdAt: DateTime.now(),
        relatedPlanId: relatedPlanId,
        actorName: actorName,
        actorUid: actorUid,
        actionType: actionType,
        targetName: targetName,
        targetId: targetId,
        navigationRoute: navigationRoute,
        navigationParameters: navigationParameters,
      );
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .add(notif.toFirestore());
    } catch (e) {
      debugPrint('[NotifService] Failed to push notification: $e');
    }
  }

  /// Broadcast a notification to all authorized members of the current household.
  ///
  /// If the user is not in a household, delivers to the current user if [includeSelf] is true.
  Future<void> notifyHouseholdMembers({
    required String title,
    required String body,
    required AppNotificationType type,
    String? relatedPlanId,
    bool includeSelf = true,
    String? excludeUid,
    String? actorName,
    String? actorUid,
    String? actionType,
    String? targetName,
    String? targetId,
    String? navigationRoute,
    Map<String, dynamic>? navigationParameters,
  }) async {
    final currentSpace = FamilyRepository.instance.value;
    final currentUid = _uid;

    if (currentSpace == null || currentSpace.members.isEmpty) {
      if (includeSelf && currentUid != null) {
        await push(
          currentUid,
          title,
          body,
          type,
          relatedPlanId: relatedPlanId,
          actorName: actorName,
          actorUid: actorUid,
          actionType: actionType,
          targetName: targetName,
          targetId: targetId,
          navigationRoute: navigationRoute,
          navigationParameters: navigationParameters,
        );
      }
      return;
    }

    final recipients = currentSpace.members.map((m) => m.id).toSet();
    if (currentUid != null && !includeSelf) {
      recipients.remove(currentUid);
    }
    if (excludeUid != null) {
      recipients.remove(excludeUid);
    }

    if (recipients.isEmpty) return;

    try {
      final batch = _firestore.batch();
      for (final recipientUid in recipients) {
        final notif = AppNotification(
          id: '',
          title: title,
          body: body,
          type: type,
          createdAt: DateTime.now(),
          relatedPlanId: relatedPlanId,
          actorName: actorName,
          actorUid: actorUid,
          actionType: actionType,
          targetName: targetName,
          targetId: targetId,
          navigationRoute: navigationRoute,
          navigationParameters: navigationParameters,
        );
        final docRef = _firestore
            .collection('users')
            .doc(recipientUid)
            .collection('notifications')
            .doc();
        batch.set(docRef, notif.toFirestore());
      }
      await batch.commit();
    } catch (e) {
      debugPrint('[NotifService] Failed to notify household members: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Mark read
  // ---------------------------------------------------------------------------

  Future<void> markAllRead() async {
    final uid = _uid;
    if (uid == null) return;
    final unread = value.where((n) => !n.read).toList();
    if (unread.isEmpty) return;

    final batch = _firestore.batch();
    for (final n in unread) {
      batch.update(
        _firestore
            .collection('users')
            .doc(uid)
            .collection('notifications')
            .doc(n.id),
        {'read': true},
      );
    }
    await batch.commit();
  }

  Future<void> markRead(String notificationId) async {
    final uid = _uid;
    if (uid == null) return;
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .doc(notificationId)
        .update({'read': true});
  }
}
