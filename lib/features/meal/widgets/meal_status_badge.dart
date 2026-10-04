import 'package:flutter/material.dart';
import '../models/meal.dart';

class MealStatusBadge extends StatelessWidget {
  const MealStatusBadge({
    super.key,
    required this.status,
    this.compact = false,
  });

  final MealStatus status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color border;
    Color text;
    IconData icon;
    String label;

    switch (status) {
      case MealStatus.pending:
        bg = const Color(0xFFFFF8E1);
        border = const Color(0xFFFFE082);
        text = const Color(0xFFB78103);
        icon = Icons.hourglass_empty_rounded;
        label = compact ? 'Pending' : 'Pending Decision';
        break;
      case MealStatus.accepted:
        bg = const Color(0xFFE8F5E9);
        border = const Color(0xFFA5D6A7);
        text = const Color(0xFF2E7D32);
        icon = Icons.check_circle_outline_rounded;
        label = 'Accepted';
        break;
      case MealStatus.completed:
        bg = const Color(0xFFE0F2F1);
        border = const Color(0xFF80CBC4);
        text = const Color(0xFF00695C);
        icon = Icons.task_alt_rounded;
        label = compact ? 'Done' : 'Completed';
        break;
      case MealStatus.notCompleted:
        bg = const Color(0xFFFFEBEE);
        border = const Color(0xFFFFCDD2);
        text = const Color(0xFFC62828);
        icon = Icons.cancel_outlined;
        label = compact ? 'Skipped' : 'Not Completed';
        break;
      case MealStatus.replaced:
        bg = const Color(0xFFF5F5F5);
        border = const Color(0xFFE0E0E0);
        text = const Color(0xFF757575);
        icon = Icons.swap_horiz_rounded;
        label = 'Replaced';
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 11 : 13, color: text),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: text,
              fontSize: compact ? 10 : 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
