import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../models/family_member.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  static const _familyMembers = [
    FamilyMember(
      name: 'David',
      relation: 'Dad',
      age: 42,
      preferences: ['Keto', 'High Protein'],
      restrictions: ['No Spicy'],
    ),
    FamilyMember(
      name: 'Sarah',
      relation: 'Mom',
      age: 39,
      preferences: ['Vegetarian Friendly', 'Low Carb'],
      restrictions: [],
    ),
    FamilyMember(
      name: 'Leo',
      age: 8,
      preferences: [],
      restrictions: ['Peanut Allergy'],
    ),
    FamilyMember(
      name: 'Emma',
      age: 5,
      preferences: ['Dairy Free', 'Sweet Lover'],
      restrictions: [],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          "Keep track of your family's dynamic food preferences and severe allergy "
          "restrictions so our AI can plan safe meals.",
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 16),
        for (final member in _familyMembers) ...[
          _FamilyMemberCard(member: member),
          const SizedBox(height: 12),
        ],
        _AddFamilyMemberCard(onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Add Family Member modal opened')),
          );
        }),
      ],
    );
  }
}

class _FamilyMemberCard extends StatelessWidget {
  const _FamilyMemberCard({required this.member});
  final FamilyMember member;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primaryLight,
            child: Text(
              member.name[0],
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      member.displayName,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      '${member.age} yrs',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final pref in member.preferences)
                      _Pill(label: pref, background: AppColors.primaryLight, foreground: AppColors.primary),
                    for (final r in member.restrictions)
                      _Pill(label: r, background: AppColors.dangerLight, foreground: AppColors.danger),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.background, required this.foreground});
  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(20)),
      child: Text(
        label,
        style: TextStyle(color: foreground, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _AddFamilyMemberCard extends StatelessWidget {
  const _AddFamilyMemberCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: CustomPaint(
        painter: _DashedBorderPainter(color: AppColors.primary, radius: 14),
        child: const SizedBox(
          height: 52,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add, color: AppColors.primary, size: 20),
                SizedBox(width: 8),
                Text(
                  'Add Family Member',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color, required this.radius});
  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(radius),
    );

    const dashWidth = 6.0;
    const dashSpace = 4.0;
    final path = Path()..addRRect(rrect);

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        canvas.drawPath(metric.extractPath(distance, next.clamp(0, metric.length)), paint);
        distance = next + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) => false;
}