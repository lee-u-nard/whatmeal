import 'package:flutter/material.dart';
import '../../../core/services/family_service.dart';
import '../../../core/theme/app_theme.dart';

/// Create/join share the same draft, validation and pending-operation lifecycle.
class HouseholdAccessSheet extends StatefulWidget {
  const HouseholdAccessSheet(
      {super.key,
      required this.create,
      required this.controller,
      required this.canStart,
      required this.isSessionCurrent,
      required this.sessionChanges,
      required this.isOperationInProgress,
      required this.onSubmit,
      required this.failureMessage,
      required this.onSuccess});
  final bool create;
  final TextEditingController controller;
  final bool Function() canStart;
  final bool Function() isSessionCurrent;
  final Listenable sessionChanges;
  final bool Function() isOperationInProgress;
  final Future<bool> Function(String value) onSubmit;
  final String? Function() failureMessage;
  final VoidCallback onSuccess;
  @override
  State<HouseholdAccessSheet> createState() => _HouseholdAccessSheetState();
}

class _HouseholdAccessSheetState extends State<HouseholdAccessSheet> {
  final _form = GlobalKey<FormState>();
  bool _submitting = false;
  String? _error;
  Future<void> _submit() async {
    if (_submitting) return;
    if (!widget.canStart()) {
      setState(() => _error =
          'Your account or household changed. Close this editor and reopen it.');
      return;
    }
    if (!_form.currentState!.validate()) return;
    if (widget.isOperationInProgress()) {
      setState(() => _error =
          'Another household change is still in progress. Wait and retry.');
      return;
    }
    final value = widget.controller.text.trim();
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final ok = await widget.onSubmit(value);
      if (!mounted || !widget.isSessionCurrent()) return;
      if (ok) {
        widget.onSuccess();
      } else {
        setState(() => _error = widget.failureMessage() ??
            'Household change could not be confirmed. Check your household and retry.');
      }
    } catch (_) {
      if (mounted && widget.isSessionCurrent()) {
        setState(() => _error =
            'Household change could not be confirmed. Check your household and retry.');
      }
    } finally {
      if (mounted && widget.isSessionCurrent()) {
        setState(() => _submitting = false);
      }
    }
  }

  String? _validate(String? input) {
    final value = input?.trim() ?? '';
    if (value.isEmpty) {
      return widget.create
          ? 'Enter a household name.'
          : 'Paste an invitation token.';
    }
    if (widget.create) {
      return value.length > 100 ? 'Use at most 100 characters.' : null;
    }
    try {
      FamilyService.validateToken(value);
    } on StateError catch (error) {
      return error.message;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: widget.sessionChanges,
      builder: (context, _) => widget.isSessionCurrent()
          ? _buildForm(context)
          : SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                  20,
                  20,
                  20,
                  MediaQuery.viewInsetsOf(context).bottom +
                      MediaQuery.paddingOf(context).bottom +
                      20),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text(
                    'Your account or household changed. Close this editor and reopen it.'),
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close')),
              ])));

  Widget _buildForm(BuildContext context) => SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.viewInsetsOf(context).bottom +
                MediaQuery.paddingOf(context).bottom +
                20),
        child: Form(
            key: _form,
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                        child: Text(
                            widget.create
                                ? 'Create Family Space'
                                : 'Join Family Space',
                            style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w800,
                                fontSize: 18))),
                    IconButton(
                        tooltip: 'Close',
                        icon:
                            const Icon(Icons.close, color: AppColors.textMuted),
                        onPressed: () => Navigator.pop(context)),
                  ]),
                  const SizedBox(height: 8),
                  Text(
                      widget.create
                          ? 'Create a private space for your parents, siblings, or roommates to collaborate on meal plans and grocery lists.'
                          : 'Paste the new single-use invitation token from your household owner or admin. Tokens expire after 48 hours by default.',
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 13)),
                  const SizedBox(height: 16),
                  TextFormField(
                      controller: widget.controller,
                      enabled: !_submitting,
                      autocorrect: widget.create,
                      enableSuggestions: widget.create,
                      validator: _validate,
                      decoration: InputDecoration(
                          hintText: widget.create
                              ? 'e.g. The Miller Family Space'
                              : 'Paste invitation token',
                          labelText: widget.create
                              ? 'Family Space Name'
                              : 'Invite Code / Key',
                          prefixIcon: Icon(
                              widget.create
                                  ? Icons.groups_outlined
                                  : Icons.key_outlined,
                              color: AppColors.primary),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)))),
                  if (_error != null)
                    Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Semantics(
                            liveRegion: true,
                            child: Text(_error!,
                                style:
                                    const TextStyle(color: AppColors.danger)))),
                  const SizedBox(height: 20),
                  SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                          onPressed: _submitting ? null : _submit,
                          style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12))),
                          icon: Icon(widget.create ? Icons.add : Icons.login),
                          label: _submitting
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      semanticsLabel: widget.create
                                          ? 'Creating household'
                                          : 'Joining household'))
                              : Text(
                                  widget.create
                                      ? 'Create Space'
                                      : 'Join Family Space',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)))),
                ])),
      );
}
