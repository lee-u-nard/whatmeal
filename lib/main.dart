import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException, appFlavor;
import 'package:go_router/go_router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:provider/provider.dart';
import 'app.dart';
import 'features/auth/data/auth_repository.dart';
import 'firebase_options.dart';
import 'features/meal_plan/data/meal_plan_repository.dart';
import 'core/services/user_service.dart';
import 'core/services/family_service.dart';
import 'core/services/llm_service.dart';
import 'core/services/firestore_service.dart';
import 'core/services/notification_service.dart';
import 'core/routing/notification_route.dart';
import 'core/config/runtime_environment.dart';
import 'core/config/ai_test_environment.dart';
import 'core/config/cloud_test_environment.dart';

// Global navigator key for deep linking from notifications
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Top-level FCM background handler must be registered before runApp.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (!useNativeDeviceNotifications) return;
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const useEmulators = useFirebaseEmulators;
  const useCloudTest = appFlavor == CloudTestEnvironment.flavor;
  var localTarget = LocalFirebaseTarget.audit;
  var startupStage = 'environment validation';
  // The explicit local mode has a demo project, never production configuration.
  try {
    AiTestEnvironment.requireNormalEntryPoint(appFlavor);
    if (useCloudTest) {
      CloudTestEnvironment.requireLaunch(
        actualFlavor: appFlavor,
        isAndroid: !kIsWeb && defaultTargetPlatform == TargetPlatform.android,
        isDebug: kDebugMode,
        useEmulators: useEmulators,
      );
    }
    if (!kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        useEmulators) {
      localTarget = LocalFirebaseTarget.forAndroidFlavor(appFlavor);
    }
    startupStage = 'Firebase initialization';
    if (useCloudTest) {
      // The full-app test has its own native Firebase app and Android data
      // folder. Never evaluate or fall back to production Dart options here.
      final app = await Firebase.initializeApp();
      CloudTestEnvironment.requireIdentity(
        actualProjectId: app.options.projectId,
        actualAppId: app.options.appId,
        actualProjectNumber: app.options.messagingSenderId,
      );
      startupStage = 'cloud-test App Check';
      final appCheck = FirebaseAppCheck.instanceFor(app: app);
      await appCheck.activate(androidProvider: AndroidProvider.debug);
      final token =
          await appCheck.getToken().timeout(const Duration(seconds: 20));
      if (token == null || token.isEmpty) {
        throw StateError(
            'The cloud test requires a registered App Check token.');
      }
    } else {
      await Firebase.initializeApp(
        options: useEmulators
            ? FirebaseOptions(
                apiKey: 'demo-api-key',
                appId: '1:123:android:abcdef1234567890',
                messagingSenderId: '123',
                projectId: localTarget.projectId)
            : DefaultFirebaseOptions.currentPlatform,
      );
    }
    if (useEmulators &&
        Firebase.app().options.projectId != localTarget.projectId) {
      throw StateError('Unexpected Firebase project for local mode.');
    }
  } catch (error) {
    String safeCode(String value) =>
        value.replaceAll(RegExp(r'[^a-zA-Z0-9_.-]'), '');
    final diagnostic = error is FirebaseException
        ? '${safeCode(error.plugin)}/${safeCode(error.code)}'
        : error is PlatformException
            ? safeCode(error.code)
            : error.runtimeType.toString();
    debugPrint('App startup failed at $startupStage ($diagnostic).');
    final message = useCloudTest
        ? 'WhatMeal Cloud Test could not start. Check its approved debug configuration, then restart. Diagnostic: $startupStage ($diagnostic).'
        : 'WhatMeal could not start during $startupStage. Check your connection and restart. Diagnostic: $startupStage ($diagnostic).';
    runApp(MaterialApp(
      home: Scaffold(body: Center(child: Text(message))),
    ));
    return;
  }

  final firestoreService = FirestoreService();
  await firestoreService.enablePersistence();
  if (useEmulators) {
    const host = String.fromEnvironment('WHATMEAL_EMULATOR_HOST',
        defaultValue: '127.0.0.1');
    final firestorePort = appFlavor == 'showcase'
        ? localTarget.firestorePort
        : const int.fromEnvironment('WHATMEAL_FIRESTORE_EMULATOR_PORT',
            defaultValue: 8180);
    // The alternate port is an isolated acceptance-test transport relay only.
    if (appFlavor != 'showcase' &&
        firestorePort != 8180 &&
        firestorePort != 8181) {
      throw StateError('Unexpected local Firestore emulator port.');
    }
    FirebaseFirestore.instance.useFirestoreEmulator(host, firestorePort);
    await FirebaseAuth.instance.useAuthEmulator(host, localTarget.authPort);
  }

  if (!useEmulators && !useCloudTest) {
    const webSiteKey = String.fromEnvironment('RECAPTCHA_SITE_KEY');
    if (kIsWeb && webSiteKey.isEmpty && !kDebugMode) {
      runApp(const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Web App Check is not configured. Restart with the public '
                'Firebase reCAPTCHA site key using '
                '--dart-define=RECAPTCHA_SITE_KEY=YOUR_PUBLIC_SITE_KEY.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ));
      return;
    }
    try {
      await FirebaseAppCheck.instance.activate(
        webProvider: kIsWeb
            ? (webSiteKey.isNotEmpty
                ? ReCaptchaEnterpriseProvider(webSiteKey)
                : (kDebugMode ? ReCaptchaV3Provider('debug') : null))
            : null,
        androidProvider:
            kDebugMode ? AndroidProvider.debug : AndroidProvider.playIntegrity,
        appleProvider:
            kDebugMode ? AppleProvider.debug : AppleProvider.deviceCheck,
      );
      if (kIsWeb) {
        final token = await FirebaseAppCheck.instance.getToken();
        if (token == null || token.isEmpty) {
          if (!kDebugMode) {
            throw StateError('Web App Check did not return a token.');
          } else {
            debugPrint('Web App Check token not returned in debug mode.');
          }
        }
      }
    } catch (error) {
      debugPrint('App Check setup failed (${error.runtimeType}); '
          'protected services may be unavailable.');
      if (kIsWeb && !kDebugMode) {
        runApp(const MaterialApp(
          home: Scaffold(
            body: Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Web App Check could not initialize. Verify the Firebase '
                  'reCAPTCHA site key and localhost domain configuration, '
                  'then restart the app.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ));
        return;
      }
    }
  }

  if (useNativeDeviceNotifications) {
    try {
      // Register the FCM background handler before any other setup.
      FirebaseMessaging.onBackgroundMessage(
          _firebaseMessagingBackgroundHandler);

      // Initialize the notification service (requests FCM permission,
      // sets up local notifications channel, saves token).
      await NotificationService.instance.initialize();

      // Set up notification interaction handlers for deep linking
      _setupNotificationInteractions();
    } catch (e) {
      debugPrint('Notification initialization failed (${e.runtimeType})');
    }
  }

  runApp(
    MultiProvider(
      providers: [
        Provider(create: (_) => UserService()),
        Provider(create: (_) => FamilyService()),
        Provider(create: (_) => LlmService()),
        Provider(create: (_) => FirestoreService()),
        ChangeNotifierProvider(create: (_) => MealPlanRepository()),
      ],
      child: WhatMealApp(navigatorKey: navigatorKey),
    ),
  );
}

/// Set up notification interaction handlers for deep linking
Map<String, dynamic>? _pendingNotification;
String? _notificationAccount;
int? _notificationSession;
bool _navigationScheduled = false;
void _setupNotificationInteractions() {
  final pending = NotificationService.instance.pendingNavigation;
  pending.addListener(() {
    if (pending.value != null) _queueNotification(pending.value!);
  });
  if (pending.value != null) _queueNotification(pending.value!);
  AuthRepository.instance.addListener(_tryNotificationNavigation);
  // Handle notification taps when app is in background
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    _handleNotificationNavigation(message);
  });

  // Handle notification taps when app is completely terminated
  FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
    if (message != null) {
      _handleNotificationNavigation(message);
    }
  });
}

