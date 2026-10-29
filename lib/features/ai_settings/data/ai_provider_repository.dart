import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../../core/models/llm_config.dart';
import '../../../core/models/app_notification.dart';
import '../../../core/services/llm_service.dart';
import '../../../core/services/ai/ai_models.dart';
import '../../../core/services/ai/generation_failure.dart';
import '../../../core/services/ai/model_registry.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/household_notification_service.dart';
import '../models/ai_provider.dart';

typedef ValidateAiConnection = Future<KeyValidationResult> Function(
    LlmConfig config);
typedef LoadAiModels = Future<List<String>> Function(LlmConfig config);
typedef AiConnectionNotification = void Function(
    String uid, String title, String message, AppNotificationType type);

class AiProviderRepository extends ValueNotifier<AiProviderConfig> {
  /// Injectable account and storage boundaries; tests never need live Firebase.
  AiProviderRepository({
    required Stream<String?> userIds,
    required Stream<LlmConfig> Function(String) watchConfig,
    required Future<LlmConfig> Function(String) readConfig,
    required Future<void> Function(String, LlmConfig) saveConfig,
    void Function(AiProviderType)? onProviderChanged,
    ValidateAiConnection? validateConnection,
    LoadAiModels? loadModels,
    AiConnectionNotification? onConnectionResult,
  })  : _watchConfig = watchConfig,
        _readConfig = readConfig,
        _saveConfig = saveConfig,
        _onProviderChanged = onProviderChanged,
        _validateConnection = validateConnection ?? _validateWithService,
        _loadModels = loadModels ?? _loadWithService,
        _onConnectionResult = onConnectionResult,
        super(AiProviderConfig(
          providerType: AiProviderType.gemini,
          selectedModel: AiProviderType.gemini.defaultModel,
          statusMessage: 'Loading provider settings...',
        )) {
    _authSub = userIds.distinct().listen(_setAccount);
  }

  static final instance = AiProviderRepository(
    userIds: FirebaseAuth.instance.authStateChanges().map((user) => user?.uid),
    watchConfig: (uid) => LlmService().activeConfigStream(uid),
    readConfig: (uid) => LlmService().getLlmConfig(uid),
    saveConfig: (uid, config) => LlmService().saveLlmConfig(uid, config),
    onProviderChanged: (type) =>
        HouseholdNotificationService.instance.notifyAiProviderChanged(
      action: 'changed',
      providerName: type.displayName,
    ),
    onConnectionResult: (uid, title, message, type) =>
        NotificationService.instance.push(uid, title, message, type),
  );

  static Future<KeyValidationResult> _validateWithService(LlmConfig config) =>
      LlmService().validateKey(config.provider, config.apiKey ?? '',
          model: config.model,
          customEndpoint: config.customEndpoint,
          isOpenAiCompatible: config.isOpenAiCompatible);

  static Future<List<String>> _loadWithService(LlmConfig config) =>
      LlmService().fetchAvailableModels(
          provider: config.provider,
          apiKey: config.apiKey ?? '',
          customEndpoint: config.customEndpoint,
          isOpenAiCompatible: config.isOpenAiCompatible);

  final Stream<LlmConfig> Function(String) _watchConfig;
  final Future<LlmConfig> Function(String) _readConfig;
  final Future<void> Function(String, LlmConfig) _saveConfig;
  final void Function(AiProviderType)? _onProviderChanged;
  final ValidateAiConnection _validateConnection;
  final LoadAiModels _loadModels;
  final AiConnectionNotification? _onConnectionResult;
  String? _uid;
  StreamSubscription<String?>? _authSub;
  StreamSubscription<LlmConfig>? _configSub;
  int _revision = 0;
  int _session = 0;
  int _editRevision = 0;
  int _remoteRevision = 0;
  int _pendingWrites = 0;
  bool _disposed = false;
  Future<void> _pendingSave = Future<void>.value();
  AiProviderConfig? _persistedSelection;

  bool get isSaving => _pendingWrites > 0;

  /// Never request an older saved provider while the screen shows a new one.
  /// Connection-test failures do not invalidate an otherwise saved selection.
  String? get generationReadinessError {
    if (_disposed || _uid == null) {
      return 'Sign in before generating a meal plan.';
    }
    if (isSaving) {
      return 'AI settings are still saving. Wait, then generate again.';
    }
    final saved = _persistedSelection;
    if (saved == null ||
        saved.providerType != value.providerType ||
        saved.selectedModel != value.selectedModel ||
        (saved.apiKey ?? '') != (value.apiKey ?? '') ||
        (saved.customEndpoint ?? '') != (value.customEndpoint ?? '') ||
        saved.isOpenAiCompatible != value.isOpenAiCompatible) {
      return 'AI settings are not synchronized. Open AI Settings and retry saving '
          'your provider before generating.';
    }
    return null;
  }

