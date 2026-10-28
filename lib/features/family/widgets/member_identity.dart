import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class MemberIdentity extends StatelessWidget {
  const MemberIdentity(
      {super.key,
      required this.name,
      required this.role,
      required this.roleBackground,
      required this.roleColor});

  final String name;
  final String role;
  final Color roleBackground;
  final Color roleColor;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(name,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
                color: roleBackground, borderRadius: BorderRadius.circular(6)),
            child: Text(role,
                style: TextStyle(
                    color: roleColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      );
}
