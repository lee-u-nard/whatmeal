import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class SavedPlanActions extends StatelessWidget {
  const SavedPlanActions(
      {super.key,
      required this.onDelete,
      required this.onReuse,
      required this.onLoad});
  final VoidCallback onDelete;
  final VoidCallback onReuse;
  final VoidCallback onLoad;

  @override
  Widget build(BuildContext context) => Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 4,
        children: [
          TextButton.icon(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline,
                  color: AppColors.danger, size: 16),
              label: const Text('Delete',
                  style: TextStyle(
                      color: AppColors.danger,
                      fontWeight: FontWeight.w700,
                      fontSize: 13))),
          TextButton(onPressed: onReuse, child: const Text('Reuse')),
          ElevatedButton.icon(
              onPressed: onLoad,
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  elevation: 0,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8))),
              icon:
                  const Icon(Icons.folder_open, color: Colors.white, size: 14),
              label: const Text('Load Plan',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13))),
        ],
      );
}
