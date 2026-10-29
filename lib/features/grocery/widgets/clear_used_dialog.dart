import 'package:flutter/material.dart';

Future<bool> confirmClearUsed(BuildContext context) async =>
    await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Clear purchased items?'),
              content: const Text(
                  'Remove purchased manual items from this list? Meal requirements are retained.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel')),
                ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Clear Used')),
              ],
            )) ??
    false;
