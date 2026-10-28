import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class GroceryToolbar extends StatelessWidget {
  const GroceryToolbar(
      {super.key,
      required this.remainingCount,
      required this.onShare,
      required this.onClearUsed});
  final int remainingCount;
  final VoidCallback onShare;
  final VoidCallback onClearUsed;

  @override
  Widget build(BuildContext context) => Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('$remainingCount remaining items',
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14)),
          Wrap(children: [
            TextButton.icon(
                onPressed: onShare,
                icon:
                    const Icon(Icons.share, size: 14, color: AppColors.primary),
                label: const Text('Share List',
                    style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13))),
            TextButton.icon(
                onPressed: onClearUsed,
                icon: const Icon(Icons.cleaning_services_outlined,
                    size: 14, color: AppColors.danger),
                label: const Text('Clear Used',
                    style: TextStyle(
                        color: AppColors.danger,
                        fontWeight: FontWeight.w700,
                        fontSize: 13))),
          ]),
        ],
      );
}