  /// Changes even when the same account signs out and back in.
  int get sessionRevision => _session;

  void retry() {
    if (_disposed || isSaving || _uid == null) return;
    // Reopen the actual subscription; reopening a page alone leaves a failed
    // singleton listener unchanged. Never discard an outstanding settings write.
    _setAccount(_uid);
  }

  void _setAccount(String? uid) {
    _uid = uid;
    _persistedSelection = null;
    final session = ++_session;
    ++_revision;
    ++_editRevision;
    ++_remoteRevision;
    _pendingWrites = 0;
    // An old account's slow write must not hold up this account's queue.
    _pendingSave = Future<void>.value();
    _configSub?.cancel();
    _configSub = null;
    value = _fromLlmConfig(LlmConfig.defaultConfig);
    if (uid == null) return;
    _configSub = _watchConfig(uid).listen((config) {
      if (!_isCurrent(uid, session)) return;
      ++_remoteRevision;
      // Firestore emits local and remote snapshots while saves are pending.
      // Re-read after the queue drains instead of applying an older echo.
      if (isSaving) return;
      ++_revision;
      final selected = _fromLlmConfig(config);
      _persistedSelection = selected;
      value = selected;
    }, onError: (Object _) {
      if (!_isCurrent(uid, session)) return;
      _persistedSelection = null;
      ++_remoteRevision;
      ++_revision;
      // Clear stale credentials on a denied/failed listener.
      value = _fromLlmConfig(LlmConfig.defaultConfig).copyWith(
        status: ApiConnectionStatus.failed,
        statusMessage: 'Provider settings could not be loaded. Retry settings.',
      );
    });
  }

  bool _isCurrent(String uid, int session) =>
      !_disposed && _uid == uid && _session == session;

  Future<bool> _saveToFirestore(LlmConfig config) async {
    final uid = _uid;
    final session = _session;
    final edit = ++_editRevision;
    ++_revision;
    if (uid == null || _disposed) return false;
    ++_pendingWrites;
    notifyListeners();
    var saved = false;
    final operation = _pendingSave.then((_) async {
      if (!_isCurrent(uid, session)) return;
      try {
        await _saveConfig(uid, config);
        saved = true;
      } catch (_) {
        if (_isCurrent(uid, session) && edit == _editRevision) {
          value = value.copyWith(
            status: ApiConnectionStatus.failed,
            statusMessage:
                'Settings could not be saved. Check your connection and retry.',
          );
        }
      } finally {
        if (_isCurrent(uid, session)) {
          --_pendingWrites;
          notifyListeners();
        }
      }
    });
    _pendingSave = operation;
    await operation;
    if (!_isCurrent(uid, session)) return false;
    if (saved && edit == _editRevision && !isSaving) {
      final remote = _remoteRevision;
      try {
        final current = await _readConfig(uid);
        if (_isCurrent(uid, session) &&
            edit == _editRevision &&
            remote == _remoteRevision &&
            !isSaving) {
          ++_revision;
          final selected = _fromLlmConfig(current);
          _persistedSelection = selected;
          value = selected;
        }
      } catch (_) {
        if (_isCurrent(uid, session) &&
            edit == _editRevision &&
            remote == _remoteRevision) {
          value = value.copyWith(
            status: ApiConnectionStatus.failed,
            statusMessage:
                'Settings saved, but synchronization could not be refreshed.',
          );
        }
      }
    }
    return saved && _isCurrent(uid, session);
  }

  AiProviderConfig _fromLlmConfig(LlmConfig config) {
    final type = _uiTypeFrom(config.provider);
    final hasKey = config.apiKey != null && config.apiKey!.isNotEmpty;
    final isBuiltIn = config.provider == LlmProvider.gemini && !config.isCustom;
    final anonymousCustom = config.provider == LlmProvider.custom &&
        (config.customEndpoint?.trim().isNotEmpty ?? false);
    return AiProviderConfig(
      providerType: type,
      selectedModel: config.model ?? type.defaultModel,
      apiKey: config.apiKey,
      customEndpoint: config.customEndpoint,
      isOpenAiCompatible: config.isOpenAiCompatible ?? true,
      status: isBuiltIn
          ? ApiConnectionStatus.configured
          : (hasKey || anonymousCustom
              ? ApiConnectionStatus.configured
              : ApiConnectionStatus.notConfigured),
      statusMessage: isBuiltIn
          ? 'Using built-in Gemini (no key required)'
          : (anonymousCustom && !hasKey
              ? 'Custom endpoint saved. Authentication and compatibility are unverified.'
              : hasKey
                  ? 'API key loaded from saved settings'
                  : 'API Key required for ${type.displayName}'),
    );
  }

