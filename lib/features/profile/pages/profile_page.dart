import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../data/family_member_repository.dart';
import '../models/family_member.dart';
import '../widgets/add_edit_family_member_sheet.dart';
import '../widgets/edit_profile_sheet.dart';
import '../../family/data/family_repository.dart';
import '../../ai_settings/data/ai_provider_repository.dart';
import '../../ai_settings/models/ai_provider.dart';
import '../../auth/data/auth_repository.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  void _openEditProfileSheet(BuildContext context, String currentName, String currentEmail) async {
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => EditProfileSheet(
        initialName: currentName,
        initialEmail: currentEmail,
      ),
    );

    if (updated == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully!'),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }

  void _openAddMemberSheet(BuildContext context) async {
    final result = await showModalBottomSheet<FamilyMember>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const AddEditFamilyMemberSheet(),
    );
    if (result != null && context.mounted) {
      FamilyMemberRepository.instance.addMember(result);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added ${result.name} to family profiles!')),
      );
    }
  }

  void _openEditMemberSheet(BuildContext context, FamilyMember member) async {
    final result = await showModalBottomSheet<FamilyMember>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => AddEditFamilyMemberSheet(existingMember: member),
    );
    if (result != null && context.mounted) {
      FamilyMemberRepository.instance.updateMember(result);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Updated ${result.name}\'s profile.')),
      );
    }
  }

  void _confirmDeleteMember(BuildContext context, FamilyMember member) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete ${member.name}?'),
        content: Text('Are you sure you want to remove ${member.name} from family profiles?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              FamilyMemberRepository.instance.deleteMember(member.id);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Removed ${member.name} from family profiles.')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<FamilyMember>>(
      valueListenable: FamilyMemberRepository.instance,
      builder: (context, members, _) {
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // User Header Profile Card (FR-01: Edit Profile)
            ValueListenableBuilder(
              valueListenable: AuthRepository.instance,
              builder: (context, user, _) {
                final userName = user?.name ?? 'David Miller';
                final userEmail = user?.email ?? 'david.miller@example.com';

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.cardSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const CircleAvatar(
                            radius: 28,
                            backgroundColor: AppColors.primaryLight,
                            child: Icon(Icons.person, size: 32, color: AppColors.primary),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  userName,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 18,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  userEmail,
                                  style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, color: AppColors.primary),
                            tooltip: 'Edit Profile',
                            onPressed: () => _openEditProfileSheet(context, userName, userEmail),
                          ),
                          const SizedBox(width: 4),
                          OutlinedButton(
                            onPressed: () {
                              AuthRepository.instance.logout();
                              context.go('/login');
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.danger,
                              side: const BorderSide(color: AppColors.danger),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            ),
                            child: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 20),

            // Navigation Cards: Family Sharing & AI Provider Settings
            Row(
              children: [
                Expanded(
                  child: ValueListenableBuilder(
                    valueListenable: FamilyRepository.instance,
                    builder: (context, space, _) {
                      return _buildSettingsMenuCard(
                        context,
                        title: 'Family Sharing',
                        subtitle: space == null ? 'Not sharing space' : space.name,
                        icon: Icons.groups,
                        badgeText: space != null ? 'Active' : 'Create/Join',
                        color: AppColors.primaryLight,
                        iconColor: AppColors.primary,
                        onTap: () => context.push('/family-space'),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ValueListenableBuilder(
                    valueListenable: AiProviderRepository.instance,
                    builder: (context, aiConfig, _) {
                      return _buildSettingsMenuCard(
                        context,
                        title: 'AI Settings',
                        subtitle: aiConfig.providerType.displayName,
                        icon: Icons.auto_awesome,
                        badgeText: aiConfig.status == ApiConnectionStatus.connected ? 'Connected' : 'Configure',
                        color: AppColors.infoLight,
                        iconColor: AppColors.info,
                        onTap: () => context.push('/ai-settings'),
                      );
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Family Members Title Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Family Profiles & Dietary Preferences',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _openAddMemberSheet(context),
                  icon: const Icon(Icons.add, size: 16, color: AppColors.primary),
                  label: const Text('Add', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              "Keep track of your family's dynamic food preferences and severe allergy restrictions so our AI can plan safe meals.",
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),

            for (final member in members) ...[
              _FamilyMemberCard(
                member: member,
                onEdit: () => _openEditMemberSheet(context, member),
                onDelete: () => _confirmDeleteMember(context, member),
              ),
              const SizedBox(height: 12),
            ],

            _AddFamilyMemberCard(onTap: () => _openAddMemberSheet(context)),
          ],
        );
      },
    );
  }

  Widget _buildSettingsMenuCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required String badgeText,
    required Color color,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
                  child: Text(
                    badgeText,
                    style: TextStyle(color: iconColor, fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _FamilyMemberCard extends StatelessWidget {
  const _FamilyMemberCard({
    required this.member,
    required this.onEdit,
    required this.onDelete,
  });

  final FamilyMember member;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primaryLight,
            child: Text(
              member.name[0],
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      member.displayName,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          '${member.age} yrs',
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, size: 18, color: AppColors.textMuted),
                          tooltip: 'Member actions',
                          onSelected: (val) {
                            if (val == 'edit') onEdit();
                            if (val == 'delete') onDelete();
                          },
                          itemBuilder: (ctx) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit_outlined, size: 16, color: AppColors.primary),
                                  SizedBox(width: 8),
                                  Text('Edit Profile'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_outline, size: 16, color: AppColors.danger),
                                  SizedBox(width: 8),
                                  Text('Remove', style: TextStyle(color: AppColors.danger)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final pref in member.preferences)
                      _Pill(label: pref, background: AppColors.primaryLight, foreground: AppColors.primary),
                    for (final r in member.restrictions)
                      _Pill(label: r, background: AppColors.dangerLight, foreground: AppColors.danger),
                  ],
                ),
              ],
            ),
          ),
        ],
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
      child: Text(
        label,
        style: TextStyle(color: foreground, fontSize: 12, fontWeight: FontWeight.w600),
      ),
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
      borderRadius: BorderRadius.circular(14),
      child: CustomPaint(
        painter: _DashedBorderPainter(color: AppColors.primary, radius: 14),
        child: const SizedBox(
          height: 52,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add, color: AppColors.primary, size: 20),
                SizedBox(width: 8),
                Text(
                  'Add Family Member',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
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
      ..strokeWidth = 2
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