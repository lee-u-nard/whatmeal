import 'package:flutter/material.dart';

/// A failed feed is not an empty collection. Keep its retry action visible.
class ListenerRecoveryNotice extends StatelessWidget {
  const ListenerRecoveryNotice(
      {super.key,
      required this.message,
      required this.onRetry,
      required this.label});
  final String message;
  final VoidCallback onRetry;
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(message, textAlign: TextAlign.center),
          TextButton(onPressed: onRetry, child: Text(label)),
        ]),
      );
}
