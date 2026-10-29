import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/config/runtime_environment.dart';
import '../../../core/config/bundled_gemini_keys.dart';
import '../../../core/services/ai/model_registry.dart';
import '../data/ai_provider_repository.dart';
import '../models/ai_provider.dart';

class AiSettingsPage extends StatefulWidget {
  const AiSettingsPage({super.key, this.repository});

  final AiProviderRepository? repository;

  @override
  State<AiSettingsPage> createState() => _AiSettingsPageState();
}

class _AiSettingsPageState extends State<AiSettingsPage> {
  AiProviderRepository get _repo =>
      widget.repository ?? AiProviderRepository.instance;
  AiProviderType? _lastProvider;
  String? _lastKey;
  String? _lastModel;
  int? _lastSession;
  final _keyController = TextEditingController();
  final _endpointController = TextEditingController();
  final _modelController = TextEditingController();
  bool _isEditingKey = false;
  bool _showRawKey = false;

  @override
  void initState() {
    super.initState();
    final config = _repo.value;
    _endpointController.text = config.customEndpoint ?? '';
    _lastProvider = config.providerType;
    _lastKey = config.apiKey;
    _lastModel = config.selectedModel;
    _lastSession = _repo.sessionRevision;
    _modelController.text = _modelText(config.selectedModel);
    // When the provider reverts to Gemini (e.g. after removeKey), clear
    // the local text controllers and exit editing mode automatically.
    _repo.addListener(_onProviderChanged);
  }

