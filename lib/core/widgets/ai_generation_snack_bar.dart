import 'package:flutter/material.dart';
import '../services/llm_service.dart';
import '../theme/app_theme.dart';

/// Reports the adapter that fulfilled an operation, independently of the user's
/// saved selection, which may differ after fallback or a concurrent edit.
class AiGenerationSnackBar extends SnackBar {
  AiGenerationSnackBar({
    super.key,
    required AiResult<Object?> result,
    String? successMessage,
  }) : super(
          duration: const Duration(seconds: 6),
          backgroundColor:
              result.usedFallback ? AppColors.warning : AppColors.primary,
          content: Text([
            if (successMessage != null && successMessage.trim().isNotEmpty)
              successMessage,
            result.fallbackNotice ??
                'Generated with ${result.providerUsed?.displayName ?? 'an unidentified AI provider'} (${result.modelUsed}).',
          ].join('\n')),
        );
}
