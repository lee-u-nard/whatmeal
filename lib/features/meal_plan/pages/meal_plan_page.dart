import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/llm_service.dart';
import '../../profile/data/family_member_repository.dart';
import '../../pantry/data/pantry_repository.dart';
import '../../grocery/data/grocery_repository.dart';
import '../../grocery/models/grocery_item.dart';
import '../data/meal_plan_repository.dart';
import '../models/meal_plan.dart';
import '../../meal/models/meal.dart';

class MealPlanPage extends StatefulWidget {
  const MealPlanPage({super.key});

  @override
  State<MealPlanPage> createState() => _MealPlanPageState();
}

class _MealPlanPageState extends State<MealPlanPage> {
  final Set<String> _selectedFamily = {};
  int _selectedDays = 5;

  final _mealTypes = ['Breakfast', 'Lunch', 'Dinner'];
  final _selectedMealTypes = <String>{'Breakfast', 'Lunch', 'Dinner'};

  bool _prioritizePantry = true;

  final _cuisines = ['Italian', 'Asian', 'Mexican', 'Mediterranean', 'American', 'Indian'];
  final _selectedCuisines = <String>{'Italian', 'Asian', 'Mexican'};

  bool _isGenerating = false;

  Future<void> _generateMealPlan() async {
    final authService = context.read<AuthService>();
    final llmService = context.read<LlmService>();
    final mealPlanRepo = context.read<MealPlanRepository>();
    final groceryRepo = context.read<GroceryRepository>();
    final pantryRepo = context.read<PantryRepository>();
    final memberRepo = context.read<FamilyMemberRepository>();

    final uid = authService.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to generate meal plans.')),
      );
      return;
    }

    setState(() => _isGenerating = true);

    try {
      final selectedMembers = memberRepo.members
          .where((m) => _selectedFamily.contains(m.name))
          .toList();

      final memberNames = selectedMembers.isNotEmpty
          ? selectedMembers.map((m) => m.name).toList()
          : (_selectedFamily.isNotEmpty ? _selectedFamily.toList() : ['Family']);

      final allRestrictions = selectedMembers
          .expand((m) => m.restrictions)
          .toSet()
          .toList();

      final pantryItemsList = _prioritizePantry
          ? pantryRepo.items.values.expand((items) => items).map((i) => i.name).toList()
          : <String>[];

      List<Meal> generatedMeals;

      try {
        final result = await llmService.generateMealPlan(
          uid: uid,
          familyMemberNames: memberNames,
          numberOfDays: _selectedDays,
          mealTypes: _selectedMealTypes.toList(),
          cuisinePreferences: _selectedCuisines.toList(),
          prioritizePantry: _prioritizePantry,
          pantryItems: pantryItemsList,
          restrictions: allRestrictions,
        );
        generatedMeals = result.data;
        if (result.usedFallback && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Using free built-in AI (your custom key had an issue).'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      } catch (e) {
        // Fallback: If no API key configured or network error, provide curated smart meal suggestions
        debugPrint('LLM Generation notice: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Notice: Using smart chef templates. (Live AI generation failed)',
              ),
              action: SnackBarAction(
                label: 'Settings',
                onPressed: () => context.push('/settings'),
              ),
              duration: const Duration(seconds: 5),
            ),
          );
        }
        generatedMeals = _generateCuratedMeals(
          days: _selectedDays,
          mealTypes: _selectedMealTypes.toList(),
          cuisines: _selectedCuisines.toList(),
          prioritizePantry: _prioritizePantry,
          pantryItems: pantryItemsList,
        );
      }

      // Save plan and meals to Firestore
      final plan = MealPlan(
        id: '',
        title: '${_cuisines.firstWhere((c) => _selectedCuisines.contains(c), orElse: () => "Family")} $_selectedDays-Day Feast',
        startDate: DateTime.now(),
        endDate: DateTime.now().add(Duration(days: _selectedDays)),
        numberOfDays: _selectedDays,
        mealTypes: _selectedMealTypes.toList(),
        cuisinePreferences: _selectedCuisines.toList(),
        prioritizePantry: _prioritizePantry,
        selectedMemberIds: selectedMembers.map((m) => m.id ?? m.name).toList(),
        estimatedCost: '\$${(_selectedDays * 18.5).toStringAsFixed(2)}',
        createdBy: uid,
      );

      await mealPlanRepo.savePlan(plan, generatedMeals);

      // Auto-populate groceries
      final groceryItems = generatedMeals
          .expand((m) => m.ingredients)
          .map((ing) => GroceryItem(
                name: ing.name,
                quantity: ing.amount,
                category: 'Other',
                tag: 'From Meal Plan',
              ))
          .toList();
      await groceryRepo.addItemsFromMealPlan(groceryItems);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Meal plan created and groceries added!')),
        );
        context.push('/saved-meal-plans');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save meal plan: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  List<Meal> _generateCuratedMeals({
    required int days,
    required List<String> mealTypes,
    required List<String> cuisines,
    required bool prioritizePantry,
    required List<String> pantryItems,
  }) {
    final meals = <Meal>[];
    final sampleMeals = [
      Meal(
        id: 'sample_1',
        title: 'Honey Garlic Pan Seared Salmon',
        subtitle: 'Mediterranean • 25m prep & cook',
        cuisine: 'Mediterranean',
        mealType: 'Dinner',
        calories: '450 kcal',
        prepTime: '10 min',
        cookTime: '15 min',
        servings: '4 servings',
        protein: '38g',
        carbs: '12g',
        fats: '18g',
        badgeText: 'Chef Favorite',
        ingredients: const [
          Ingredient(name: 'Salmon Fillets', amount: '4 pieces'),
          Ingredient(name: 'Garlic Cloves', amount: '4 minced'),
          Ingredient(name: 'Honey', amount: '3 tbsp'),
          Ingredient(name: 'Soy Sauce', amount: '2 tbsp'),
          Ingredient(name: 'Olive Oil', amount: '1 tbsp'),
        ],
      ),
      Meal(
        id: 'sample_2',
        title: 'Avocado & Spinach Power Bowl',
        subtitle: 'Vegetarian • 10m prep',
        cuisine: 'American',
        mealType: 'Lunch',
        calories: '320 kcal',
        prepTime: '10 min',
        cookTime: '0 min',
        servings: '2 servings',
        protein: '14g',
        carbs: '22g',
        fats: '16g',
        badgeText: 'Quick & Healthy',
        ingredients: const [
          Ingredient(name: 'Fresh Spinach', amount: '2 cups'),
          Ingredient(name: 'Ripe Avocado', amount: '1 sliced'),
          Ingredient(name: 'Cherry Tomatoes', amount: '1/2 cup'),
          Ingredient(name: 'Lemon Juice', amount: '1 tbsp'),
          Ingredient(name: 'Feta Cheese', amount: '50g'),
        ],
      ),
      Meal(
        id: 'sample_3',
        title: 'Golden Berry Oatmeal Bowl',
        subtitle: 'Energizing • 8m prep',
        cuisine: 'American',
        mealType: 'Breakfast',
        calories: '280 kcal',
        prepTime: '3 min',
        cookTime: '5 min',
        servings: '1 serving',
        protein: '10g',
        carbs: '45g',
        fats: '5g',
        badgeText: 'High Fiber',
        ingredients: const [
          Ingredient(name: 'Rolled Oats', amount: '1 cup'),
          Ingredient(name: 'Almond Milk', amount: '1 cup'),
          Ingredient(name: 'Blueberries', amount: '1/2 cup'),
          Ingredient(name: 'Honey', amount: '1 tbsp'),
        ],
      ),
      Meal(
        id: 'sample_4',
        title: 'Tuscan Herb Chicken Breast',
        subtitle: 'Italian • 30m prep & cook',
        cuisine: 'Italian',
        mealType: 'Dinner',
        calories: '410 kcal',
        prepTime: '10 min',
        cookTime: '20 min',
        servings: '4 servings',
        protein: '42g',
        carbs: '8g',
        fats: '14g',
        badgeText: 'High Protein',
        ingredients: const [
          Ingredient(name: 'Chicken Breast', amount: '500g'),
          Ingredient(name: 'Rosemary & Thyme', amount: '2 sprigs'),
          Ingredient(name: 'Olive Oil', amount: '2 tbsp'),
          Ingredient(name: 'Lemon', amount: '1 sliced'),
        ],
      ),
    ];

    var index = 0;
    for (var d = 0; d < days; d++) {
      for (final type in mealTypes) {
        final base = sampleMeals[index % sampleMeals.length];
        meals.add(
          Meal(
            id: 'm_${d}_$type',
            title: base.title,
            subtitle: '${base.cuisine ?? "Family"} • $type',
            cuisine: base.cuisine,
            mealType: type,
            dayIndex: d,
            prepTime: base.prepTime,
            cookTime: base.cookTime,
            servings: base.servings,
            calories: base.calories,
            protein: base.protein,
            carbs: base.carbs,
            fats: base.fats,
            badgeText: base.badgeText,
            ingredients: base.ingredients,
          ),
        );
        index++;
      }
    }
    return meals;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FamilyMemberRepository>(
      builder: (context, memberRepo, _) {
        final members = memberRepo.members;
        final familyNames = members.isNotEmpty
            ? members.map((m) => m.name).toList()
            : ['Dad', 'Mom', 'Kids'];

        // Auto-select all on first load if empty
        if (_selectedFamily.isEmpty) {
          _selectedFamily.addAll(familyNames);
        }

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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Plan Meals For',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                if (members.isEmpty)
                  TextButton(
                    onPressed: () => context.push('/profile'),
                    child: const Text('Add Profiles', style: TextStyle(fontSize: 12)),
                  ),
              ],
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
                children: familyNames.map((name) {
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
            Container(
              decoration: BoxDecoration(
                color: AppColors.cardSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [3, 5, 7].map((days) {
                  final isSelected = _selectedDays == days;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedDays = days),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Center(
                          child: Text(
                            '$days Days',
                            style: TextStyle(
                              color: isSelected ? Colors.white : AppColors.textSecondary,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 20),

            // Section: Meal Types
            const Text(
              'Meal Types',
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
                    child: FilterChip(
                      label: Center(child: Text(type)),
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
                            _selectedMealTypes.add(type);
                          } else {
                            if (_selectedMealTypes.length > 1) {
                              _selectedMealTypes.remove(type);
                            }
                          }
                        });
                      },
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 20),

            // Section: Prioritize Expiring Pantry
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                        'Prioritize Expiring Pantry',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Reduce food waste by using near-expiry items',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 11),
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
                onPressed: _isGenerating ? null : _generateMealPlan,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shadowColor: const Color.fromRGBO(27, 42, 30, 0.2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: _isGenerating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome, size: 20),
                label: Text(
                  _isGenerating ? 'Cooking up your plan...' : 'Generate AI Meal Plan',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