  void _onProviderChanged() {
    final config = _repo.value;
    final changedSession = _lastSession != _repo.sessionRevision;
    if (changedSession ||
        _lastProvider != config.providerType ||
        _lastKey != config.apiKey) {
      _keyController.clear();
      _showRawKey = false;
      _isEditingKey = false;
    }
    _lastProvider = config.providerType;
    _lastKey = config.apiKey;
    _lastSession = _repo.sessionRevision;
    if (changedSession || _lastModel != config.selectedModel) {
      _modelController.text = _modelText(config.selectedModel);
    }
    _lastModel = config.selectedModel;
    final endpoint = config.customEndpoint ?? '';
    if (_endpointController.text != endpoint) {
      _endpointController.text = endpoint;
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _repo.removeListener(_onProviderChanged);
    _keyController.dispose();
    _endpointController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  String _modelText(String model) =>
      model == 'custom-model' || model == 'default' ? '' : model;

  void _showRemoveKeyDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Remove API Key'),
          content: const Text(
            'Are you sure you want to remove your saved API key? '
            'WhatMeal will fall back to the built-in Gemini quota.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final session = _repo.sessionRevision;
                final saved = await _repo.removeKey();
                if (!mounted || session != _repo.sessionRevision) return;
                _keyController.clear();
                _endpointController.clear();
                setState(() => _isEditingKey = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(saved
                        ? 'API Key removed. Switched back to default Gemini.'
                        : 'API key removal was not saved. Please retry.'),
                    backgroundColor: AppColors.primary,
                  ),
                );
              },
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
              child: const Text('Remove Key',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AiProviderConfig>(
      valueListenable: _repo,
      builder: (context, config, _) {
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
              onPressed: () => context.pop(),
            ),
            title: const Text(
              'AI Provider Settings',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 16),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Configure your preferred AI engine to generate personalized '
                'family meal plans. You can use the built-in Gemini quota '
                'when configured, or bring your own provider API key. '
                'Provider access, limits, and charges depend on your account.',
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 20),
              if (config.status == ApiConnectionStatus.failed)
                TextButton.icon(
                  onPressed: _repo.isSaving ? null : _repo.retry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry Settings'),
                ),

              // ── Provider Selector ──────────────────────────────────────────
              const Text(
                'Select AI Provider',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 16),
              ),
              const SizedBox(height: 12),

              Column(
                children: AiProviderType.values.map((type) {
                  final isSelected = config.providerType == type;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      onTap: () {
                        _repo.selectProvider(type);
                        // Sync endpoint field when switching to custom
                        if (type == AiProviderType.custom) {
                          _endpointController.text =
                              _repo.value.customEndpoint ?? '';
                        }
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.cardSurface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.border,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primaryLight
                                    : AppColors.background,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                _iconForProvider(type),
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.textSecondary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    type.displayName,
                                    style: TextStyle(
                                      color: AppColors.textPrimary,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    type.availableModels.isNotEmpty
                                        ? 'Models: ${type.availableModels.take(2).join(', ')}…'
                                        : (type == AiProviderType.custom
                                            ? 'OpenAI Chat Completions JSON; compatibility requires verification'
                                            : 'Default: ${type.defaultModel}'),
                                    style: const TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            _RadioDot(selected: isSelected),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 20),

              // ── API Key & Options Card ─────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.cardSurface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                            child: Row(
                          children: [
                            const Icon(Icons.key,
                                color: AppColors.primary, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(
                              '${config.providerType.displayName} Key',
                              style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15),
                            )),
                          ],
                        )),
                        if (config.apiKey != null && !_isEditingKey)
                          IconButton(
                            icon: const Icon(Icons.edit_outlined,
                                color: AppColors.primary, size: 18),
                            onPressed: () {
                              _keyController.text = config.apiKey ?? '';
                              setState(() => _isEditingKey = true);
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Default WhatMeal Provider (Gemini) — No key required
                    if (config.providerType == AiProviderType.gemini &&
                        (config.apiKey == null || config.apiKey!.isEmpty) &&
                        !_isEditingKey) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.check_circle_rounded,
                                    color: AppColors.primary, size: 18),
                                SizedBox(width: 8),
                                Expanded(
                                    child: Text(
                                  'Default WhatMeal AI Provider',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                )),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              useFirebaseEmulators
                                  ? 'Live AI is disabled in this isolated local demo. '
                                      'Use manual planning here, or use the online WhatMeal app for Gemini.'
                                  : BundledGeminiKeys.hasKeys
                                      ? 'Gemini uses the configured Google AI Studio credentials through the Gemini Developer API. '
                                          'No personal API key is required. Access depends on the selected model and the configured projects\' quotas. '
                                          'Firebase continues to store your account and meal plans.'
                                      : 'Gemini uses the Gemini Developer API through Firebase AI Logic. '
                                          'No personal API key is required. Free-tier generation requires '
                                          'Firebase AI Logic, valid App Check, and available provider quota.',
                              style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 12,
                                  height: 1.4),
                            ),
                            const SizedBox(height: 10),
                            TextButton.icon(
                              onPressed: () {
                                _keyController.text = '';
                                setState(() => _isEditingKey = true);
                              },
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 0),
                              ),
                              icon: const Icon(Icons.vpn_key_outlined,
                                  size: 14, color: AppColors.primary),
                              label: const Text(
                                'Use Custom Gemini Key (Optional)',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (config.providerType != AiProviderType.gemini ||
                        _isEditingKey ||
                        (config.apiKey != null &&
                            config.apiKey!.isNotEmpty)) ...[
                      if (config.providerType == AiProviderType.custom) ...[
                        const Text(
                          'API Endpoint',
                          style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _endpointController,
                          keyboardType: TextInputType.url,
                          decoration: InputDecoration(
                            hintText: 'e.g. https://api.example.com/v1',
                            labelText: 'Base URL',
                            prefixIcon: const Icon(Icons.link,
                                color: AppColors.textMuted),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          onChanged: (val) {
                            _repo.setCustomEndpoint(val);
                          },
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'The app will append /chat/completions to your base URL.',
                          style: TextStyle(
                              color: AppColors.textMuted, fontSize: 11),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // API Key input / display
                      if (_isEditingKey ||
                          config.apiKey == null ||
                          config.apiKey!.isEmpty) ...[
                        TextField(
                          controller: _keyController,
                          obscureText: !_showRawKey,
                          decoration: InputDecoration(
                            hintText: 'Enter API Key',
                            labelText: 'API Key',
                            suffixIcon: IconButton(
                              icon: Icon(
                                _showRawKey
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: AppColors.textMuted,
                              ),
                              onPressed: () =>
                                  setState(() => _showRawKey = !_showRawKey),
                            ),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _repo.isSaving
                                    ? null
                                    : () async {
                                        final key = _keyController.text.trim();
                                        if (key.isEmpty) {
                                          _showRemoveKeyDialog();
                                          return;
                                        }
                                        final session = _repo.sessionRevision;
                                        final saved =
                                            await _repo.setApiKey(key);
                                        if (!mounted ||
                                            !context.mounted ||
                                            session != _repo.sessionRevision) {
                                          return;
                                        }
                                        if (saved) {
                                          setState(() => _isEditingKey = false);
                                        }
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(saved
                                                ? 'API key updated!'
                                                : 'API key was not saved. Please retry.'),
                                            backgroundColor: saved
                                                ? AppColors.primary
                                                : AppColors.danger,
                                          ),
                                        );
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                ),
                                child: const Text('Save Key',
                                    style:
                                        TextStyle(fontWeight: FontWeight.w700)),
                              ),
                            ),
                            if (_isEditingKey && config.apiKey != null) ...[
                              const SizedBox(width: 8),
                              OutlinedButton(
                                onPressed: () =>
                                    setState(() => _isEditingKey = false),
                                style: OutlinedButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10))),
                                child: const Text('Cancel'),
                              ),
                            ],
                          ],
                        ),
                      ] else ...[
                        // Masked Key Display
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                config.maskedApiKey,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  fontFamily: 'Monospace',
                                ),
                              ),
                              TextButton(
                                onPressed: _showRemoveKeyDialog,
                                child: const Text(
                                  'Remove',
                                  style: TextStyle(
                                      color: AppColors.danger,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],

                    // Model selector (for providers with a fixed or fetched list)
                    if (config.providerType != AiProviderType.custom &&
                        config.providerType.availableModels.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Model',
                            style: TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13),
                          ),
                          // "Load from API" button — fetches live model list
                          // using the user's actual API key so only accessible
                          // models appear in the dropdown.
                          if (config.apiKey != null &&
                              config.apiKey!.isNotEmpty)
                            TextButton.icon(
                              onPressed: config.status ==
                                          ApiConnectionStatus.testing ||
                                      _repo.isSaving
                                  ? null
                                  : () => _repo.fetchModels(),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                minimumSize: const Size(0, 0),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              icon: config.status == ApiConnectionStatus.testing
                                  ? const SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 1.5),
                                    )
                                  : const Icon(Icons.refresh,
                                      size: 14, color: AppColors.primary),
                              label: Text(
                                config.fetchedModels != null
                                    ? 'Reload Models'
                                    : 'Load from API',
                                style: const TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        key: ValueKey('model:${_repo.sessionRevision}:'
                            '${config.providerType.name}:${config.selectedModel}:'
                            '${config.effectiveModels.join(',')}'),
                        initialValue: config.selectedModel,
                        isExpanded: true,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          helperText: config.fetchedModels != null
                              ? (config.fetchedModels!
                                      .contains(config.selectedModel)
                                  ? 'Discovered list — model access and meal generation still require verification'
                                  : 'Saved model is absent from the discovered list. It has not been changed automatically.')
                              : 'Suggested models — availability depends on the provider and your account',
                          helperMaxLines: 4,
                          helperStyle: const TextStyle(
                              fontSize: 10, color: AppColors.textMuted),
                        ),
                        items: <String>{
                          config.selectedModel,
                          ...config.effectiveModels
                        }
                            .map((m) => DropdownMenuItem(
                                  value: m,
                                  enabled: AiModelRegistry.find(
                                              config.providerType.toLlmProvider,
                                              m)
                                          ?.selectable ??
                                      true,
                                  child: Text(
                                      AiModelRegistry.label(
                                          config.providerType.toLlmProvider, m),
                                      style: const TextStyle(fontSize: 13),
                                      overflow: TextOverflow.ellipsis),
                                ))
                            .toList(),
                        onChanged: (model) {
                          if (model != null) {
                            _repo.updateModel(model);
                          }
                        },
                      ),
                      const SizedBox(height: 6),
                      Text(
                        AiModelRegistry.note(config.providerType.toLlmProvider,
                            config.selectedModel),
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textMuted),
                      ),
                    ],
                    // Custom model name text field
                    if (config.providerType == AiProviderType.custom) ...[
                      const SizedBox(height: 14),
                      const Text(
                        'Model Name',
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        decoration: InputDecoration(
                          hintText: 'e.g. mistral-7b-instruct',
                          labelText: 'Model',
                          helperText: 'Press Enter to save the exact model ID.',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        controller: _modelController,
                        onSubmitted: (val) {
                          if (val.trim().isNotEmpty) {
                            _repo.updateModel(val.trim());
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      Material(
                        color: AppColors.cardSurface,
                        child: SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Append /chat/completions to URL',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary),
                          ),
                          subtitle: const Text(
                            'On: base URL. Off: exact URL. Both require OpenAI Chat Completions JSON.',
                            style: TextStyle(
                                fontSize: 11, color: AppColors.textMuted),
                          ),
                          value: config.isOpenAiCompatible,
                          onChanged: (val) {
                            _repo.setOpenAiCompatible(val);
                          },
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    const Divider(color: AppColors.border, height: 1),
                    const SizedBox(height: 16),

                    // Connection Status & Test Button
                    LayoutBuilder(
                        builder: (context, constraints) => Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                SizedBox(
                                  width: constraints.maxWidth < 360
                                      ? constraints.maxWidth
                                      : constraints.maxWidth - 180,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            width: 10,
                                            height: 10,
                                            decoration: BoxDecoration(
                                              color:
                                                  _statusColor(config.status),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                              child: Text(
                                            _statusLabel(config.status),
                                            style: TextStyle(
                                              color:
                                                  _statusColor(config.status),
                                              fontWeight: FontWeight.w800,
                                              fontSize: 13,
                                            ),
                                          )),
                                        ],
                                      ),
                                      if (config.statusMessage != null) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          config.statusMessage!,
                                          style: const TextStyle(
                                              color: AppColors.textMuted,
                                              fontSize: 11),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: config.status ==
                                              ApiConnectionStatus.testing ||
                                          _repo.isSaving
                                      ? null
                                      : () async {
                                          final session = _repo.sessionRevision;
                                          if (config.providerType ==
                                                  AiProviderType.custom &&
                                              _modelController.text.trim() !=
                                                  config.selectedModel) {
                                            final saved =
                                                await _repo.updateModel(
                                                    _modelController.text);
                                            if (!saved ||
                                                session !=
                                                    _repo.sessionRevision) {
                                              return;
                                            }
                                          }
                                          await _repo.testConnection();
                                        },
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.primary,
                                    side: const BorderSide(
                                        color: AppColors.primary),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                  ),
                                  icon: config.status ==
                                          ApiConnectionStatus.testing
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        )
                                      : const Icon(Icons.sync, size: 16),
                                  label: const Text('Test Connection',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12)),
                                ),
                              ],
                            )),

                    // Key creation link
                    if (config.providerType.toLlmProvider.keyCreationUrl !=
                        null) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Get an API key at ${config.providerType.toLlmProvider.keyCreationUrl}',
                        style: const TextStyle(
                          color: AppColors.info,
                          fontSize: 11,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  IconData _iconForProvider(AiProviderType type) {
    switch (type) {
      case AiProviderType.openAi:
        return Icons.auto_awesome;
      case AiProviderType.gemini:
        return Icons.eco;
      case AiProviderType.claude:
        return Icons.psychology;
      case AiProviderType.groq:
        return Icons.bolt;
      case AiProviderType.custom:
        return Icons.api;
    }
  }

  Color _statusColor(ApiConnectionStatus status) => status.color;

  String _statusLabel(ApiConnectionStatus status) => status.label;
}

class _RadioDot extends StatelessWidget {
  const _RadioDot({required this.selected});
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.border,
          width: 2,
        ),
      ),
      child: selected
          ? Center(
              child: Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
            )
          : null,
    );
  }
}