/// Handle navigation based on notification data
/// Note: This is used when Cloud Functions send FCM messages with navigation data.
/// On Firebase Spark (free) plan without Cloud Functions, this won't be triggered
/// by household notifications, but is kept for future use or manual FCM testing.
void _handleNotificationNavigation(RemoteMessage message) =>
    _queueNotification(message.data);

void _queueNotification(Map<String, dynamic> data) {
  _pendingNotification = data;
  _notificationAccount = FirebaseAuth.instance.currentUser?.uid;
  _notificationSession = _notificationAccount == null
      ? null
      : AuthRepository.instance.sessionVersion;
  _tryNotificationNavigation();
}

void _tryNotificationNavigation() {
  if (_pendingNotification == null || _navigationScheduled) return;
  final auth = AuthRepository.instance;
  if (!auth.isAuthenticated || auth.isInitializing) return;
  if (_notificationAccount != null &&
      (auth.currentUser?.uid != _notificationAccount ||
          auth.sessionVersion != _notificationSession)) {
    _pendingNotification = null;
    return;
  }
  _navigationScheduled = true;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _navigationScheduled = false;
    final context = navigatorKey.currentContext;
    if (context == null ||
        !auth.isAuthenticated ||
        _pendingNotification == null) {
      return;
    }
    if (_notificationAccount != null &&
        (auth.currentUser?.uid != _notificationAccount ||
            auth.sessionVersion != _notificationSession)) {
      _pendingNotification = null;
      return;
    }
    final data = _pendingNotification!;
    _pendingNotification = null;
    GoRouter.of(context).go(notificationRoute(data));
  });
  WidgetsBinding.instance.ensureVisualUpdate();
}
