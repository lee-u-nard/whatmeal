import 'dart:async';
import '../config/runtime_environment.dart';
import 'dart:convert';
import 'household_activity_store.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/app_notification.dart';
import '../../features/family/data/family_repository.dart';
import '../../features/family/models/family_space.dart';

// ---------------------------------------------------------------------------
// Top-level background message handler (must be a top-level function)
// ---------------------------------------------------------------------------

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase is already initialised before this handler runs.
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
  final pendingNavigation = ValueNotifier<Map<String, dynamic>?>(null);
  void _localNotificationTapped(String? payload) {
    if (payload == null) return;
    try {
      final data = jsonDecode(payload);
      if (data is Map<String, dynamic>) pendingNavigation.value = data;
    } on FormatException {
      pendingNavigation.value = {'route': '/notifications'};
    }
  }

  NotificationService({
    required FirebaseFirestore firestore,
    required Stream<String?> userIds,
    required ValueListenable<FamilySpace?> household,
    Stream<QuerySnapshot<Map<String, dynamic>>> Function(String uid)?
        watchPersonal,
    Stream<List<AppNotification>> Function(
            String uid, String familyId, DateTime joinedAt)?
        watchShared,
    bool enableDeviceNotifications = false,
  })  : _firestore = firestore,
        _household = household,
        _watchPersonal = watchPersonal,
        _watchShared = watchShared,
        _enableDeviceNotifications = enableDeviceNotifications,
        super([]) {
    _authSub = userIds.distinct().listen((uid) {
      if (_disposed) return;
      _sub?.cancel();
      _activitySub?.cancel();
      _activityScope = null;
      ++_activityEpoch;
      ++_authEpoch;
      ++_personalEpoch;
      _personal = [];
      _shared = [];
      _uid = uid;
      _personalLoading = _uid != null;
      _sharedLoading = false;
      _personalError = null;
      _sharedError = null;
      pendingNavigation.value = null;
      _listenToHousehold();
      _mergeFeed();
      if (_uid != null) {
        _listenToNotifications();
        if (_enableDeviceNotifications) {
          _refreshFcmToken();
        }
      } else {
        _sub?.cancel();
        _sub = null;
        value = [];
      }
    });
    _household.addListener(_householdChanged);
  }

  static final instance = NotificationService(
    firestore: FirebaseFirestore.instance,
    userIds: FirebaseAuth.instance.authStateChanges().map((user) => user?.uid),
    household: FamilyRepository.instance,
    enableDeviceNotifications: useNativeDeviceNotifications,
  );

  final FirebaseFirestore _firestore;
  final ValueListenable<FamilySpace?> _household;
  final Stream<QuerySnapshot<Map<String, dynamic>>> Function(String uid)?
      _watchPersonal;
  final Stream<List<AppNotification>> Function(
      String uid, String familyId, DateTime joinedAt)? _watchShared;
  final bool _enableDeviceNotifications;
  FirebaseMessaging get _messaging => FirebaseMessaging.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();

  String? _uid;
  StreamSubscription<String?>? _authSub;
  StreamSubscription<RemoteMessage>? _messageSub;
  StreamSubscription<String>? _tokenSub;
  bool _disposed = false;
  StreamSubscription? _sub;
  bool _initialized = false;
  StreamSubscription? _activitySub;
  List<AppNotification> _personal = [], _shared = [];
  String? _activityScope;
  int _activityEpoch = 0;
  int _authEpoch = 0;
  int _personalEpoch = 0;
  int get sessionVersion => _authEpoch;
  bool _personalLoading = false, _sharedLoading = false;
  String? _personalError, _sharedError;
  bool get isLoading => _personalLoading || _sharedLoading;
  String? get error => _personalError ?? _sharedError;

  void retry() {
    if (_disposed) return;
    ++_personalEpoch;
    _personalError = _sharedError = null;
    _personalLoading = _uid != null;
    _personal = [];
    _activityScope = null;
    _listenToHousehold(newSession: false);
    _listenToNotifications();
    _mergeFeed();
  }

  void _mergeFeed() {
    if (_disposed) return;
    value = [..._personal, ..._shared]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  void _householdChanged() => _listenToHousehold();

  void _listenToHousehold({bool newSession = true}) {
    if (_disposed) return;
    final uid = _uid;
    final family = _household.value;
    final member = family?.memberForUid(uid);
    final scope = uid != null && family != null && member?.joinedAt != null
        ? '$uid/${family.id}/${member!.joinedAt}'
        : null;
    if (_activityScope == scope) return;
    if (newSession) {
      ++_authEpoch;
      pendingNavigation.value = null;
    }
    _activityScope = scope;
    final epoch = ++_activityEpoch;
    _activitySub?.cancel();
    _shared = [];
    _sharedLoading = scope != null;
    _sharedError = null;
    _mergeFeed();
    if (scope == null) return;
    _activitySub = (_watchShared?.call(uid!, family!.id, member!.joinedAt!) ??
            HouseholdActivityStore(_firestore).watch(
                uid: uid!, familyId: family!.id, joinedAt: member!.joinedAt!))
        .listen((events) {
      if (!_disposed && epoch == _activityEpoch) {
        _sharedLoading = false;
        _sharedError = null;
        _shared = events;
        _mergeFeed();
      }
    }, onError: (Object error) {
      if (!_disposed && epoch == _activityEpoch) {
        _sharedLoading = false;
        _sharedError = 'Household notifications could not be loaded.';
        _shared = [];
        _mergeFeed();
      }
    }, cancelOnError: true);
  }

  List<AppNotification> get notifications => value;

  int get unreadCount => value.where((n) => !n.read).length;

  /// Cleanup FCM tokens on logout
  Future<void> cleanupOnLogout() async {
    if (!_enableDeviceNotifications) return;
    final uid = _uid;
    if (uid == null) return;

    try {
      final token = kIsWeb
          ? await _messaging
              .getToken(vapidKey: _webVapidKey)
              .timeout(const Duration(seconds: 5))
          : await _messaging.getToken().timeout(const Duration(seconds: 5));
      if (token == null) return;
      // Remove this installation's registrations only, not other devices.
      final tokensSnapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('fcmTokens')
          .where('token', isEqualTo: token)
          .get()
          .timeout(const Duration(seconds: 5));

      final batch = _firestore.batch();
      for (final doc in tokensSnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit().timeout(const Duration(seconds: 5));

      final userRef = _firestore.collection('users').doc(uid);
      await _firestore.runTransaction((transaction) async {
        final user = await transaction.get(userRef);
        if (user.data()?['fcmToken'] == token) {
          transaction.update(userRef, {'fcmToken': null});
        }
      }).timeout(const Duration(seconds: 5));
      await _messaging.deleteToken().timeout(const Duration(seconds: 5));

      debugPrint('[FCM] Tokens cleaned up on logout for $uid');
    } catch (e) {
      debugPrint('[FCM] Token cleanup failed (${e.runtimeType})');
    }
  }

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  Future<void> initialize() async {
    if (!_enableDeviceNotifications) return;
    if (_initialized) return;
    _initialized = true;

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
      onDidReceiveNotificationResponse: (response) =>
          _localNotificationTapped(response.payload),
    );
    final launch = await _localNotifications.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp == true) {
      _localNotificationTapped(launch?.notificationResponse?.payload);
    }

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
    _messageSub = FirebaseMessaging.onMessage.listen((message) {
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
          payload: jsonEncode(message.data),
        );
      }
    });

    // 6. Handle FCM token refresh.
    _tokenSub = _messaging.onTokenRefresh.listen(_saveFcmToken);
  }

  // ---------------------------------------------------------------------------
  // FCM token management
  // ---------------------------------------------------------------------------
  // Note: FCM tokens are saved to Firestore for future use.
  // On Firebase Spark (free) plan, server-side push notifications require Cloud Functions.
  // Current implementation uses Firestore realtime listeners for in-app notifications.
  // Foreground FCM messages are handled client-side via FirebaseMessaging.onMessage.

  // VAPID key for web push (Firebase Console → Project Settings → Cloud Messaging → Web Push certificates)
  static const _webVapidKey =
      'BFBhoCPBfz7MvNXUejT1G-hm31gxLJZcxuuwTSGyFlH-wEi7hnOJF7RXQyvZjuL1LZQVquCv9PrGAyILtAY5Pp4';

  Future<void> _refreshFcmToken() async {
    try {
      final token = kIsWeb
          ? await _messaging.getToken(vapidKey: _webVapidKey)
          : await _messaging.getToken();
      if (token != null) await _saveFcmToken(token);
    } catch (e) {
      debugPrint('[FCM] Failed to get token: ${e.runtimeType}');
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
      debugPrint('[FCM] Failed to save token: ${e.runtimeType}');
    }
  }

  // ---------------------------------------------------------------------------
  // Firestore in-app notification feed
  // ---------------------------------------------------------------------------

  void _listenToNotifications() {
    _sub?.cancel();
    final uid = _uid;
    final epoch = _personalEpoch;
    if (uid == null) return;

    _sub = (_watchPersonal?.call(uid) ??
            _firestore
                .collection('users')
                .doc(uid)
                .collection('notifications')
                .orderBy('createdAt', descending: true)
                .limit(50)
                .snapshots())
        .listen(
      (snapshot) {
        if (_disposed || _uid != uid || _personalEpoch != epoch) return;
        _personalLoading = false;
        _personalError = null;
        _personal = snapshot.docs
            .map((doc) => AppNotification.fromFirestore(doc))
            .toList();
        _mergeFeed();
      },
      onError: (Object failure) {
        if (_disposed || _uid != uid || _personalEpoch != epoch) return;
        _personalLoading = false;
        _personalError = 'Notifications could not be loaded.';
        _personal = [];
        _mergeFeed();
      },
      cancelOnError: true,
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
      debugPrint(
          '[NotifService] Failed to push notification: ${e.runtimeType}');
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
    final currentSpace = _household.value;
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

    if (currentUid == null) return;
    try {
      // Never persist arbitrary provider errors, credentials or invitation tokens
      // in shared activity. Actor identity comes from the authenticated session.
      await HouseholdActivityStore(_firestore).publish(
        familyId: currentSpace.id,
        actorUid: currentUid,
        type: type,
        relatedPlanId: relatedPlanId,
        targetId: targetId,
        includeSelf: includeSelf && excludeUid != currentUid,
        operationId:
            type == AppNotificationType.mealReplaced && targetId != null
                ? 'replacement_$targetId'
                : null,
      );
    } catch (error) {
      debugPrint(
          '[NotifService] Household activity failed (${error.runtimeType})');
    }
  }

  // ---------------------------------------------------------------------------
  // Mark read
  // ---------------------------------------------------------------------------

  void _checkSession(int? expectedSession) {
    if (_disposed ||
        (expectedSession != null && expectedSession != sessionVersion)) {
      throw StateError(
          'Your account or household changed. Reopen notifications.');
    }
  }

  Future<void> markAllRead({int? expectedSession}) async {
    _checkSession(expectedSession);
    final uid = _uid;
    if (uid == null) return;
    final unread = value.where((n) => !n.read).toList();
    if (unread.isEmpty) return;

    final batch = _firestore.batch();
    for (final n in unread) {
      if (n.id.startsWith('household:')) {
        batch.set(_firestore.doc('users/$uid/notificationReceipts/${n.id}'), {
          'read': true,
          'dismissed': false,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        batch.update(
            _firestore.doc('users/$uid/notifications/${n.id}'), {'read': true});
      }
    }
    await batch.commit();
  }

  Future<void> markRead(String notificationId, {int? expectedSession}) async {
    _checkSession(expectedSession);
    final uid = _uid;
    if (uid == null) return;
    if (notificationId.startsWith('household:')) {
      await HouseholdActivityStore(_firestore).markRead(uid, notificationId);
      return;
    }
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .doc(notificationId)
        .update({'read': true});
  }

  @override
  void dispose() {
    _disposed = true;
    ++_authEpoch;
    ++_personalEpoch;
    ++_activityEpoch;
    _authSub?.cancel();
    _sub?.cancel();
    _activitySub?.cancel();
    _messageSub?.cancel();
    _tokenSub?.cancel();
    _household.removeListener(_householdChanged);
    pendingNavigation.dispose();
    super.dispose();
  }
}
