import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../data/saved_plans_repository.dart';
import '../models/saved_meal_plan.dart';
import '../../grocery/data/grocery_repository.dart';
import '../../grocery/models/grocery_item.dart';

class GeneratedMealPlanPage extends StatefulWidget {
  const GeneratedMealPlanPage({super.key});

  @override
  State<GeneratedMealPlanPage> createState() => _GeneratedMealPlanPageState();
}

class _GeneratedMealPlanPageState extends State<GeneratedMealPlanPage> {
  int _selectedDayIndex = 0;
  final _saveTitleController = TextEditingController(text: 'My Family Meal Plan');

  late List<GeneratedMeal> _dayMeals;

  @override
  void initState() {
    super.initState();
    _dayMeals = [
      const GeneratedMeal(
        id: '1',
        title: 'Avocado Toast with Poached Eggs',
        type: 'Breakfast',
        prepTime: '15m',
        calories: '340 kcal',
        badgeText: 'Kid Friendly',
        imageUrl: 'https://images.unsplash.com/photo-1525351484163-7529414344d8?auto=format&fit=crop&w=800&q=80',
        ingredients: ['Avocado', 'Whole Wheat Bread', 'Organic Eggs', 'Olive oil'],
        macros: {'Protein': '14g', 'Carbs': '24g', 'Fats': '18g'},
      ),
      const GeneratedMeal(
        id: '2',
        title: 'Avocado & Spinach Salad',
        type: 'Lunch',
        prepTime: '10m',
        calories: '320 kcal',
        badgeText: 'Pantry Cleanout',
        imageUrl: 'https://images.unsplash.com/photo-1512621776951-a57141f2eefd?auto=format&fit=crop&w=800&q=80',
        ingredients: ['Spinach', 'Avocado', 'Cherry Tomatoes', 'Cucumber'],
        macros: {'Protein': '12g', 'Carbs': '14g', 'Fats': '22g'},
      ),
      const GeneratedMeal(
        id: '3',
        title: 'Honey Garlic Pan Seared Salmon',
        type: 'Dinner',
        prepTime: '25m',
        calories: '450 kcal',
        badgeText: 'Dinner Special',
        imageUrl: 'https://images.unsplash.com/photo-1467003909585-2f8a72700288?auto=format&fit=crop&w=800&q=80',
        ingredients: ['Fresh Salmon Fillet', 'Asparagus spears', 'Lemon slices', 'Honey', 'Garlic'],
        macros: {'Protein': '42g', 'Carbs': '8g', 'Fats': '18g'},
      ),
    ];
  }

  @override
  void dispose() {
    _saveTitleController.dispose();
    super.dispose();
  }

