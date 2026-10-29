import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/models/account_action_failure.dart';

/// Bottom sheet for editing the logged-in user's display name and password.
/// Email is read-only to avoid Firebase Auth/Firestore consistency issues.
class EditProfileSheet extends StatefulWidget {
  const EditProfileSheet({
    super.key,
    this.initialName = 'David Miller',
    this.initialEmail = 'david.miller@example.com',
    this.onUpdateName,
    this.onUpdatePassword,
    this.isSessionCurrent,
  });

  final String initialName;
  final String initialEmail;
  final Future<void> Function(String name)? onUpdateName;
  final Future<void> Function(String currentPassword, String newPassword)?
      onUpdatePassword;
  final bool Function()? isSessionCurrent;

  @override
  State<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<EditProfileSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isSaving = false;
  bool _confirming = false;
  String? _error;
  late final bool Function() _isCurrent;

  @override
  void initState() {
    super.initState();
    if (widget.isSessionCurrent != null) {
      _isCurrent = widget.isSessionCurrent!;
    } else {
      final session = AuthRepository.instance.sessionVersion;
      _isCurrent = () => AuthRepository.instance.sessionVersion == session;
    }
    _nameController = TextEditingController(text: widget.initialName);
    _emailController = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _requireCurrent() {
    if (!_isCurrent()) {
      throw const AccountActionFailure(AccountFailureKind.sessionChanged);
    }
  }

  Future<void> _save() async {
    if (_isSaving || _confirming || !_formKey.currentState!.validate()) return;
    setState(() {
      _confirming = _newPasswordController.text.isNotEmpty;
      _isSaving = !_confirming;
      _error = null;
    });
    var passwordChanged = false;
    try {
      _requireCurrent();
      final newName = _nameController.text.trim();
      final currentPassword = _currentPasswordController.text;
      final newPassword = _newPasswordController.text;
      if (newPassword.isNotEmpty) {
        final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
                    title: const Text('Change password?'),
                    content: const Text(
                        'Use the new password the next time you sign in.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel')),
                      ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Change Password'))
                    ]));
        if (confirmed != true) return;
        _requireCurrent();
        setState(() {
          _confirming = false;
          _isSaving = true;
        });
        await (widget.onUpdatePassword?.call(currentPassword, newPassword) ??
            AuthRepository.instance.updatePassword(
                currentPassword: currentPassword, newPassword: newPassword));
        passwordChanged = true;
        // A later name failure must not retry with a now-obsolete password.
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      }
      _requireCurrent();
      if (newName != widget.initialName) {
        await (widget.onUpdateName?.call(newName) ??
            AuthRepository.instance.updateProfile(displayName: newName));
      }
      _requireCurrent();
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Profile updated successfully!'),
          backgroundColor: AppColors.primary));
    } catch (e) {
      if (!mounted) return;
      final message = e is AccountActionFailure
          ? e.message
          : 'Profile could not be saved. Please retry.';
      setState(() =>
          _error = passwordChanged ? 'Password changed. $message' : message);
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _confirming = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
        canPop: !_isSaving && !_confirming,
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.viewInsetsOf(context).bottom +
                MediaQuery.paddingOf(context).bottom +
                24,
          ),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                          child: Text(
                        'Edit Profile',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      )),
                      IconButton(
                        icon:
                            const Icon(Icons.close, color: AppColors.textMuted),
                        tooltip: 'Close',
                        onPressed:
                            _isSaving ? null : () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const Text(
                    'Update your display name or password. Email is read-only.',
                    style:
                        TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 24),

                  // ── Account Details ──────────────────────────────────
                  const _SectionLabel(label: 'ACCOUNT DETAILS'),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _nameController,
                    enabled: !_isSaving,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Display Name',
                      prefixIcon: const Icon(Icons.person_outline,
                          color: AppColors.textMuted),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Name is required'
                        : v.trim().length > 120
                            ? 'Name must be at most 120 characters'
                            : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    enabled: false,
                    decoration: InputDecoration(
                      labelText: 'Email Address',
                      prefixIcon: const Icon(Icons.email_outlined,
                          color: AppColors.textMuted),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: AppColors.background,
                      disabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Email cannot be changed through the app. Contact support if needed.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                  ),
                  const SizedBox(height: 24),

                  // ── Change Password ──────────────────────────────────
                  const _SectionLabel(label: 'CHANGE PASSWORD'),
                  const SizedBox(height: 4),
                  const Text(
                    'Leave these blank to keep your current password.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _currentPasswordController,
                    enabled: !_isSaving,
                    validator: (v) => _newPasswordController.text.isNotEmpty &&
                            (v == null || v.isEmpty)
                        ? 'Current password is required'
                        : null,
                    obscureText: _obscureCurrent,
                    decoration: InputDecoration(
                      labelText: 'Current Password',
                      prefixIcon: const Icon(Icons.lock_outline,
                          color: AppColors.textMuted),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureCurrent
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: AppColors.textMuted,
                        ),
                        tooltip:
                            _obscureCurrent ? 'Show password' : 'Hide password',
                        onPressed: () =>
                            setState(() => _obscureCurrent = !_obscureCurrent),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _newPasswordController,
                    enabled: !_isSaving,
                    obscureText: _obscureNew,
                    decoration: InputDecoration(
                      labelText: 'New Password',
                      prefixIcon: const Icon(Icons.lock_outline,
                          color: AppColors.textMuted),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureNew
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: AppColors.textMuted,
                        ),
                        tooltip:
                            _obscureNew ? 'Show password' : 'Hide password',
                        onPressed: () =>
                            setState(() => _obscureNew = !_obscureNew),
                      ),
                    ),
                    validator: (v) {
                      if (v != null && v.isNotEmpty && v.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _confirmPasswordController,
                    enabled: !_isSaving,
                    obscureText: _obscureConfirm,
                    decoration: InputDecoration(
                      labelText: 'Confirm New Password',
                      prefixIcon: const Icon(Icons.lock_outline,
                          color: AppColors.textMuted),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirm
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: AppColors.textMuted,
                        ),
                        tooltip:
                            _obscureConfirm ? 'Show password' : 'Hide password',
                        onPressed: () =>
                            setState(() => _obscureConfirm = !_obscureConfirm),
                      ),
                    ),
                    validator: (v) {
                      if (_newPasswordController.text.isNotEmpty &&
                          v != _newPasswordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                  ),
                  if (_error != null)
                    Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(_error!,
                            style: const TextStyle(color: AppColors.danger))),
                  const SizedBox(height: 28),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: (_isSaving || _confirming) ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'Save Changes',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 15),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ));
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: AppColors.textMuted,
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
      ),
    );
  }
}
