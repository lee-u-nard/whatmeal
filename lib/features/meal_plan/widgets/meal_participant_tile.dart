import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class MealParticipantTile extends StatelessWidget {
  const MealParticipantTile(
      {super.key,
      required this.name,
      required this.restrictions,
      required this.selected,
      required this.onChanged});
  final String name;
  final List<String> restrictions;
  final bool selected;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) => Material(
        type: MaterialType.transparency,
        child: CheckboxListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          visualDensity: VisualDensity.compact,
          title: Text(name,
              style: TextStyle(
                  color: selected ? AppColors.primary : AppColors.textPrimary,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 13)),
          subtitle: restrictions.isNotEmpty
              ? Text(
                  restrictions.take(2).join(', ') +
                      (restrictions.length > 2 ? '…' : ''),
                  style: const TextStyle(color: AppColors.danger, fontSize: 10))
              : null,
          activeColor: AppColors.primary,
          checkColor: Colors.white,
          value: selected,
          onChanged: onChanged,
        ),
      );
}