  void _showSavePlanDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Save Meal Plan', style: TextStyle(fontWeight: FontWeight.w800)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Give your generated meal plan a title to reload it anytime from Saved Plans.'),
              const SizedBox(height: 16),
              TextField(
                controller: _saveTitleController,
                decoration: InputDecoration(
                  labelText: 'Plan Name',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () {
                final plan = SavedMealPlan(
                  id: 'sp_${DateTime.now().millisecondsSinceEpoch}',
                  title: _saveTitleController.text.trim().isEmpty
                      ? 'Family Meal Plan'
                      : _saveTitleController.text.trim(),
                  dates: 'Day 1 - Day 5',
                  mealsCount: 15,
                  estCost: '\$98.40',
                  familyMembers: ['Dad', 'Mom', 'Leo', 'Emma'],
                  meals: _dayMeals,
                  createdAt: DateTime.now(),
                );
                SavedPlansRepository.instance.savePlan(plan);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Saved "${plan.title}" to Saved Plans!'),
                    backgroundColor: AppColors.primary,
                    action: SnackBarAction(
                      label: 'View',
                      textColor: Colors.white,
                      onPressed: () => context.push('/saved-meal-plans'),
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Save Plan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );
  }

  void _generateGroceryList() {
    final newItems = <GroceryItem>[
      GroceryItem(id: 'g_gen1', name: 'Fresh Atlantic Salmon', quantity: '500g', section: 'MEAT & SEAFOOD'),
      GroceryItem(id: 'g_gen2', name: 'Asparagus bundle', quantity: '1 unit', section: 'PRODUCE AISLE'),
      GroceryItem(id: 'g_gen3', name: 'Whole Wheat Bread', quantity: '1 loaf', section: 'PANTRY STAPLES'),
      GroceryItem(id: 'g_gen4', name: 'Organic Honey', quantity: '1 jar', section: 'PANTRY STAPLES'),
    ];
    GroceryRepository.instance.addMultipleItems(newItems);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.shopping_cart_checkout, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Exported 4 missing ingredients to Grocery List!'),
          ],
        ),
        backgroundColor: AppColors.primary,
        action: SnackBarAction(
          label: 'View List',
          textColor: Colors.white,
          onPressed: () => context.go('/grocery'),
        ),
      ),
    );
  }

  void _replaceMealWithAi(int index) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (ctx.mounted) {
            Navigator.pop(ctx);
          }
          if (mounted) {
            setState(() {
              _dayMeals[index] = const GeneratedMeal(
                id: 'replaced_1',
                title: 'Mediterranean Lemon Herb Chicken',
                type: 'Dinner',
                prepTime: '20m',
                calories: '490 kcal',
                badgeText: 'AI Replacement',
                imageUrl: 'https://images.unsplash.com/photo-1532550907401-a500c9a57435?auto=format&fit=crop&w=800&q=80',
                ingredients: ['Chicken Breast', 'Fresh Rosemary', 'Lemon', 'Olive oil'],
                macros: {'Protein': '46g', 'Carbs': '6g', 'Fats': '16g'},
              );
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Meal replaced with AI recommendation!'),
                backgroundColor: AppColors.primary,
              ),
            );
          }
        });

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: const Row(
            children: [
              CircularProgressIndicator(color: AppColors.primary),
              SizedBox(width: 20),
              Expanded(
                child: Text(
                  'Consulting AI Engine for alternative recipe...',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          tooltip: 'Back',
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Generated AI Meal Plan',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_border, color: AppColors.primary),
            tooltip: 'Save Plan',
            onPressed: _showSavePlanDialog,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Day selector tabs
          Row(
            children: List.generate(5, (index) {
              final dayNum = index + 1;
              final isSelected = _selectedDayIndex == index;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: InkWell(
                    onTap: () => setState(() => _selectedDayIndex = index),
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
                        'Day $dayNum',
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
            }),
          ),
          const SizedBox(height: 20),

          // Day Schedule Summary
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Day ${_selectedDayIndex + 1} Schedule',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '1,110 Total kcal',
                  style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Meals List for Day
          for (var i = 0; i < _dayMeals.length; i++) ...[
            _buildGeneratedMealCard(context, _dayMeals[i], i),
            const SizedBox(height: 14),
          ],

          const SizedBox(height: 12),

          // Bottom Action Bar Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _generateGroceryList,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.shopping_cart_outlined, size: 18),
                  label: const Text('Export Grocery List', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _showSavePlanDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.bookmark_add, size: 18),
                  label: const Text('Save Plan', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGeneratedMealCard(BuildContext context, GeneratedMeal meal, int index) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.all(12),
            leading: Container(
              width: 56,
              height: 56,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Image.network(
                meal.imageUrl,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    color: AppColors.border.withValues(alpha: 0.3),
                    child: const Center(
                      child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: AppColors.primaryLight,
                    child: const Icon(Icons.restaurant, color: AppColors.primary, size: 24),
                  );
                },
              ),
            ),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  meal.type.toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  meal.calories,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  meal.title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${meal.prepTime} prep • ${meal.badgeText}',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                ),
              ],
            ),
            onTap: () => context.push('/meal/${meal.id}'),
          ),
          const Divider(height: 1, indent: 12, endIndent: 12, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: () => _replaceMealWithAi(index),
                  icon: const Icon(Icons.refresh, size: 14, color: AppColors.primary),
                  label: const Text(
                    'Replace with AI',
                    style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Accepted ${meal.title} for Day ${_selectedDayIndex + 1}')),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryLight,
                    foregroundColor: AppColors.primary,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.check, size: 14),
                  label: const Text('Accept Meal', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