  AiProviderType _uiTypeFrom(LlmProvider p) {
    switch (p) {
      case LlmProvider.openai:
        return AiProviderType.openAi;
      case LlmProvider.anthropic:
        return AiProviderType.claude;
      case LlmProvider.groq:
        return AiProviderType.groq;
      case LlmProvider.custom:
        return AiProviderType.custom;
      case LlmProvider.gemini:
        return AiProviderType.gemini;
    }
  }

  Future<void> selectProvider(AiProviderType type) async {
    final oldProvider = value.providerType;
    value = value.forProvider(type);
    final saved = await _persist();

    // Never announce a failed or stale-session change.
    if (saved && value.providerType == type && oldProvider != type) {
      _onProviderChanged?.call(type);
    }
  }

  Future<bool> setApiKey(String key) {
    final trimmed = key.trim();
    if (trimmed.isEmpty) {
      return removeKey();
    }
    value = value.copyWith(
      apiKey: trimmed,
      status: ApiConnectionStatus.configured,
      statusMessage: 'Key updated — save and test the connection to verify.',
      clearFetchedModels: true,
    );
    return _persist();
  }

  void setCustomEndpoint(String endpoint) {
    value = value.copyWith(
      customEndpoint: endpoint.trim(),
      clearFetchedModels: true,
      status: ApiConnectionStatus.configured,
      statusMessage: 'Endpoint changed. Test the connection again.',
    );
    _persist();
  }

  void setOpenAiCompatible(bool compatible) {
    value = value.copyWith(
      isOpenAiCompatible: compatible,
      clearFetchedModels: true,
      status: ApiConnectionStatus.configured,
      statusMessage: 'Endpoint mode changed. Test the connection again.',
    );
    _persist();
  }

  Future<bool> updateModel(String model) {
    final trimmed = model.trim();
    if (trimmed.isEmpty) return Future.value(false);
    if (trimmed == value.selectedModel) return Future.value(true);
    value = value.copyWith(
      selectedModel: trimmed,
      status: ApiConnectionStatus.configured,
      statusMessage: 'Model changed. Test the connection again.',
    );
    return _persist();
  }

  Future<void> testConnection() async {
    final uid = _uid;
    final session = _session;
    if (uid == null ||
        _disposed ||
        isSaving ||
        value.status == ApiConnectionStatus.testing) {
      return;
    }
    final config = _toLlmConfig();
    final revision = ++_revision;
    value = value.copyWith(
      status: ApiConnectionStatus.testing,
      statusMessage:
          'Testing connection to ${value.providerType.displayName}...',
    );
    try {
      final result = await _validateConnection(config);
      if (!_isCurrent(uid, session) || revision != _revision) return;
      if (result.isValid) {
        value = value.copyWith(
          status: ApiConnectionStatus.connected,
          statusMessage:
              'Connection check passed. Meal generation has not been verified.',
        );
        _onConnectionResult?.call(
          uid,
          'AI Connection Checked',
          '${value.providerType.displayName} passed a connection check. Meal generation has not been verified.',
          AppNotificationType.aiSuccess,
        );
      } else {
        value = value.copyWith(
          status: _mapStatus(result.status),
          statusMessage: result.errorMessage ?? 'Validation failed.',
        );
        _onConnectionResult?.call(
          uid,
          'AI Provider Connection Failed',
          result.errorMessage ??
              'Could not connect to ${value.providerType.displayName}.',
          AppNotificationType.general,
        );
      }
    } catch (error) {
      if (!_isCurrent(uid, session) || revision != _revision) return;
      final failure = GenerationFailure.from(error);
      value = value.copyWith(
        status: switch (failure.kind) {
          GenerationFailureKind.configuration =>
            ApiConnectionStatus.configurationError,
          GenerationFailureKind.authentication =>
            ApiConnectionStatus.authenticationRequired,
          GenerationFailureKind.permission =>
            ApiConnectionStatus.permissionDenied,
          GenerationFailureKind.invalidModel =>
            ApiConnectionStatus.invalidModel,
          GenerationFailureKind.quota => ApiConnectionStatus.rateLimited,
          GenerationFailureKind.appCheck ||
          GenerationFailureKind.firebase =>
            ApiConnectionStatus.failed,
          GenerationFailureKind.network ||
          GenerationFailureKind.dns ||
          GenerationFailureKind.timeout =>
            ApiConnectionStatus.networkError,
          _ => ApiConnectionStatus.providerUnavailable,
        },
        statusMessage: GenerationFailure.connectionCheckMessage(error),
      );
    }
  }

