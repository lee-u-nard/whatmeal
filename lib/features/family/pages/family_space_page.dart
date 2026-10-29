import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../data/family_repository.dart';
import '../models/family_space.dart';
import '../widgets/member_identity.dart';
import '../widgets/household_access_sheet.dart';

class FamilySpacePage extends StatefulWidget {
  const FamilySpacePage({super.key, this.repository});
  final FamilyRepository? repository;

  @override
  State<FamilySpacePage> createState() => _FamilySpacePageState();
}

class _FamilySpacePageState extends State<FamilySpacePage> {
  FamilyRepository get _repo => widget.repository ?? FamilyRepository.instance;
  // Dialogs and sheets may remain open while Auth/household listeners change.
  bool Function() _captureScope() {
    final session = _repo.sessionVersion;
    final id = _repo.scopeId;
    final joinedAt = _repo.value?.memberForUid(_repo.currentUid)?.joinedAt;
    return () {
      if (!mounted) return false;
      if (_repo.sessionVersion == session &&
          _repo.scopeId == id &&
          _repo.value?.memberForUid(_repo.currentUid)?.joinedAt == joinedAt) {
        return true;
      }
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Your account or household changed. Reopen this action.')));
      return false;
    };
  }

  final _joinCodeController = TextEditingController();
  final _newSpaceNameController = TextEditingController();

  @override
  void dispose() {
    _joinCodeController.dispose();
    _newSpaceNameController.dispose();
    super.dispose();
  }

