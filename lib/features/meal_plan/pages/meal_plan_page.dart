import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';

class MealPlanPage extends StatefulWidget {
  const MealPlanPage({super.key});

  @override
  State<MealPlanPage> createState() => _MealPlanPageState();
}

class _MealPlanPageState extends State<MealPlanPage> {
  final _familyMembers = ['Dad', 'Mom', 'Leo', 'Emma'];
  final _selectedFamily = <String>{'Dad', 'Mom', 'Leo', 'Emma'};

  int _selectedDays = 5;

  final _mealTypes = ['Breakfast', 'Lunch', 'Dinner'];
  final _selectedMealTypes = <String>{'Breakfast', 'Lunch', 'Dinner'};

  bool _prioritizePantry = true;

  final _cuisines = ['Italian', 'Asian', 'Mexican', 'Mediterranean', 'American', 'Indian'];
  final _selectedCuisines = <String>{'Italian', 'Asian', 'Mexican'};

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Saved Meal Plans Quick Link Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Generate AI Meal Plan',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => context.push('/saved-meal-plans'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
              icon: const Icon(Icons.bookmark_outline, size: 16),
              label: const Text('Saved Plans', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Section: Plan Meals For
        const Text(
          'Plan Meals For',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.cardSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: _familyMembers.map((name) {
              final isChecked = _selectedFamily.contains(name);
              return CheckboxListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                visualDensity: VisualDensity.compact,
                title: Text(
                  name,
                  style: TextStyle(
                    color: isChecked ? AppColors.primary : AppColors.textPrimary,
                    fontWeight: isChecked ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
                activeColor: AppColors.primary,
                checkColor: Colors.white,
                value: isChecked,
                onChanged: (checked) {
                  setState(() {
                    if (checked == true) {
                      _selectedFamily.add(name);
                    } else {
                      _selectedFamily.remove(name);
                    }
                  });
                },
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 20),

        // Section: Number of Days
        const Text(
          'Number of Days',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [1, 3, 5, 7].map((days) {
            final isSelected = _selectedDays == days;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: InkWell(
                  onTap: () => setState(() => _selectedDays = days),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : AppColors.cardSurface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : AppColors.border,
                      ),
                    ),
                    child: Text(
                      '$days Days',
                      style: TextStyle(
                        color: isSelected ? Colors.white : AppColors.textSecondary,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 20),

        // Section: Include Meal Types
        const Text(
          'Include Meal Types',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: _mealTypes.map((type) {
            final isSelected = _selectedMealTypes.contains(type);
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedMealTypes.remove(type);
                      } else {
                        _selectedMealTypes.add(type);
                      }
                    });
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primaryLight : AppColors.cardSurface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : AppColors.border,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (isSelected)
                          const Padding(
                            padding: EdgeInsets.only(right: 4),
                            child: Icon(Icons.check, size: 14, color: AppColors.primary),
                          ),
                        Text(
                          type,
                          style: TextStyle(
                            color: isSelected ? AppColors.primary : AppColors.textSecondary,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 20),

        // Section: Prioritize Pantry Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.cardSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Prioritize Pantry',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Use ingredients expiring soon first',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              Switch(
                value: _prioritizePantry,
                activeTrackColor: AppColors.primary,
                onChanged: (val) => setState(() => _prioritizePantry = val),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Section: Cuisine Preferences
        const Text(
          'Cuisine Preferences',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _cuisines.map((cuisine) {
            final isSelected = _selectedCuisines.contains(cuisine);
            return FilterChip(
              label: Text(cuisine),
              selected: isSelected,
              selectedColor: AppColors.primaryLight,
              checkmarkColor: AppColors.primary,
              backgroundColor: AppColors.cardSurface,
              side: BorderSide(
                color: isSelected ? AppColors.primary : AppColors.border,
              ),
              labelStyle: TextStyle(
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 12,
              ),
              onSelected: (val) {
                setState(() {
                  if (val) {
                    _selectedCuisines.add(cuisine);
                  } else {
                    _selectedCuisines.remove(cuisine);
                  }
                });
              },
            );
          }).toList(),
        ),

        const SizedBox(height: 28),

        // Generate AI Meal Plan CTA Button
        SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            onPressed: () => context.push('/meal/1'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 2,
              shadowColor: const Color.fromRGBO(27, 42, 30, 0.2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.auto_awesome, size: 20),
            label: const Text(
              'Generate AI Meal Plan',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
          ),
        ),
      ],
    );
  }
}
