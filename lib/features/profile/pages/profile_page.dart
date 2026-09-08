/*import 'package:flutter/material.dart';


class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext centext) {
    return const Center(child: Text('Profile'));
  } 
}
*/

import 'package:flutter/material.dart';
import '../models/family_member.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  static const _familyMembers = [
    FamilyMember(name: 'David', relation: 'Dad', age: 42,
        preferences: ['Keto', 'High Protein'], restrictions: ['No Spicy']),
    FamilyMember(name: 'Sarah', relation: 'Mom', age: 39,
        preferences: ['Vegetarian Friendly', 'Low Carb'], restrictions: []),
    FamilyMember(name: 'Leo', age: 8,
        preferences: [], restrictions: ['Peanut Allergy', 'No Spicy']),
    FamilyMember(name: 'Emma', age: 5,
        preferences: ['Sweet Lover'], restrictions: ['Dairy Free']),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          "Keep track of your family's dynamic food preferences and severe allergy "
          "restrictions so our AI can plan safe meals.",
          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
        ),
        const SizedBox(height: 16),
        for (final member in _familyMembers) _FamilyMemberCard(member: member),
        _AddFamilyMemberCard(onTap: () {/* TODO: open add-member form */}),
      ],
    );
  }
}

class _FamilyMemberCard extends StatelessWidget {
  const _FamilyMemberCard({required this.member});
  final FamilyMember member;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CircleAvatar(radius: 28, child: Icon(Icons.person)), // TODO: swap for illustrated avatar
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(member.displayName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                      Text('${member.age} yrs', style: TextStyle(color: Colors.grey.shade600)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final pref in member.preferences)
                        _Pill(label: pref, background: Colors.green.shade50, foreground: Colors.green.shade700),
                      for (final r in member.restrictions)
                        _Pill(label: r, background: Colors.red.shade50, foreground: Colors.red.shade700),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
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
      child: Text(label, style: TextStyle(color: foreground, fontSize: 12, fontWeight: FontWeight.w600)),
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
      borderRadius: BorderRadius.circular(16),
      child: CustomPaint(
        painter: _DashedBorderPainter(color: Colors.green.shade400, radius: 16),
        child: SizedBox(
          height: 88,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_circle_outline, color: Colors.green.shade700),
                const SizedBox(width: 8),
                Text('Add Family Member',
                    style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w600)),
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
      ..strokeWidth = 1.5
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