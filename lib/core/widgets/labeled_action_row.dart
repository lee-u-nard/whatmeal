import 'package:flutter/material.dart';

/// Lets a label wrap while keeping its adjacent action visible and tappable.
class LabeledActionRow extends StatelessWidget {
  const LabeledActionRow(
      {super.key, required this.label, required this.action});
  final Widget label;
  final Widget action;

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(child: label),
        action,
      ]);
}