  Future<void> _copyInviteCode(String code) async {
    try {
      await Clipboard.setData(ClipboardData(text: code));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not copy the invitation. Please retry.')));
      }
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            const Text('Invitation token copied to clipboard.'),
          ],
        ),
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _manageInvitations() {
    final stillCurrent = _captureScope();
    final session = _repo.sessionVersion;
    final stream = _repo.invitationRefs();
    showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text('Manage invitations'),
              content: SizedBox(
                  width: 360,
                  height: 300,
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: stream,
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return const Text(
                              'Invitation access is unavailable.');
                        }
                        if (!snapshot.hasData) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }
                        if (snapshot.data!.docs.isEmpty) {
                          return const Text('No invitations yet.');
                        }
                        return ListView(
                            children: snapshot.data!.docs
                                .map((doc) => ListTile(
                                      title: Text(
                                          'Expires ${(doc.data()['expiresAt'] as Timestamp).toDate().toLocal()}'),
                                      subtitle: const Text(
                                          'Single use. Revocation applies to unused tokens.'),
                                      trailing: IconButton(
                                          icon: const Icon(Icons.block),
                                          tooltip: 'Revoke invitation',
                                          onPressed: () async {
                                            if (!stillCurrent()) return;
                                            final ok =
                                                await _repo.revokeToken(doc.id);
                                            if (!mounted ||
                                                _repo.sessionVersion !=
                                                    session) {
                                              return;
                                            }
                                            ScaffoldMessenger.of(this.context)
                                                .showSnackBar(SnackBar(
                                                    content: Text(ok
                                                        ? 'Invitation revoked.'
                                                        : 'Invitation is already used/revoked, or access is unavailable.')));
                                          }),
                                    ))
                                .toList());
                      })),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Close'))
              ],
            ));
  }

  Future<void> _issueInvitation() async {
    final stillCurrent = _captureScope();
    final ok = await _repo.regenerateInviteKey();
    if (!mounted) return;
    if (!stillCurrent()) return;
    final token = _repo.activeInvitationToken;
    if (ok && token != null) {
      _copyInviteCode(token);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_repo.error ?? 'Could not create invitation.')));
    }
  }

  Future<void> _offerOwnership(SharedSpaceMember member) async {
    final stillCurrent = _captureScope();
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
                title: const Text('Offer ownership transfer?'),
                content: Text(
                    '${member.name} must accept. You will become an admin when they do.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel')),
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Offer transfer'))
                ]));
    if (confirmed == true && stillCurrent()) {
      await _repo.offerOwnership(member.id);
    }
  }

  Future<void> _acceptOwnership() async {
    final stillCurrent = _captureScope();
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
                title: const Text('Accept household ownership?'),
                content: const Text(
                    'You will manage household access and archival. The previous owner becomes an admin.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel')),
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Accept ownership'))
                ]));
    if (confirmed == true && stillCurrent()) await _repo.acceptOwnership();
  }

  void _showJoinModal() => _showAccessModal(create: false);

  void _showCreateSpaceModal() => _showAccessModal(create: true);

  void _showAccessModal({required bool create}) {
    final stillCurrent = _captureScope();
    final session = _repo.sessionVersion;
    final controller = create ? _newSpaceNameController : _joinCodeController;
    controller.text = create ? 'The Miller Household' : '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => HouseholdAccessSheet(
        create: create,
        controller: controller,
        canStart: stillCurrent,
        isSessionCurrent: () => mounted && _repo.sessionVersion == session,
        sessionChanges: _repo,
        isOperationInProgress: () => _repo.isLoading,
        onSubmit: create ? _repo.createSpace : _repo.joinSpaceWithKey,
        failureMessage: () => _repo.error,
        onSuccess: () {
          if (!mounted || !ctx.mounted || _repo.sessionVersion != session) {
            return;
          }
          Navigator.of(ctx).pop();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(create
                ? 'Created new Family Space!'
                : 'Successfully joined family space!'),
            backgroundColor: AppColors.primary,
          ));
        },
      ),
    );
  }

  void _showRoleDialog(SharedSpaceMember member) {
    final stillCurrent = _captureScope();
    final session = _repo.sessionVersion;
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Manage Role for ${member.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: FamilyRole.values
                .where((role) =>
                    role != FamilyRole.owner &&
                    (_repo.value?.isOwner(_repo.currentUid) == true ||
                        role != FamilyRole.admin))
                .map((role) {
              final isSelected = member.role == role;
              return InkWell(
                onTap: () async {
                  if (!stillCurrent()) return;
                  Navigator.pop(ctx);
                  final ok = await _repo.updateMemberRole(member.id, role);
                  if (!mounted || _repo.sessionVersion != session) {
                    return;
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(ok
                            ? 'Updated ${member.name} to ${role.label}'
                            : _repo.error ?? 'Role update failed.')),
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
    final stillCurrent = _captureScope();
    final session = _repo.sessionVersion;
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
              onPressed: () async {
                if (!stillCurrent()) return;
                Navigator.pop(ctx);
                final ok = await _repo.removeMember(member.id);
                if (!mounted || _repo.sessionVersion != session) {
                  return;
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text(ok
                          ? 'Removed ${member.name} from family space.'
                          : _repo.error ?? 'Removal failed.')),
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
    final stillCurrent = _captureScope();
    final session = _repo.sessionVersion;
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
                if (!stillCurrent()) return;
                Navigator.pop(ctx);
                final ok = await _repo.leaveSpace();
                if (!mounted || _repo.sessionVersion != session) {
                  return;
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text(ok
                          ? 'You have left the family space.'
                          : _repo.error ?? 'Leave failed.')),
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
    final stillCurrent = _captureScope();
    final session = _repo.sessionVersion;
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
              Text('Archive Household',
                  style: TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
          content: const Text(
            'Are you sure you want to archive this household space? Shared access will stop. Data is retained; members can leave, and the owner can restore it while retaining membership.',
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
                if (!stillCurrent()) return;
                Navigator.pop(ctx);
                final ok = await _repo.deleteSpace();
                if (!mounted || _repo.sessionVersion != session) {
                  return;
                }
                if (ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Household was archived. Its data has been retained.'),
                      backgroundColor: AppColors.primary,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:
                          Text(_repo.error ?? 'Could not archive household.'),
                      backgroundColor: AppColors.danger,
                    ),
                  );
                }
              },
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
              child: const Text('Archive Household',
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
    return ValueListenableBuilder<FamilySpace?>(
      valueListenable: _repo,
      builder: (context, familySpace, _) {
        final currentUid = _repo.currentUid;
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
          bottomNavigationBar: _repo.isLoading
              ? SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const LinearProgressIndicator(color: AppColors.primary),
                      const SizedBox(height: 8),
                      Semantics(
                        liveRegion: true,
                        child: const Text(
                          'Updating household. Waiting for confirmation…',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ]),
                  ),
                )
              : null,
          body: AbsorbPointer(
            absorbing: _repo.isLoading,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (_repo.error != null)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(_repo.error!,
                          style: const TextStyle(color: AppColors.danger))),
                if (_repo.error != null)
                  TextButton.icon(
                      onPressed: _repo.retry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry household connection')),
                if (familySpace == null &&
                    _repo.unavailableFamilyId != null) ...[
                  if (_repo.canRestore)
                    TextButton(
                        onPressed: () => _repo.restoreSpace(),
                        child: const Text('Restore archived household')),
                  TextButton(
                      onPressed: _confirmLeaveSpace,
                      child: const Text('Leave unavailable household')),
                ],
                if (_repo.pendingTransferToUid == currentUid &&
                    currentUid != null)
                  TextButton(
                      onPressed: _acceptOwnership,
                      child: const Text('Review ownership offer')),
                if (canManageMembers && _repo.activeInvitationToken != null)
                  TextButton(
                      onPressed: () => _repo.revokeInvite(),
                      child: const Text('Revoke last invitation')),
                if (canManageMembers)
                  TextButton(
                      onPressed: _manageInvitations,
                      child: const Text('Manage invitations')),
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
                                  side: const BorderSide(
                                      color: AppColors.primary),
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
                            Expanded(
                                child: Row(
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
                                Expanded(
                                    child: Text(
                                  familySpace.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 18,
                                  ),
                                )),
                              ],
                            )),
                            IconButton(
                              icon: const Icon(Icons.logout,
                                  color: Colors.white70),
                              tooltip: 'Leave Family Space',
                              onPressed: _confirmLeaveSpace,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Invitation capabilities are restricted to managers.
                        if (canManageMembers)
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
                                Expanded(
                                    child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'SINGLE-USE INVITATION',
                                      style: TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    Text(
                                      'Expires in 48 hours',
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 18,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                  ],
                                )),
                                IconButton(
                                  icon: const Icon(Icons.copy,
                                      color: AppColors.primary),
                                  tooltip: 'Create invitation',
                                  onPressed: _issueInvitation,
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 12),

                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed:
                                    canManageMembers ? _issueInvitation : null,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(color: Colors.white70),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                ),
                                icon: const Icon(Icons.share, size: 16),
                                label: const Text('Create Invitation',
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
                      Expanded(
                          child: Text(
                        'Household Members (${familySpace.members.length})',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      )),
                      Flexible(
                          child: TextButton.icon(
                        onPressed: canManageMembers ? _issueInvitation : null,
                        icon: const Icon(Icons.person_add_alt_1,
                            size: 16, color: AppColors.primary),
                        label: const Text('Invite Member',
                            style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700)),
                      )),
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
                        for (var i = 0;
                            i < familySpace.members.length;
                            i++) ...[
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
                              color:
                                  isOwner ? AppColors.primary : AppColors.info,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Your Role: ${familySpace.roleForUid(currentUid).label}',
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
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
                              Icons.archive_outlined,
                              color: isOwner
                                  ? AppColors.danger
                                  : AppColors.textMuted,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Archive Household',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            if (!isOwner)
                              Flexible(
                                  child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(6),
                                  border:
                                      Border.all(color: Colors.grey.shade300),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.lock,
                                        size: 10, color: Colors.grey),
                                    SizedBox(width: 4),
                                    Flexible(
                                        child: Text(
                                      'Owner Only',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    )),
                                  ],
                                ),
                              )),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isOwner
                              ? 'Archive this household to stop shared access. Its data is retained; the owner can restore it while retaining membership.'
                              : 'Only the household owner can archive this household.',
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
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon:
                                  const Icon(Icons.archive_outlined, size: 18),
                              label: const Text(
                                'Archive Household Space',
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
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
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

    final currentUid = _repo.currentUid;
    final isOwner = _repo.value?.isOwner(currentUid) == true;
    final canEditThisMember = canManageMembers &&
        member.id != currentUid &&
        member.role != FamilyRole.owner &&
        (isOwner || member.role != FamilyRole.admin);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: AppColors.primaryLight,
        child: Text(
          member.name.isEmpty ? '?' : member.name.characters.first,
          style: const TextStyle(
              color: AppColors.primary, fontWeight: FontWeight.w800),
        ),
      ),
      title: MemberIdentity(
          name: member.name,
          role: member.role.label,
          roleBackground: roleBg,
          roleColor: roleText),
      subtitle: Text(member.email,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
      trailing: canEditThisMember
          ? PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: AppColors.textMuted),
              onSelected: (val) {
                if (val == 'transfer') {
                  _offerOwnership(member);
                } else if (val == 'role') {
                  _showRoleDialog(member);
                } else if (val == 'remove') {
                  _confirmRemoveMember(member);
                }
              },
              itemBuilder: (ctx) => [
                if (isOwner)
                  const PopupMenuItem(
                      value: 'transfer',
                      child: Text('Offer ownership transfer')),
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
