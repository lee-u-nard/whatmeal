import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/llm_service.dart';
import '../../../core/models/llm_config.dart';
import '../../../core/theme/app_theme.dart';

// =============================================================================
// Settings Page
// =============================================================================

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text(
          'Settings',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _AiModelSection(),
          SizedBox(height: 32),
        ],
      ),
    );
  }
}

// =============================================================================
// AI Model Section
// =============================================================================

class _AiModelSection extends StatefulWidget {
  const _AiModelSection();

  @override
  State<_AiModelSection> createState() => _AiModelSectionState();
}

class _AiModelSectionState extends State<_AiModelSection> {
  int? _quotaRemaining;

  @override
  void initState() {
    super.initState();
    _loadQuota();
  }

  Future<void> _loadQuota() async {
    final uid = context.read<AuthService>().uid;
    if (uid == null) return;
    try {
      final quota = await context.read<LlmService>().getRemainingQuota(uid);
      if (mounted) {
        setState(() => _quotaRemaining = quota);
      }
    } catch (_) {
      // Ignore quota fetch errors
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthService>().uid;
    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<LlmConfig>(
      stream: context.read<LlmService>().activeConfigStream(uid),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('AI Settings Error: ${snapshot.error}');
          return Text(
            'Error loading AI settings: ${snapshot.error}',
            style: const TextStyle(color: AppColors.danger),
          );
        }

        if (!snapshot.hasData) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              const Center(child: CircularProgressIndicator()),
            ],
          );
        }

        final config = snapshot.data!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 16),

            // Quota / fallback banner
            if (!config.isCustom)
              _QuotaBanner(quotaRemaining: _quotaRemaining ?? kDailyQuotaLimit),

            const SizedBox(height: 12),

            // Provider cards
            ...LlmProvider.values.map(
              (p) => _ProviderCard(
                provider: p,
                isActive: config.isCustom
                    ? config.provider == p
                    : p == LlmProvider.gemini,
                hasCustomKey: config.isCustom && config.provider == p,
                onTap: () => _onProviderTap(p, config),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AI Model',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'WhatMeal uses AI to generate meal plans. Gemini is free and built in — no setup needed.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
      ],
    );
  }

  Future<void> _onProviderTap(LlmProvider provider, LlmConfig config) async {
    if (!provider.requiresCustomKey) {
      // Tapping Gemini: if there's a custom key, offer to remove it.
      final uid = context.read<AuthService>().uid;
      if (uid != null && config.isCustom) {
        await _showRemoveKeyDialog(uid);
      }
      return;
    }

    // Show bottom sheet for custom-key providers.
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CustomKeySheet(
        provider: provider,
        existingKey: (config.provider == provider && config.isCustom)
            ? config.apiKey
            : null,
      ),
    );
  }

  Future<void> _showRemoveKeyDialog(String uid) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Switch to free Gemini?'),
        content: const Text(
          'Your custom key will be removed and WhatMeal will use the free built-in AI.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Switch to Gemini'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<LlmService>().clearLlmConfig(uid);
    }
  }
}

// =============================================================================
// Quota Banner
// =============================================================================

class _QuotaBanner extends StatelessWidget {
  const _QuotaBanner({required this.quotaRemaining});
  final int quotaRemaining;

