import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/data/auth_repository.dart';
import '../data/family_repository.dart';
import '../models/family_space.dart';

class FamilySpacePage extends StatefulWidget {
  const FamilySpacePage({super.key});

  @override
  State<FamilySpacePage> createState() => _FamilySpacePageState();
}

class _FamilySpacePageState extends State<FamilySpacePage> {
  final _joinCodeController = TextEditingController();
  final _newSpaceNameController = TextEditingController();

  @override
  void dispose() {
    _joinCodeController.dispose();
    _newSpaceNameController.dispose();
    super.dispose();
  }

  void _copyInviteCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text('Invite code "$code" copied to clipboard!'),
          ],
        ),
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showJoinModal() {
    _joinCodeController.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Join Family Space',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textMuted),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Enter the 6-character unique invite code shared by your family owner or household admin.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _joinCodeController,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: 'e.g. WM-8K92F',
                  labelText: 'Invite Code / Key',
                  prefixIcon:
                      const Icon(Icons.key_outlined, color: AppColors.primary),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final code = _joinCodeController.text;
                    if (code.trim().isNotEmpty) {
                      final messenger = ScaffoldMessenger.of(context);
                      final navigator = Navigator.of(ctx);
                      final ok = await FamilyRepository.instance
                          .joinSpaceWithKey(code);
                      navigator.pop();
                      if (ok) {
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Successfully joined family space!'),
                            backgroundColor: AppColors.primary,
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.login),
                  label: const Text('Join Family Space',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCreateSpaceModal() {
    _newSpaceNameController.text = 'The Miller Household';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Create Family Space',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textMuted),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Create a private space for your parents, siblings, or roommates to collaborate on meal plans and grocery lists.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _newSpaceNameController,
                decoration: InputDecoration(
                  hintText: 'e.g. The Miller Family Space',
                  labelText: 'Family Space Name',
                  prefixIcon: const Icon(Icons.groups_outlined,
                      color: AppColors.primary),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    if (_newSpaceNameController.text.trim().isNotEmpty) {
                      final messenger = ScaffoldMessenger.of(context);
                      final navigator = Navigator.of(ctx);
                      await FamilyRepository.instance
                          .createSpace(_newSpaceNameController.text.trim());
                      navigator.pop();
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Created new Family Space!'),
                          backgroundColor: AppColors.primary,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Create Space',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showRoleDialog(SharedSpaceMember member) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Manage Role for ${member.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: FamilyRole.values.map((role) {
              final isSelected = member.role == role;
              return InkWell(
                onTap: () {
                  FamilyRepository.instance.updateMemberRole(member.id, role);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content:
                            Text('Updated ${member.name} to ${role.label}')),
                  );
                },
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.border,
                            width: 2,
                          ),
                        ),
                        child: isSelected
                            ? Center(
                                child: Container(
                                  width: 10,
                                  height: 10,
                                  decoration: const BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Text(role.label,
                          style: TextStyle(
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w600,
                            fontSize: 14,
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.textPrimary,
                          )),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
          ],
        );
      },
    );
  }

  void _confirmRemoveMember(SharedSpaceMember member) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Remove Member'),
          content: Text(
              'Are you sure you want to remove ${member.name} from this family space? They will lose access to shared meal plans and grocery lists.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () {
                FamilyRepository.instance.removeMember(member.id);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content:
                          Text('Removed ${member.name} from family space.')),
                );
              },
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
              child: const Text('Remove',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );
  }

  void _confirmLeaveSpace() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Leave Family Space'),
          content: const Text(
              'Are you sure you want to leave this family space? You can rejoin anytime if you have an active invite key.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await FamilyRepository.instance.leaveSpace();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('You have left the family space.')),
                );
              },
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
              child: const Text('Leave Space',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeleteSpace() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.danger),
              SizedBox(width: 8),
              Text('Delete Household',
                  style: TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
          content: const Text(
            'Are you sure you want to permanently delete this household space? All members will be disconnected and unlinked. This cannot be undone.',
            style: TextStyle(fontSize: 13, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                final ok = await FamilyRepository.instance.deleteSpace();
                if (!mounted) return;
                if (ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content:
                          Text('Household space was successfully deleted.'),
                      backgroundColor: AppColors.primary,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(FamilyRepository.instance.error ??
                          'Could not delete household.'),
                      backgroundColor: AppColors.danger,
                    ),
                  );
                }
              },
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
              child: const Text('Delete Permanently',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = AuthRepository.instance.currentUser?.uid;
    return ValueListenableBuilder<FamilySpace?>(
      valueListenable: FamilyRepository.instance,
      builder: (context, familySpace, _) {
        final isOwner = familySpace?.isOwner(currentUid) ?? false;
        final canManageMembers =
            familySpace?.canManageMembers(currentUid) ?? false;
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
              onPressed: () => context.pop(),
            ),
            title: const Text(
              'Family Sharing Space',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 16),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (familySpace == null) ...[
                // Empty Family Space State
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.cardSurface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.group_add_outlined,
                          size: 64, color: AppColors.primary),
                      const SizedBox(height: 16),
                      const Text(
                        'No Shared Family Space',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Create a family space to share meal plans and grocery lists with your household, or join using an invite code.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                            height: 1.4),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _showJoinModal,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                side:
                                    const BorderSide(color: AppColors.primary),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.key, size: 18),
                              label: const Text('Join with Key',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w700)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _showCreateSpaceModal,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('Create Space',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Space Header Banner Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                        color: Color.fromRGBO(46, 125, 50, 0.15),
                        blurRadius: 16,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.groups,
                                    color: Colors.white, size: 24),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                familySpace.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon:
                                const Icon(Icons.logout, color: Colors.white70),
                            tooltip: 'Leave Family Space',
                            onPressed: _confirmLeaveSpace,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Invite Key Container
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.key,
                                color: AppColors.primary, size: 20),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'UNIQUE INVITE KEY',
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                Text(
                                  familySpace.inviteCode,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.copy,
                                  color: AppColors.primary),
                              tooltip: 'Copy Code',
                              onPressed: () =>
                                  _copyInviteCode(familySpace.inviteCode),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  _copyInviteCode(familySpace.inviteCode),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: Colors.white70),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.share, size: 16),
                              label: const Text('Share Code',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _showJoinModal,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: Colors.white70),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.login, size: 16),
                              label: const Text('Join Another',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Members List Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Household Members (${familySpace.members.length})',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _copyInviteCode(familySpace.inviteCode),
                      icon: const Icon(Icons.person_add_alt_1,
                          size: 16, color: AppColors.primary),
                      label: const Text('Invite Member',
                          style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => context.push('/household-dashboard'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.dashboard_outlined, size: 18),
                    label: const Text(
                      'Open Household Dashboard',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Members Cards
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.cardSurface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < familySpace.members.length; i++) ...[
                        _buildMemberTile(
                          context,
                          familySpace.members[i],
                          canManageMembers: canManageMembers,
                        ),
                        if (i != familySpace.members.length - 1)
                          const Divider(
                              height: 1,
                              indent: 16,
                              endIndent: 16,
                              color: AppColors.border),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Household Role & Permissions Banner
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.cardSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isOwner
                                ? Icons.verified_user
                                : Icons.shield_outlined,
                            size: 18,
                            color: isOwner ? AppColors.primary : AppColors.info,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Your Role: ${familySpace.roleForUid(currentUid).label}',
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Household owners and authorized members can view shared meal plans, monitor, accept, and replace meals, and manage pantry items and groceries.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Household Management / Danger Zone Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.cardSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isOwner
                          ? AppColors.danger.withValues(alpha: 0.3)
                          : AppColors.border,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.delete_forever_outlined,
                            color: isOwner
                                ? AppColors.danger
                                : AppColors.textMuted,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Delete Household',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                          const Spacer(),
                          if (!isOwner)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.lock,
                                      size: 10, color: Colors.grey),
                                  SizedBox(width: 4),
                                  Text(
                                    'Owner Only',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isOwner
                            ? 'Permanently delete this household space and unlink all members. This cannot be undone.'
                            : 'Only the household owner has permission to delete this household space.',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (isOwner)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _confirmDeleteSpace,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.danger,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.delete_outline, size: 18),
                            label: const Text(
                              'Delete Household Space',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        )
                      else
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _confirmLeaveSpace,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.danger,
                              side: const BorderSide(color: AppColors.danger),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.logout, size: 18),
                            label: const Text(
                              'Leave Household Space',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildMemberTile(
    BuildContext context,
    SharedSpaceMember member, {
    required bool canManageMembers,
  }) {
    Color roleBg = AppColors.primaryLight;
    Color roleText = AppColors.primary;
    if (member.role == FamilyRole.owner) {
      roleBg = AppColors.primaryLight;
      roleText = AppColors.primary;
    } else if (member.role == FamilyRole.admin) {
      roleBg = AppColors.infoLight;
      roleText = AppColors.info;
    } else if (member.role == FamilyRole.viewOnly) {
      roleBg = AppColors.warningLight;
      roleText = AppColors.warning;
    }

    final canEditThisMember =
        canManageMembers && member.role != FamilyRole.owner;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: AppColors.primaryLight,
        child: Text(
          member.name[0],
          style: const TextStyle(
              color: AppColors.primary, fontWeight: FontWeight.w800),
        ),
      ),
      title: Row(
        children: [
          Text(
            member.name,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
                color: roleBg, borderRadius: BorderRadius.circular(6)),
            child: Text(
              member.role.label,
              style: TextStyle(
                  color: roleText, fontSize: 10, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      subtitle: Text(member.email,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
      trailing: canEditThisMember
          ? PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: AppColors.textMuted),
              onSelected: (val) {
                if (val == 'role') {
                  _showRoleDialog(member);
                } else if (val == 'remove') {
                  _confirmRemoveMember(member);
                }
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'role',
                  child: Row(
                    children: [
                      Icon(Icons.admin_panel_settings_outlined,
                          size: 18, color: AppColors.primary),
                      SizedBox(width: 8),
                      Text('Change Role'),
                    ],
                  ),
                ),
                if (member.role != FamilyRole.owner)
                  const PopupMenuItem(
                    value: 'remove',
                    child: Row(
                      children: [
                        Icon(Icons.person_remove_outlined,
                            size: 18, color: AppColors.danger),
                        SizedBox(width: 8),
                        Text('Remove Member',
                            style: TextStyle(color: AppColors.danger)),
                      ],
                    ),
                  ),
              ],
            )
          : null,
    );
  }
}
