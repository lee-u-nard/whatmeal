import 'package:flutter/material.dart';

/// Protects an in-memory plan until saving succeeds or discard is explicit.
class UnsavedPlanGuard extends StatefulWidget {
  const UnsavedPlanGuard({
    super.key,
    required this.hasUnsavedPlan,
    required this.onSave,
    required this.child,
  });

  final bool hasUnsavedPlan;
  final VoidCallback onSave;
  final Widget child;

  @override
  State<UnsavedPlanGuard> createState() => _UnsavedPlanGuardState();
}

class _UnsavedPlanGuardState extends State<UnsavedPlanGuard> {
  bool _discard = false;
  bool _asking = false;

  Future<void> _confirmExit() async {
    if (_asking || !widget.hasUnsavedPlan) return;
    _asking = true;
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save this meal plan?'),
        content: const Text(
            'This plan has not been saved. Leaving will discard its meals and edits.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'keep'),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            child: const Text('Discard'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'save'),
            child: const Text('Save Plan'),
          ),
        ],
      ),
    );
    _asking = false;
    // An account change can invalidate the draft while the dialog is open.
    if (!mounted || !widget.hasUnsavedPlan) return;
    if (action == 'save') {
      widget.onSave();
    } else if (action == 'discard') {
      setState(() => _discard = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope<Object?>(
        canPop: !widget.hasUnsavedPlan || _discard,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) _confirmExit();
        },
        child: widget.child,
      );
}