  ApiConnectionStatus _mapStatus(TestConnectionStatus status) {
    switch (status) {
      case TestConnectionStatus.failed:
        return ApiConnectionStatus.failed;
      case TestConnectionStatus.connected:
        return ApiConnectionStatus.connected;
      case TestConnectionStatus.invalidKey:
        return ApiConnectionStatus.invalidKey;
      case TestConnectionStatus.invalidModel:
        return ApiConnectionStatus.invalidModel;
      case TestConnectionStatus.invalidEndpoint:
        return ApiConnectionStatus.invalidEndpoint;
      case TestConnectionStatus.configurationError:
        return ApiConnectionStatus.configurationError;
      case TestConnectionStatus.authenticationRequired:
        return ApiConnectionStatus.authenticationRequired;
      case TestConnectionStatus.permissionDenied:
        return ApiConnectionStatus.permissionDenied;
      case TestConnectionStatus.rateLimited:
        return ApiConnectionStatus.rateLimited;
      case TestConnectionStatus.networkError:
        return ApiConnectionStatus.networkError;
      case TestConnectionStatus.providerUnavailable:
        return ApiConnectionStatus.providerUnavailable;
    }
  }

  /// Fetches the live list of models from the provider API using the user's actual API key.
  Future<void> fetchModels() async {
    final uid = _uid;
    final session = _session;
    if (uid == null ||
        _disposed ||
        isSaving ||
        value.status == ApiConnectionStatus.testing) {
      return;
    }
    final apiKey = value.apiKey ?? '';
    if (apiKey.isEmpty && value.providerType == AiProviderType.gemini) {
      value = value.copyWith(
        status: ApiConnectionStatus.configured,
        statusMessage:
            'Built-in Gemini uses suggested models. Live model discovery requires your own Gemini API key.',
      );
      return;
    }
    if (apiKey.isEmpty && value.providerType != AiProviderType.custom) return;
    final config = _toLlmConfig();
    final revision = ++_revision;

    value = value.copyWith(
      status: ApiConnectionStatus.testing,
      statusMessage: 'Loading available models...',
    );

    try {
      final models = AiModelRegistry.filterDiscovered(
          config.provider,
          (await _loadModels(config))
              .map((model) => model.trim())
              .where((model) => model.isNotEmpty)
              .toSet()
              .toList());
      if (!_isCurrent(uid, session) || revision != _revision) return;

      if (models.isEmpty) {
        value = value.copyWith(
          status: ApiConnectionStatus.failed,
          statusMessage:
              'No reviewed meal-planning models found. Check your provider access and settings.',
          fetchedModels: [],
        );
        return;
      }

      final selectedAvailable = models.contains(value.selectedModel);
      value = value.copyWith(
        fetchedModels: models,
        status: selectedAvailable
            ? ApiConnectionStatus.configured
            : ApiConnectionStatus.invalidModel,
        statusMessage: selectedAvailable
            ? 'Found ${models.length} model(s). Test the selected model before use.'
            : 'The saved model is absent from this list. Select a model explicitly or check its availability.',
      );
    } catch (e) {
      if (!_isCurrent(uid, session) || revision != _revision) return;
      value = value.copyWith(
        status: ApiConnectionStatus.failed,
        statusMessage: e is GenerationFailure
            ? e.toString()
            : 'Failed to load models. Check your settings and connection.',
      );
    }
  }

  Future<bool> removeKey() {
    value = AiProviderConfig(
      providerType: AiProviderType.gemini,
      selectedModel: AiProviderType.gemini.defaultModel,
      apiKey: null,
      customEndpoint: null,
      fetchedModels: null,
      status: ApiConnectionStatus.configured,
      statusMessage: 'Using built-in Gemini (no key required)',
    );
    return _persist();
  }

  Future<bool> _persist() {
    return _saveToFirestore(_toLlmConfig());
  }

  LlmConfig _toLlmConfig() => LlmConfig(
        provider: value.providerType.toLlmProvider,
        apiKey: value.apiKey,
        model: value.selectedModel,
        customEndpoint: value.customEndpoint,
        isOpenAiCompatible: value.isOpenAiCompatible,
      );

  @override
  void dispose() {
    _disposed = true;
    _persistedSelection = null;
    ++_session;
    ++_revision;
    _authSub?.cancel();
    _configSub?.cancel();
    super.dispose();
  }
}
