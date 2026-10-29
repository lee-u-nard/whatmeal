import 'package:firebase_app_check/firebase_app_check.dart';
// WebProvider is part of FirebaseAppCheck.activate's public interface but is not
// re-exported by the pinned firebase_app_check package.
// ignore: depend_on_referenced_packages
import 'package:firebase_app_check_platform_interface/firebase_app_check_platform_interface.dart'
    show WebProvider;
import 'package:firebase_core/firebase_core.dart';

/// Supplies one limited-use token per Firebase AI request on the pinned SDK.
///
/// Firebase AI 2.3.0 asks its supplied App Check instance for getToken(). Its
/// session tokens are incompatible with enforced replay protection. Keep this
/// delegate local to AI so other Firebase services retain their normal session
/// tokens. Token failures propagate; there is no session-token fallback.
class FirebaseAiAppCheck implements FirebaseAppCheck {
  FirebaseAiAppCheck(this._delegate);

  final FirebaseAppCheck _delegate;

  @override
  FirebaseApp get app => _delegate.app;

  @override
  set app(FirebaseApp value) => _delegate.app = value;

  @override
  Map<dynamic, dynamic> get pluginConstants => _delegate.pluginConstants;

  @override
  Future<void> activate({
    WebProvider? webProvider,
    AndroidProvider androidProvider = AndroidProvider.playIntegrity,
    AppleProvider appleProvider = AppleProvider.deviceCheck,
  }) =>
      _delegate.activate(
        webProvider: webProvider,
        androidProvider: androidProvider,
        appleProvider: appleProvider,
      );

  @override
  Future<String?> getToken([bool? forceRefresh]) =>
      _delegate.getLimitedUseToken();

  @override
  Future<String> getLimitedUseToken() => _delegate.getLimitedUseToken();

  @override
  Future<void> setTokenAutoRefreshEnabled(bool isTokenAutoRefreshEnabled) =>
      _delegate.setTokenAutoRefreshEnabled(isTokenAutoRefreshEnabled);

  @override
  Stream<String?> get onTokenChange => _delegate.onTokenChange;
}