  @override
  Widget build(BuildContext context) {
    final isLow = quotaRemaining <= 3;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isLow ? AppColors.warningLight : AppColors.primaryLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isLow ? AppColors.warning.withValues(alpha: 0.4) : AppColors.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isLow ? Icons.warning_amber_rounded : Icons.auto_awesome,
            size: 18,
            color: isLow ? AppColors.warning : AppColors.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isLow
                  ? 'Using free built-in AI · $quotaRemaining of $kDailyQuotaLimit daily generations left'
                  : 'Using free built-in AI · $quotaRemaining of $kDailyQuotaLimit daily generations left',
              style: TextStyle(
                fontSize: 13,
                color: isLow ? AppColors.warning : AppColors.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Provider Card
// =============================================================================

class _ProviderCard extends StatelessWidget {
  const _ProviderCard({
    required this.provider,
    required this.isActive,
    required this.hasCustomKey,
    required this.onTap,
  });

  final LlmProvider provider;
  final bool isActive;
  final bool hasCustomKey;
  final VoidCallback onTap;

  IconData get _icon {
    switch (provider) {
      case LlmProvider.gemini:
        return Icons.auto_awesome;
      case LlmProvider.openai:
        return Icons.psychology_outlined;
      case LlmProvider.anthropic:
        return Icons.lightbulb_outline;
    }
  }

  Color get _accentColor {
    switch (provider) {
      case LlmProvider.gemini:
        return AppColors.primary;
      case LlmProvider.openai:
        return const Color(0xFF10A37F); // OpenAI green
      case LlmProvider.anthropic:
        return const Color(0xFFD97757); // Anthropic orange
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive ? _accentColor : AppColors.border,
            width: isActive ? 2 : 1,
          ),
          boxShadow: [
            if (isActive)
              BoxShadow(
                color: _accentColor.withValues(alpha: 0.12),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Row(
          children: [
            // Icon badge
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_icon, color: _accentColor, size: 22),
            ),
            const SizedBox(width: 14),

            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        provider.displayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (!provider.requiresCustomKey) ...[
                        const SizedBox(width: 8),
                        _Chip(label: 'Free · Built in', color: AppColors.primary),
                      ],
                      if (hasCustomKey) ...[
                        const SizedBox(width: 8),
                        _Chip(label: 'Connected', color: _accentColor),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    provider.description,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            // Trailing indicator
            if (isActive)
              Icon(Icons.check_circle, color: _accentColor, size: 22)
            else if (provider.requiresCustomKey)
              const Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// =============================================================================
// Custom Key Bottom Sheet
// =============================================================================

class _CustomKeySheet extends StatefulWidget {
  const _CustomKeySheet({required this.provider, this.existingKey});
  final LlmProvider provider;
  final String? existingKey;

  @override
  State<_CustomKeySheet> createState() => _CustomKeySheetState();
}

class _CustomKeySheetState extends State<_CustomKeySheet> {
  final _keyController = TextEditingController();
  bool _obscure = true;
  bool _testing = false;
  bool _saving = false;
  bool _testPassed = false;
  String? _testError;

  @override
  void initState() {
    super.initState();
    if (widget.existingKey != null) {
      _keyController.text = widget.existingKey!;
      // Pre-mark as tested if key already saved
      _testPassed = true;
    }
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Color get _accentColor {
    switch (widget.provider) {
      case LlmProvider.gemini:
        return AppColors.primary;
      case LlmProvider.openai:
        return const Color(0xFF10A37F);
      case LlmProvider.anthropic:
        return const Color(0xFFD97757);
    }
  }

  Future<void> _openKeyUrl() async {
    final url = widget.provider.keyCreationUrl;
    if (url == null) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _testConnection() async {
    final key = _keyController.text.trim();
    if (key.isEmpty) {
      setState(() => _testError = 'Paste your key first.');
      return;
    }

    setState(() {
      _testing = true;
      _testError = null;
      _testPassed = false;
    });

    final result =
        await context.read<LlmService>().validateKey(widget.provider, key);

    if (mounted) {
      setState(() {
        _testing = false;
        _testPassed = result.isValid;
        _testError = result.isValid ? null : result.errorMessage;
      });
    }
  }

  Future<void> _save() async {
    final uid = context.read<AuthService>().uid!;
    final key = _keyController.text.trim();

    setState(() => _saving = true);
    try {
      await context.read<LlmService>().saveLlmConfig(
            uid,
            LlmConfig(provider: widget.provider, apiKey: key),
          );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _testError = 'Something went wrong saving. Please try again.';
        });
      }
    }
  }

  Future<void> _removeKey() async {
    final uid = context.read<AuthService>().uid!;
    await context.read<LlmService>().clearLlmConfig(uid);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Title
          Text(
            'Connect ${widget.provider.displayName}',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 20,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),

          // Plain-language explanation
          Text(
            'This connects your own ${widget.provider.displayName} account. '
            '${widget.provider.displayName} will bill you directly for usage — '
            'WhatMeal doesn\'t charge for this.',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 20),

          // "Get my key" button
          if (widget.provider.keyCreationUrl != null)
            OutlinedButton.icon(
              onPressed: _openKeyUrl,
              icon: const Icon(Icons.open_in_new, size: 16),
              label: Text('Get my ${widget.provider.displayName} key'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _accentColor,
                side: BorderSide(color: _accentColor.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),

          const SizedBox(height: 20),

          // Key input
          TextField(
            controller: _keyController,
            obscureText: _obscure,
            onChanged: (_) => setState(() {
              _testPassed = false;
              _testError = null;
            }),
            decoration: InputDecoration(
              labelText: 'Paste your key here',
              hintText: widget.provider == LlmProvider.openai
                  ? 'sk-...'
                  : 'sk-ant-...',
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _accentColor),
              ),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Paste from clipboard shortcut
                  IconButton(
                    icon: const Icon(Icons.content_paste, size: 18),
                    tooltip: 'Paste',
                    onPressed: () async {
                      final data = await Clipboard.getData(Clipboard.kTextPlain);
                      if (data?.text != null) {
                        _keyController.text = data!.text!;
                        setState(() {
                          _testPassed = false;
                          _testError = null;
                        });
                      }
                    },
                  ),
                  IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility_off : Icons.visibility,
                      size: 18,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Test connection feedback
          if (_testPassed)
            _FeedbackBanner(
              icon: Icons.check_circle_outline,
              text: 'Connected! Tap "Save" to start using ${widget.provider.displayName}.',
              color: AppColors.primary,
              bgColor: AppColors.primaryLight,
            )
          else if (_testError != null)
            _FeedbackBanner(
              icon: Icons.error_outline,
              text: _testError!,
              color: AppColors.danger,
              bgColor: AppColors.dangerLight,
            ),

          const SizedBox(height: 16),

          // Test connection button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _testing ? null : _testConnection,
              icon: _testing
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _accentColor,
                      ),
                    )
                  : const Icon(Icons.wifi_tethering),
              label: Text(_testing ? 'Testing…' : 'Test connection'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _accentColor,
                side: BorderSide(color: _accentColor.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Save button — only enabled after a passed test
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: (_testPassed && !_saving) ? _save : null,
              style: FilledButton.styleFrom(
                backgroundColor: _accentColor,
                disabledBackgroundColor: AppColors.border,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text('Save & Use ${widget.provider.displayName}'),
            ),
          ),

          // Remove key (only shown when a key already exists for this provider)
          if (widget.existingKey != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: TextButton(
                onPressed: _removeKey,
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                child: const Text('Remove key · Use free Gemini'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// =============================================================================
// Feedback Banner
// =============================================================================

class _FeedbackBanner extends StatelessWidget {
  const _FeedbackBanner({
    required this.icon,
    required this.text,
    required this.color,
    required this.bgColor,
  });

  final IconData icon;
  final String text;
  final Color color;
  final Color bgColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

