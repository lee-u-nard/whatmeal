import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../../features/pantry/data/pantry_repository.dart';
import '../../features/pantry/widgets/add_pantry_item_sheet.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _titles = ['WhatMeal', 'Meal Plan', 'Pantry Inventory', 'Grocery List', 'Family Profiles'];

  static Widget? _fabForTab(int index, BuildContext context) {
    if (index != 2) return null;
    return FloatingActionButton(
      backgroundColor: AppColors.primary,
      shape: const CircleBorder(),
      elevation: 4,
      onPressed: () async {
        final result = await showModalBottomSheet<NewPantryItem>(
          context: context,
          isScrollControlled: true,
          builder: (_) => const AddPantryItemSheet(),
        );
        if (result != null) {
          PantryRepository.instance.addItem(result.category, result.item);
        }
      },
      child: const Icon(Icons.add, color: Colors.white),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = navigationShell.currentIndex;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.eco, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 8),
            Text(
              _titles[currentIndex],
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: AppColors.textPrimary),
            onPressed: () {},
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: () => navigationShell.goBranch(4),
              child: const CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.primaryLight,
                child: Icon(Icons.person, size: 20, color: AppColors.primary),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _fabForTab(currentIndex, context),
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.cardSurface,
          border: Border(top: BorderSide(color: AppColors.border, width: 1)),
        ),
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(context, index: 0, icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Home'),
            _buildNavItem(context, index: 1, icon: Icons.calendar_today_outlined, activeIcon: Icons.calendar_today, label: 'Meal Plan'),
            _buildNavItem(context, index: 2, icon: Icons.inventory_2_outlined, activeIcon: Icons.inventory_2, label: 'Pantry'),
            _buildNavItem(context, index: 3, icon: Icons.shopping_cart_outlined, activeIcon: Icons.shopping_cart, label: 'Grocery'),
            _buildNavItem(context, index: 4, icon: Icons.person_outline, activeIcon: Icons.person, label: 'Profile'),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
  }) {
    final isSelected = navigationShell.currentIndex == index;

    return InkWell(
      onTap: () => navigationShell.goBranch(
        index,
        initialLocation: index == navigationShell.currentIndex,
      ),
      borderRadius: BorderRadius.circular(100),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primaryLight : Colors.transparent,
              borderRadius: BorderRadius.circular(100),
            ),
            child: Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
              size: 20,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
