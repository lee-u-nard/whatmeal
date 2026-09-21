import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../data/ai_provider_repository.dart';
import '../models/ai_provider.dart';

class AiSettingsPage extends StatefulWidget {
  const AiSettingsPage({super.key});

  @override
  State<AiSettingsPage> createState() => _AiSettingsPageState();
}

class _AiSettingsPageState extends State<AiSettingsPage> {
  final _keyController = TextEditingController();
  bool _isEditingKey = false;
  bool _showRawKey = false;

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  void _showRemoveKeyDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Remove API Key'),
          content: const Text(
            'Are you sure you want to remove your saved API key? You will not be able to generate AI meal plans until a valid key is provided.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () {
                AiProviderRepository.instance.removeKey();
                Navigator.pop(ctx);
                setState(() => _isEditingKey = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('API Key removed.')),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
              child: const Text('Remove Key', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AiProviderConfig>(
      valueListenable: AiProviderRepository.instance,
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
              style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 16),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Configure your preferred AI engine to generate personalized family meal plans and smart pantry recommendations.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 20),

              // Provider Selection List
              const Text(
                'Select AI Provider',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),

              Column(
                children: AiProviderType.values.map((type) {
                  final isSelected = config.providerType == type;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      onTap: () => AiProviderRepository.instance.selectProvider(type),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.cardSurface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected ? AppColors.primary : AppColors.border,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.primaryLight : AppColors.background,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                _iconForProvider(type),
                                color: isSelected ? AppColors.primary : AppColors.textSecondary,
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
                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Default model: ${type.defaultModel}',
                                    style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected ? AppColors.primary : AppColors.border,
                                  width: 2,
                                ),
                              ),
                              child: isSelected
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
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 20),

              // API Key Management Card
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
                        Row(
                          children: [
                            const Icon(Icons.key, color: AppColors.primary, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              '${config.providerType.displayName} Key',
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                        if (config.apiKey != null && !_isEditingKey)
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, color: AppColors.primary, size: 18),
                            onPressed: () {
                              _keyController.text = config.apiKey ?? '';
                              setState(() => _isEditingKey = true);
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (_isEditingKey || config.apiKey == null || config.apiKey!.isEmpty) ...[
                      TextField(
                        controller: _keyController,
                        obscureText: !_showRawKey,
                        decoration: InputDecoration(
                          hintText: 'Enter API Key (e.g. sk-...)',
                          labelText: 'API Key',
                          suffixIcon: IconButton(
                            icon: Icon(
                              _showRawKey ? Icons.visibility_off : Icons.visibility,
                              color: AppColors.textMuted,
                            ),
                            onPressed: () => setState(() => _showRawKey = !_showRawKey),
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                if (_keyController.text.trim().isNotEmpty) {
                                  AiProviderRepository.instance.setApiKey(_keyController.text.trim());
                                  setState(() => _isEditingKey = false);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('API key updated!'),
                                      backgroundColor: AppColors.primary,
                                    ),
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: const Text('Save Key', style: TextStyle(fontWeight: FontWeight.w700)),
                            ),
                          ),
                          if (_isEditingKey && config.apiKey != null) ...[
                            const SizedBox(width: 8),
                            OutlinedButton(
                              onPressed: () => setState(() => _isEditingKey = false),
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ],
                        ],
                      ),
                    ] else ...[
                      // Masked Key Display
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                                style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),
                    const Divider(color: AppColors.border, height: 1),
                    const SizedBox(height: 16),

                    // Connection Status & Test Button
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: _statusColor(config.status),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _statusLabel(config.status),
                                    style: TextStyle(
                                      color: _statusColor(config.status),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              if (config.statusMessage != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  config.statusMessage!,
                                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                                ),
                              ],
                            ],
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: config.status == ApiConnectionStatus.testing
                              ? null
                              : () => AiProviderRepository.instance.testConnection(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: config.status == ApiConnectionStatus.testing
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.sync, size: 16),
                          label: const Text('Test Connection', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                        ),
                      ],
                    ),
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

  Color _statusColor(ApiConnectionStatus status) {
    switch (status) {
      case ApiConnectionStatus.notConfigured:
        return AppColors.textMuted;
      case ApiConnectionStatus.testing:
        return AppColors.warning;
      case ApiConnectionStatus.connected:
        return AppColors.primary;
      case ApiConnectionStatus.failed:
        return AppColors.danger;
    }
  }

  String _statusLabel(ApiConnectionStatus status) {
    switch (status) {
      case ApiConnectionStatus.notConfigured:
        return 'Not Configured';
      case ApiConnectionStatus.testing:
        return 'Testing...';
      case ApiConnectionStatus.connected:
        return 'Connected';
      case ApiConnectionStatus.failed:
        return 'Connection Failed';
    }
  }
}
