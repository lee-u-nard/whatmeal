import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../family/data/family_repository.dart';
import '../../family/models/family_space.dart';
import '../../pantry/data/pantry_repository.dart';
import '../../grocery/data/grocery_repository.dart';
import '../../grocery/models/grocery_item.dart';
import '../../meal_plan/data/saved_plans_repository.dart';
import '../../meal_plan/models/saved_meal_plan.dart';
import '../../auth/data/auth_repository.dart';

import '../../profile/data/family_member_repository.dart';
import '../../profile/models/family_member.dart';

/// Combined overview for an active family household:
/// members, meal plans, pantry, and grocery status.
class HouseholdDashboardPage extends StatelessWidget {
  const HouseholdDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Household Dashboard',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
      ),
      body: ValueListenableBuilder<FamilySpace?>(
        valueListenable: FamilyRepository.instance,
        builder: (context, space, _) {
          if (space == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.groups_outlined,
                        size: 64, color: AppColors.textMuted),
                    const SizedBox(height: 16),
                    const Text(
                      'No Family Space Yet',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Create or join a family space to see a shared household overview.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          height: 1.4),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => context.push('/family-space'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Open Family Space',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
            );
          }

          final uid = AuthRepository.instance.currentUser?.uid;
          final role = space.roleForUid(uid);

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      space.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${space.members.length} members · Your role: ${role.label}',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () => context.push('/family-space'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.15),
                          ),
                          child: const Text('Manage Family',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Household Account Members
              _sectionTitle('Household Account Members'),
              const SizedBox(height: 4),
              const Text(
                'Signed-in WhatMeal users collaborating in this shared household.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 8),
              ...space.members.map((m) => _memberTile(m)),
              const SizedBox(height: 20),

              // Family Profiles (People Being Planned For)
              ValueListenableBuilder<List<FamilyMember>>(
                valueListenable: FamilyMemberRepository.instance,
                builder: (context, members, _) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _sectionTitle('Family Members (Planned For)'),
                          TextButton(
                            onPressed: () => context.go('/profile'),
                            child: const Text('Manage Profiles',
                                style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'People in your household being planned for (children, parents, etc.) with allergies & diets.',
                        style:
                            TextStyle(color: AppColors.textMuted, fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      if (members.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.cardSurface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Text(
                            'No family member profiles added yet. Add profiles in Profile to customize meal plans for everyone.',
                            style: TextStyle(
                                color: AppColors.textMuted, fontSize: 12),
                          ),
                        )
                      else
                        ...members.map((fm) => _familyProfileTile(fm)),
                      const SizedBox(height: 20),
                    ],
                  );
                },
              ),

              // Meal plans
              ValueListenableBuilder<List<SavedMealPlan>>(
                valueListenable: SavedPlansRepository.instance,
                builder: (context, plans, _) {
                  final meals = plans.expand((p) => p.activeMeals).toList();
                  final pending = meals.where((m) => m.isPending).length;
                  final accepted = meals.where((m) => m.isAccepted).length;
                  final completed = meals.where((m) => m.isCompleted).length;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle('Shared Meal Plans'),
                      const SizedBox(height: 8),
                      _statRow([
                        ('Plans', plans.length, AppColors.primary),
                        ('Pending', pending, AppColors.warning),
                        ('Accepted', accepted, AppColors.info),
                        ('Done', completed, AppColors.primary),
                      ]),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () => context.push('/saved-meal-plans'),
                          child: const Text('View Saved Plans',
                              style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),

              // Pantry
              ValueListenableBuilder(
                valueListenable: PantryRepository.instance,
                builder: (context, pantry, _) {
                  final items = pantry.values.expand((e) => e).toList();
                  final expiring = items.where((i) => i.isExpiringSoon).length;
                  final low =
                      items.where((i) => i.status.name == 'runningLow').length;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle(PantryRepository.instance.isShared
                          ? 'Shared Pantry'
                          : 'Pantry'),
                      const SizedBox(height: 8),
                      _statRow([
                        ('Items', items.length, AppColors.primary),
                        ('Expiring', expiring, AppColors.danger),
                        ('Low', low, AppColors.warning),
                      ]),
                      TextButton(
                        onPressed: () => context.go('/pantry'),
                        child: const Text('Open Pantry',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),

              // Grocery
              ValueListenableBuilder(
                valueListenable: GroceryRepository.instance,
                builder: (context, grocery, _) {
                  final items = grocery.values.expand((e) => e).toList();
                  final needed = items
                      .where((i) => i.status == GroceryStatus.needed)
                      .length;
                  final purchased =
                      items.where((i) => i.status == GroceryStatus.used).length;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionTitle(GroceryRepository.instance.isShared
                          ? 'Shared Grocery'
                          : 'Grocery'),
                      const SizedBox(height: 8),
                      _statRow([
                        ('Items', items.length, AppColors.primary),
                        ('Needed', needed, AppColors.danger),
                        ('Purchased', purchased, AppColors.info),
                      ]),
                      TextButton(
                        onPressed: () => context.go('/grocery'),
                        child: const Text('Open Grocery',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _sectionTitle(String title) => Text(
        title,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w800,
          fontSize: 16,
        ),
      );

  Widget _memberTile(SharedSpaceMember m) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.primaryLight,
            child: Text(
              m.name.isNotEmpty ? m.name[0].toUpperCase() : '?',
              style: const TextStyle(
                  color: AppColors.primary, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              m.name,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            m.role.label,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statRow(List<(String, int, Color)> stats) {
    return Row(
      children: [
        for (var i = 0; i < stats.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: stats[i].$3.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Text(
                    '${stats[i].$2}',
                    style: TextStyle(
                      color: stats[i].$3,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    stats[i].$1,
                    style: TextStyle(
                      color: stats[i].$3,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _familyProfileTile(FamilyMember fm) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: AppColors.primaryLight,
            child: Text(
              fm.name.isNotEmpty ? fm.name[0].toUpperCase() : '?',
              style: const TextStyle(
                  color: AppColors.primary, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      fm.displayName,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${fm.age} yrs',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (fm.preferences.isNotEmpty ||
                    fm.restrictions.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      for (final p in fm.preferences)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            p,
                            style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 10,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      for (final r in fm.restrictions)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.dangerLight,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            r,
                            style: const TextStyle(
                                color: AppColors.danger,
                                fontSize: 10,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
