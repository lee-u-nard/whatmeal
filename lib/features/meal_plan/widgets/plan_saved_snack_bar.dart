import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class PlanSavedSnackBar extends SnackBar {
  PlanSavedSnackBar(
      {super.key, required String title, required VoidCallback onView})
      : super(
          duration: const Duration(seconds: 6),
          persist: false,
          backgroundColor: AppColors.primary,
          content: Row(children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
                child: Text('Saved "$title"!',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700))),
          ]),
          action: SnackBarAction(
              label: 'View', textColor: Colors.white, onPressed: onView),
        );
}
