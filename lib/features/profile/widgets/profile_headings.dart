import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class FamilyProfilesHeading extends StatelessWidget {
  const FamilyProfilesHeading({super.key, required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Row(children: [
        const Expanded(
          child: Text('Family Profiles & Dietary Preferences',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 16)),
        ),
        TextButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add, size: 16, color: AppColors.primary),
          label: const Text('Add',
              style: TextStyle(
                  color: AppColors.primary, fontWeight: FontWeight.w700)),
        ),
      ]);
}

class ProfileSettingsIdentity extends StatelessWidget {
  const ProfileSettingsIdentity(
      {super.key,
      required this.icon,
      required this.badgeText,
      required this.color,
      required this.iconColor});
  final IconData icon;
  final String badgeText;
  final Color color;
  final Color iconColor;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          Flexible(
              child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(4)),
            child: Text(badgeText,
                style: TextStyle(
                    color: iconColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          )),
        ],
      );
}
