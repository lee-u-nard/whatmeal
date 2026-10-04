import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// Meal photo that works on Chrome web (CORS) and Android.
///
/// Uses [WebHtmlElementStrategy.prefer] so the browser can display remote
/// images even when canvas CORS would fail.
class MealNetworkImage extends StatelessWidget {
  const MealNetworkImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final image = Image.network(
      url,
      width: width,
      height: height,
      fit: fit,
      webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return _box(
          child: const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
          ),
        );
      },
      errorBuilder: (context, error, stack) => _placeholder(),
    );

    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: image);
    }
    return image;
  }

  Widget _box({required Widget child}) {
    return Container(
      width: width,
      height: height,
      color: AppColors.primaryLight,
      child: child,
    );
  }

  Widget _placeholder() => _box(
        child: Icon(
          Icons.restaurant,
          color: AppColors.primary,
          size: (height != null && height! < 80) ? 28 : 40,
        ),
      );
}
