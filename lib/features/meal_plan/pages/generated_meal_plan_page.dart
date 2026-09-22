import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/llm_service.dart';
import '../../auth/data/auth_repository.dart';
import '../data/saved_plans_repository.dart';
import '../models/saved_meal_plan.dart';
import '../../grocery/data/grocery_repository.dart';
import '../../grocery/models/grocery_item.dart';

class GeneratedMealPlanPage extends StatefulWidget {
  const GeneratedMealPlanPage({super.key, this.draft});

  final GeneratedPlanDraft? draft;

  @override
  State<GeneratedMealPlanPage> createState() => _GeneratedMealPlanPageState();
}

class _GeneratedMealPlanPageState extends State<GeneratedMealPlanPage> {
  int _selectedDayIndex = 0;
  late final TextEditingController _saveTitleController;
  late List<GeneratedMeal> _allMeals;
  late int _numberOfDays;
  late List<String> _familyMembers;

  List<GeneratedMeal> get _dayMeals =>
      _allMeals.where((m) => m.dayIndex == _selectedDayIndex).toList();

  @override
  void initState() {
    super.initState();
    final draft = widget.draft;
    _allMeals = List<GeneratedMeal>.from(draft?.meals ?? const []);
    _numberOfDays = draft?.numberOfDays ?? 5;
    if (_numberOfDays < 1) _numberOfDays = 1;
    _familyMembers = List<String>.from(draft?.familyMembers ?? const []);
    _saveTitleController = TextEditingController(
      text: draft?.title ?? 'My Family Meal Plan',
    );
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
              onPressed: () async {
                final plan = SavedMealPlan(
                  id: 'sp_${DateTime.now().millisecondsSinceEpoch}',
                  title: _saveTitleController.text.trim().isEmpty
                      ? 'Family Meal Plan'
                      : _saveTitleController.text.trim(),
                  dates: 'Day 1 - Day $_numberOfDays',
                  mealsCount: _allMeals.length,
                  estCost: '\$0.00',
                  familyMembers: _familyMembers,
                  meals: _allMeals,
                  createdAt: DateTime.now(),
                );
                try {
                  await SavedPlansRepository.instance.savePlan(plan);
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  if (!mounted) return;
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
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Could not save meal plan: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Save Plan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _generateGroceryList() async {
    final newItems = <GroceryItem>[];
    for (final meal in _allMeals) {
      for (final ingredient in meal.ingredients) {
        if (ingredient.isEmpty) continue;
        newItems.add(
          GroceryItem(
            name: ingredient,
            quantity: '1',
            section: 'PANTRY STAPLES',
          ),
        );
      }
    }
    if (newItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No ingredients to export.')),
      );
      return;
    }
    try {
      await GroceryRepository.instance.addMultipleItems(newItems);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Exported ${newItems.length} ingredients to Grocery List!'),
          backgroundColor: AppColors.primary,
          action: SnackBarAction(
            label: 'View List',
            textColor: Colors.white,
            onPressed: () => context.go('/grocery'),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not export grocery list: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _replaceMealWithAi(int index) async {
    final visible = _dayMeals;
    if (index < 0 || index >= visible.length) return;
    final current = visible[index];
    final uid = AuthRepository.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to replace a meal.')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: const Row(
            children: [
              CircularProgressIndicator(color: AppColors.primary),
              SizedBox(width: 20),
              Expanded(
                child: Text(
                  'Asking Gemini for an alternative recipe...',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            ],
          ),
        );
      },
    );

    try {
      final result = await context.read<LlmService>().replaceMeal(
            uid: uid,
            currentMeal: current.toCore(),
          );
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      final replacement = GeneratedMeal.fromCore(result.data, fallbackIndex: index);
      setState(() {
        final allIndex = _allMeals.indexWhere((m) => m.id == current.id);
        if (allIndex >= 0) {
          _allMeals[allIndex] = GeneratedMeal(
            id: replacement.id,
            title: replacement.title,
            type: current.type,
            prepTime: replacement.prepTime,
            calories: replacement.calories,
            badgeText: replacement.badgeText.isEmpty ? 'AI Replacement' : replacement.badgeText,
            imageUrl: replacement.imageUrl,
            ingredients: replacement.ingredients,
            macros: replacement.macros,
            dayIndex: current.dayIndex,
          );
        }
      });
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not replace meal: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
            children: List.generate(_numberOfDays, (index) {
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
                child: Text(
                  '${_dayMeals.length} meals',
                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 12),
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
          if (_dayMeals.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'No meals for this day. Generate a plan from the Meal Plan tab.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ),

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
              child: meal.imageUrl.isEmpty
                  ? const Icon(Icons.restaurant, color: AppColors.primary, size: 24)
                  : Image.network(
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
