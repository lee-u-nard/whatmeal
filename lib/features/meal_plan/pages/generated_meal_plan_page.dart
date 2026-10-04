import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/llm_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/household_notification_service.dart';
import '../../../core/services/unsplash_service.dart';
import '../../../core/models/app_notification.dart';
import '../../../core/utils/family_permissions.dart';
import '../../../core/utils/ingredient_matcher.dart';
import '../../../core/utils/week_calendar.dart';
import '../../auth/data/auth_repository.dart';
import '../../pantry/data/pantry_repository.dart';
import '../../grocery/data/grocery_repository.dart';
import '../../grocery/models/grocery_item.dart';
import '../data/saved_plans_repository.dart';
import '../models/saved_meal_plan.dart';
import '../models/meal_plan.dart';
import '../../meal/models/meal.dart';
import '../../meal/widgets/meal_status_badge.dart';
import '../../meal/widgets/meal_network_image.dart';

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
  late DateTime _startDate;

  static const _weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  static const _shortDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  /// Calendar always shows a full Mon–Sun week; meals may only fill some days.
  int get _calendarDays => _numberOfDays < 7 ? 7 : _numberOfDays;

  List<GeneratedMeal> get _dayMeals =>
      _allMeals.where((m) => m.dayIndex == _selectedDayIndex).toList();

  String _dayLabel(int index) {
    final date = _startDate.add(Duration(days: index));
    final wd = date.weekday - 1; // 0=Mon … 6=Sun
    return _weekdays[wd % 7];
  }

  String _dayShortLabel(int index) {
    final date = _startDate.add(Duration(days: index));
    final wd = date.weekday - 1;
    return _shortDays[wd % 7];
  }

  @override
  void initState() {
    super.initState();
    final draft = widget.draft;
    _allMeals = List<GeneratedMeal>.from(draft?.meals ?? const []);
    _numberOfDays = draft?.numberOfDays ?? 7;
    if (_numberOfDays < 1) _numberOfDays = 1;
    _familyMembers = List<String>.from(draft?.familyMembers ?? const []);
    _startDate = draft?.startDate ?? WeekCalendar.mondayOf(DateTime.now());
    // Align selected day to today when viewing the current week.
    final todayIdx = WeekCalendar.dayIndexOf(DateTime.now());
    if (WeekCalendar.mondayOf(_startDate) ==
            WeekCalendar.mondayOf(DateTime.now()) &&
        todayIdx < _calendarDays) {
      _selectedDayIndex = todayIdx;
    }
    _saveTitleController = TextEditingController(
      text: draft?.title ?? 'My Family Meal Plan',
    );
  }

  @override
  void dispose() {
    _saveTitleController.dispose();
    super.dispose();
  }

  // ── Save plan dialog ────────────────────────────────────────────────────────

  void _showSavePlanDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Save Meal Plan',
              style: TextStyle(fontWeight: FontWeight.w800)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                  'Give this meal plan a name to load it anytime from Saved Plans.'),
              const SizedBox(height: 16),
              TextField(
                controller: _saveTitleController,
                decoration: InputDecoration(
                  labelText: 'Plan Name',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                final title = _saveTitleController.text.trim().isEmpty
                    ? 'Family Meal Plan'
                    : _saveTitleController.text.trim();
                final endDate =
                    _startDate.add(Duration(days: _numberOfDays - 1));

                final coreMeals = _allMeals.map((m) => m.toCore()).toList();
                final corePlan = MealPlan(
                  id: '',
                  title: title,
                  startDate: _startDate,
                  endDate: endDate,
                  numberOfDays: _numberOfDays,
                  selectedMemberIds: _familyMembers,
                  status: 'saved',
                );

                try {
                  // Capture router/messenger before async gaps so View still works
                  // even if this page is later disposed.
                  final router = GoRouter.of(context);
                  final messenger = ScaffoldMessenger.of(context);
                  final viewedDraft = GeneratedPlanDraft(
                    meals: List<GeneratedMeal>.from(_allMeals),
                    familyMembers: List<String>.from(_familyMembers),
                    numberOfDays: _numberOfDays,
                    startDate: _startDate,
                    title: title,
                  );

                  final savedPlanId = await SavedPlansRepository.instance
                      .savePlan(corePlan, coreMeals);
                  final userName =
                      AuthRepository.instance.value?.name ?? 'A member';
                  NotificationService.instance.notifyHouseholdMembers(
                    title: 'Meal Plan Saved 📋',
                    body: '$userName saved "$title" to the meal plans.',
                    type: AppNotificationType.mealPlanSaved,
                    relatedPlanId: savedPlanId,
                    includeSelf: true,
                  );
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);

                  messenger.hideCurrentSnackBar();
                  messenger.showSnackBar(
                    SnackBar(
                      duration: const Duration(seconds: 6),
                      backgroundColor: AppColors.primary,
                      content: Row(
                        children: [
                          const Icon(Icons.check_circle,
                              color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Saved "$title"!',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      action: SnackBarAction(
                        label: 'View',
                        textColor: Colors.white,
                        onPressed: () {
                          // Prefer the persisted copy once the local cache catches up.
                          SavedMealPlan? saved;
                          for (final p in SavedPlansRepository.instance.value) {
                            if (p.id == savedPlanId) {
                              saved = p;
                              break;
                            }
                          }
                          final draft = saved == null
                              ? viewedDraft
                              : GeneratedPlanDraft(
                                  meals: List<GeneratedMeal>.from(saved.meals),
                                  familyMembers:
                                      List<String>.from(saved.familyMembers),
                                  numberOfDays: saved.meals.isEmpty
                                      ? viewedDraft.numberOfDays
                                      : saved.meals
                                              .map((m) => m.dayIndex)
                                              .reduce((a, b) => a > b ? a : b) +
                                          1,
                                  startDate: viewedDraft.startDate,
                                  title: saved.title,
                                );

                          // Leave the editor, then open the saved plan so View
                          // always produces a visible navigation (not a no-op
                          // push of the same screen the user is already on).
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            router.go('/meal-plan');
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              router.push('/generated-plan', extra: draft);
                            });
                          });
                        },
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
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Save Plan',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ],
        );
      },
    );
  }

  // ── Custom Edit & Add Meal Dialogs ──────────────────────────────────────────

  void _showEditMealDialog(GeneratedMeal meal) {
    final titleCtrl = TextEditingController(text: meal.title);
    final prepTimeCtrl = TextEditingController(text: meal.prepTime);
    final caloriesCtrl = TextEditingController(text: meal.calories);
    final badgeCtrl = TextEditingController(text: meal.badgeText);
    final ingredientsCtrl =
        TextEditingController(text: meal.ingredients.join(', '));
    String selectedType =
        ['Breakfast', 'Lunch', 'Dinner', 'Snack', 'Dessert'].contains(meal.type)
            ? meal.type
            : 'Breakfast';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Edit Meal Details',
              style: TextStyle(fontWeight: FontWeight.w800)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: InputDecoration(
                    labelText: 'Dish Name',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedType,
                  decoration: InputDecoration(
                    labelText: 'Meal Type',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  items: ['Breakfast', 'Lunch', 'Dinner', 'Snack', 'Dessert']
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedType = val);
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: prepTimeCtrl,
                        decoration: InputDecoration(
                          labelText: 'Prep Time',
                          hintText: '20m',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: caloriesCtrl,
                        decoration: InputDecoration(
                          labelText: 'Calories',
                          hintText: '450 kcal',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: badgeCtrl,
                  decoration: InputDecoration(
                    labelText: 'Tag / Style',
                    hintText: 'e.g. Quick & Easy, Home Cooked',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ingredientsCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Ingredients (comma-separated)',
                    hintText: 'Chicken, Soy sauce, Garlic, Onion',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () {
                final updatedTitle = titleCtrl.text.trim();
                if (updatedTitle.isEmpty) return;

                final rawIngredients = ingredientsCtrl.text
                    .split(',')
                    .map((s) => s.trim())
                    .where((s) => s.isNotEmpty)
                    .toList();

                setState(() {
                  final allIdx = _allMeals.indexWhere((m) => m.id == meal.id);
                  if (allIdx >= 0) {
                    _allMeals[allIdx] = _allMeals[allIdx].copyWith(
                      title: updatedTitle,
                      type: selectedType,
                      prepTime: prepTimeCtrl.text.trim(),
                      calories: caloriesCtrl.text.trim(),
                      badgeText: badgeCtrl.text.trim(),
                      ingredients: rawIngredients,
                    );
                  }
                });
                Navigator.pop(ctx);
              },
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Save Changes',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddMealDialog() {
    final titleCtrl = TextEditingController();
    final prepTimeCtrl = TextEditingController(text: '20m');
    final caloriesCtrl = TextEditingController(text: '400 kcal');
    final badgeCtrl = TextEditingController(text: 'Home Cooked');
    final ingredientsCtrl = TextEditingController();
    String selectedType = 'Lunch';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Add Dish to ${_dayLabel(_selectedDayIndex)}',
              style: const TextStyle(fontWeight: FontWeight.w800)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: InputDecoration(
                    labelText: 'Dish Name',
                    hintText: 'e.g., Sinigang na Baboy',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedType,
                  decoration: InputDecoration(
                    labelText: 'Meal Type',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  items: ['Breakfast', 'Lunch', 'Dinner', 'Snack', 'Dessert']
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedType = val);
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: prepTimeCtrl,
                        decoration: InputDecoration(
                          labelText: 'Prep Time',
                          hintText: '20m',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: caloriesCtrl,
                        decoration: InputDecoration(
                          labelText: 'Calories',
                          hintText: '400 kcal',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ingredientsCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Ingredients (comma-separated)',
                    hintText: 'Pork, Tamarind soup mix, Kangkong',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () {
                final title = titleCtrl.text.trim();
                if (title.isEmpty) return;

                final rawIngredients = ingredientsCtrl.text
                    .split(',')
                    .map((s) => s.trim())
                    .where((s) => s.isNotEmpty)
                    .toList();

                final newMeal = GeneratedMeal(
                  id: 'custom_added_${_selectedDayIndex}_${DateTime.now().millisecondsSinceEpoch}',
                  title: title,
                  type: selectedType,
                  dayIndex: _selectedDayIndex,
                  prepTime: prepTimeCtrl.text.trim(),
                  calories: caloriesCtrl.text.trim(),
                  badgeText: badgeCtrl.text.trim(),
                  imageUrl: '',
                  ingredients: rawIngredients,
                  macros: {
                    'Protein': '25g',
                    'Carbs': '40g',
                    'Fats': '15g',
                  },
                  status: MealStatus.accepted,
                );

                setState(() {
                  _allMeals.add(newMeal);
                });
                Navigator.pop(ctx);
              },
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Add Dish',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Smart grocery export ────────────────────────────────────────────────────

  /// Ingredients not found in the pantry (singular/plural-aware) for [meal].
  List<String> _missingAgainstPantry(GeneratedMeal meal) {
    final pantryNames = PantryRepository.instance.availableNames;
    final all = IngredientMatcher.allIngredients(
      ingredients: meal.ingredients,
      availableIngredients: meal.availableIngredients,
      missingIngredients: meal.missingIngredients,
    );
    return IngredientMatcher.partition(all, pantryNames).needToBuy;
  }

  /// On Accept: add every ingredient that is NOT in the pantry to Grocery.
  /// Empty pantry ⇒ every ingredient is added. Skips items already on grocery.
  Future<int> _pushMissingIngredientsToGrocery(GeneratedMeal meal) async {
    final needToBuy = _missingAgainstPantry(meal);
    if (needToBuy.isEmpty) return 0;

    final groceryNames = GroceryRepository.instance.allItemNames;
    final newItems = <GroceryItem>[];
    final seen = <String>{};

    for (final ingredient in needToBuy) {
      final key = IngredientMatcher.normalize(ingredient);
      if (key.isEmpty || !seen.add(key)) continue;
      // Avoid duplicate grocery lines; pantry was already checked above.
      if (IngredientMatcher.isInPantry(ingredient, groceryNames)) continue;
      newItems.add(GroceryItem(
        name: ingredient,
        quantity: '1',
        section: _classifyIngredient(ingredient),
      ));
    }

    if (newItems.isEmpty) return 0;
    return GroceryRepository.instance.addMultipleItems(newItems);
  }

  Future<void> _generateGroceryList() async {
    if (!FamilyPermissions.canGenerateGroceryList) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(FamilyPermissions.denialMessage('generate a grocery list')),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final pantryNames = PantryRepository.instance.availableNames;
    final groceryNames = GroceryRepository.instance.allItemNames;

    final newItems = <GroceryItem>[];
    final seen = <String>{};

    // Only accepted (and completed) meals feed the grocery list.
    final sourceMeals = _allMeals.where(
      (m) => !m.isReplaced && (m.isAccepted || m.isCompleted),
    );
    // If nothing accepted yet, fall back to all non-replaced meals.
    final meals = sourceMeals.isNotEmpty
        ? sourceMeals
        : _allMeals.where((m) => !m.isReplaced);

    for (final meal in meals) {
      final all = IngredientMatcher.allIngredients(
        ingredients: meal.ingredients,
        availableIngredients: meal.availableIngredients,
        missingIngredients: meal.missingIngredients,
      );
      final needToBuy = IngredientMatcher.partition(all, pantryNames).needToBuy;

      for (final ingredient in needToBuy) {
        final key = IngredientMatcher.normalize(ingredient);
        if (key.isEmpty || !seen.add(key)) continue;
        if (IngredientMatcher.isInPantry(ingredient, groceryNames)) continue;
        newItems.add(GroceryItem(
          name: ingredient,
          quantity: '1',
          section: _classifyIngredient(ingredient),
        ));
      }
    }

    if (newItems.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'All ingredients are already in your pantry or grocery list!'),
        ),
      );
      return;
    }

    try {
      final added = await GroceryRepository.instance.addMultipleItems(newItems);
      if (added > 0) {
        final userName = AuthRepository.instance.value?.name ?? 'A member';
        NotificationService.instance.notifyHouseholdMembers(
          title: 'Grocery List Updated 🛒',
          body:
              '$userName added $added missing ingredients from the meal plan.',
          type: AppNotificationType.groceryListUpdated,
          includeSelf: true,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(added == 0
              ? 'Those items were already on your grocery list.'
              : 'Added $added missing ingredients to Grocery List!'),
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

  /// Classify an ingredient name into a grocery section.
  String _classifyIngredient(String ingredient) {
    final lower = ingredient.toLowerCase();
    if (_containsAny(lower, [
      'chicken',
      'beef',
      'pork',
      'fish',
      'shrimp',
      'prawn',
      'meat',
      'salmon',
      'tuna',
      'bangus',
      'tilapia',
      'galunggong',
      'squid',
      'crab',
      'clams',
      'mussel',
      'sausage',
      'bacon',
      'ham',
      'turkey',
      'lamb',
      'veal',
      'ground'
    ])) {
      return 'MEAT & SEAFOOD';
    }
    if (_containsAny(lower, [
      'milk',
      'cheese',
      'butter',
      'egg',
      'yogurt',
      'cream',
      'curd',
      'dairy',
      'condensed',
      'evaporated',
      'whipping',
      'sour cream'
    ])) {
      return 'DAIRY & REFRIGERATED';
    }
    if (_containsAny(lower, [
      'tomato',
      'lettuce',
      'onion',
      'garlic',
      'pepper',
      'vegetable',
      'carrot',
      'potato',
      'cabbage',
      'spinach',
      'kangkong',
      'sitaw',
      'eggplant',
      'okra',
      'ampalaya',
      'fruit',
      'apple',
      'banana',
      'mango',
      'papaya',
      'lemon',
      'calamansi',
      'ginger',
      'celery',
      'leek',
      'mushroom',
      'herb',
      'cilantro',
      'parsley',
      'basil',
      'bay leaf',
      'lemongrass',
      'pechay'
    ])) {
      return 'PRODUCE AISLE';
    }
    if (_containsAny(lower, [
      'bread',
      'flour',
      'rice',
      'pasta',
      'noodle',
      'oat',
      'cereal',
      'pancit',
      'bihon',
      'misua',
      'sotanghon',
      'spaghetti',
      'macaroni',
      'crackers',
      'biscuit'
    ])) {
      return 'GRAINS & BREAD';
    }
    if (_containsAny(lower, [
      'sauce',
      'vinegar',
      'soy sauce',
      'fish sauce',
      'patis',
      'bagoong',
      'oyster sauce',
      'hoisin',
      'ketchup',
      'mustard',
      'mayo',
      'oil',
      'olive oil',
      'coconut oil',
      'cooking oil',
      'sugar',
      'salt',
      'pepper',
      'cumin',
      'turmeric',
      'paprika',
      'cinnamon',
      'spice',
      'seasoning',
      'stock',
      'broth',
      'coconut milk',
      'canned',
      'paste'
    ])) {
      return 'PANTRY STAPLES';
    }
    return 'PANTRY STAPLES';
  }

  bool _containsAny(String text, List<String> keywords) =>
      keywords.any((k) => text.contains(k));

  // ── AI meal replacement ─────────────────────────────────────────────────────

  Future<void> _replaceMealWithAi(int index) async {
    final visible = _dayMeals;
    if (index < 0 || index >= visible.length) return;
    if (!FamilyPermissions.canReplaceMeal) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(FamilyPermissions.denialMessage('replace meals')),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }
    final current = visible[index];
    final uid = AuthRepository.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to replace a meal.')),
      );
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Replace Meal'),
        content: const Text(
            'Are you sure you want to replace this meal with a new AI-generated recipe?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Replace',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: const Row(
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(width: 20),
            Expanded(
              child: Text(
                'Asking AI for an alternative recipe…',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );

    try {
      final pantryNames = PantryRepository.instance.items.values
          .expand((list) => list)
          .map((item) => item.name)
          .toList();
      final result = await context.read<LlmService>().replaceMeal(
            uid: uid,
            currentMeal: current.toCore(),
            pantryItems: pantryNames,
          );
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      final replacement = GeneratedMeal.fromCore(
        result.data,
        fallbackIndex: index,
      ).copyWith(
        type: current.type,
        dayIndex: current.dayIndex,
        status: MealStatus.pending,
        badgeText: 'AI Replacement',
        replacedMealId: current.id,
      );
      setState(() {
        final allIndex = _allMeals.indexWhere((m) => m.id == current.id);
        if (allIndex >= 0) {
          _allMeals[allIndex] = replacement;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${current.title} replaced with "${replacement.title}". Status is now Pending.'),
          backgroundColor: AppColors.primary,
        ),
      );
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

  // ── Build ───────────────────────────────────────────────────────────────────

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
          'Meal Plan Editor',
          style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 16),
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
          // ── Day selector tabs ─────────────────────────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(_calendarDays, (index) {
                final isSelected = _selectedDayIndex == index;
                final date = _startDate.add(Duration(days: index));
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () => setState(() => _selectedDayIndex = index),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.cardSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color:
                              isSelected ? AppColors.primary : AppColors.border,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            _dayShortLabel(index),
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.textSecondary,
                              fontWeight: isSelected
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            '${date.day}/${date.month}',
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white.withValues(alpha: 0.8)
                                  : AppColors.textMuted,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 20),

          // ── Day header ────────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _dayLabel(_selectedDayIndex),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_dayMeals.length} meals • ${_dayMeals.where((m) => m.isAccepted).length} accepted',
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ── Meals for the day ─────────────────────────────────────────────
          for (var i = 0; i < _dayMeals.length; i++) ...[
            _MealCard(
              meal: _dayMeals[i],
              dayIndex: _selectedDayIndex,
              onReplace: () => _replaceMealWithAi(i),
              onEdit: () => _showEditMealDialog(_dayMeals[i]),
              onDelete: () {
                final targetMeal = _dayMeals[i];
                setState(() {
                  _allMeals.removeWhere((m) => m.id == targetMeal.id);
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Removed ${targetMeal.title}'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              onAccept: () async {
                if (!FamilyPermissions.canAcceptMeal) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:
                          Text(FamilyPermissions.denialMessage('accept meals')),
                      backgroundColor: AppColors.danger,
                    ),
                  );
                  return;
                }
                final targetMeal = _dayMeals[i];
                final pantryNames = PantryRepository.instance.availableNames;
                final allIngredients = IngredientMatcher.allIngredients(
                  ingredients: targetMeal.ingredients,
                  availableIngredients: targetMeal.availableIngredients,
                  missingIngredients: targetMeal.missingIngredients,
                );
                final split = IngredientMatcher.partition(
                  allIngredients,
                  pantryNames,
                );

                setState(() {
                  final allIdx =
                      _allMeals.indexWhere((m) => m.id == targetMeal.id);
                  if (allIdx >= 0) {
                    _allMeals[allIdx] = _allMeals[allIdx].copyWith(
                      status: MealStatus.accepted,
                      // Recompute against live pantry (ignore AI labels).
                      availableIngredients: split.inPantry,
                      missingIngredients: split.needToBuy,
                      ingredients: allIngredients.isNotEmpty
                          ? allIngredients
                          : targetMeal.ingredients,
                    );
                  }
                });

                SavedPlansRepository.instance
                    .updateMealStatus(targetMeal.id, MealStatus.accepted);

                // Send household notification (plan ID not available for drafts)
                final targetMemberName = _familyMembers.isNotEmpty
                    ? _familyMembers[0]
                    : 'your household';
                HouseholdNotificationService.instance.notifyMealAccepted(
                  planId: '', // Draft plans don't have IDs yet
                  mealId: targetMeal.id,
                  mealTitle: targetMeal.title,
                  mealType: targetMeal.type,
                  targetMemberName: targetMemberName,
                );

                final messenger = ScaffoldMessenger.of(context);
                final router = GoRouter.of(context);

                var added = 0;
                try {
                  added = await _pushMissingIngredientsToGrocery(
                    targetMeal.copyWith(
                      availableIngredients: split.inPantry,
                      missingIngredients: split.needToBuy,
                      ingredients: allIngredients.isNotEmpty
                          ? allIngredients
                          : targetMeal.ingredients,
                    ),
                  );
                } catch (_) {
                  added = 0;
                }

                if (!mounted) return;
                final groceryNote = pantryNames.isEmpty
                    ? (added > 0
                        ? 'Pantry empty — added $added ingredients to Grocery.'
                        : 'Pantry empty — ingredients already on Grocery.')
                    : (added > 0
                        ? 'Added $added missing ingredients to Grocery.'
                        : (split.needToBuy.isEmpty
                            ? 'All ingredients are already in your pantry.'
                            : 'Missing items were already on Grocery.'));
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      'Accepted ${targetMeal.title}. $groceryNote',
                    ),
                    backgroundColor: AppColors.primary,
                    action: added > 0
                        ? SnackBarAction(
                            label: 'View List',
                            textColor: Colors.white,
                            onPressed: () => router.go('/grocery'),
                          )
                        : null,
                  ),
                );
              },
              onComplete: () {
                if (!FamilyPermissions.canAcceptMeal) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(FamilyPermissions.denialMessage(
                          'update meal status')),
                      backgroundColor: AppColors.danger,
                    ),
                  );
                  return;
                }
                final targetMeal = _dayMeals[i];
                setState(() {
                  final allIdx =
                      _allMeals.indexWhere((m) => m.id == targetMeal.id);
                  if (allIdx >= 0) {
                    _allMeals[allIdx] = _allMeals[allIdx].copyWith(
                      status: MealStatus.completed,
                    );
                  }
                });
                SavedPlansRepository.instance
                    .updateMealStatus(targetMeal.id, MealStatus.completed);

                // Send household notification (plan ID not available for drafts)
                HouseholdNotificationService.instance.notifyMealCompleted(
                  planId: '', // Draft plans don't have IDs yet
                  mealId: targetMeal.id,
                  mealTitle: targetMeal.title,
                  mealType: targetMeal.type,
                );

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Marked ${targetMeal.title} as completed'),
                    backgroundColor: AppColors.info,
                  ),
                );
              },
              onNotCompleted: () {
                if (!FamilyPermissions.canAcceptMeal) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(FamilyPermissions.denialMessage(
                          'update meal status')),
                      backgroundColor: AppColors.danger,
                    ),
                  );
                  return;
                }
                final targetMeal = _dayMeals[i];
                setState(() {
                  final allIdx =
                      _allMeals.indexWhere((m) => m.id == targetMeal.id);
                  if (allIdx >= 0) {
                    _allMeals[allIdx] = _allMeals[allIdx].copyWith(
                      status: MealStatus.notCompleted,
                    );
                  }
                });
                SavedPlansRepository.instance
                    .updateMealStatus(targetMeal.id, MealStatus.notCompleted);

                // Send household notification (plan ID not available for drafts)
                HouseholdNotificationService.instance.notifyMealNotCompleted(
                  planId: '', // Draft plans don't have IDs yet
                  mealId: targetMeal.id,
                  mealTitle: targetMeal.title,
                  mealType: targetMeal.type,
                );

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content:
                        Text('Marked ${targetMeal.title} as not completed'),
                    backgroundColor: AppColors.danger,
                  ),
                );
              },
            ),
            const SizedBox(height: 14),
          ],

          // ── Add Dish to this day ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: OutlinedButton.icon(
              onPressed: _showAddMealDialog,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(
                  color: AppColors.primary.withValues(alpha: 0.6),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.add_circle_outline, size: 18),
              label: Text(
                'Add Dish to ${_dayLabel(_selectedDayIndex)}',
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ),

          if (_dayMeals.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'No meals for this day. Tap "Add Dish" above to create one.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ),

          const SizedBox(height: 12),

          // ── Action buttons ────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _generateGroceryList,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side:
                        const BorderSide(color: AppColors.primary, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.shopping_cart_outlined, size: 18),
                  label: const Text('Export Grocery',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
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
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.bookmark_add, size: 18),
                  label: const Text('Save Plan',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ── Meal card widget ──────────────────────────────────────────────────────────

class _MealCard extends StatefulWidget {
  const _MealCard({
    required this.meal,
    required this.dayIndex,
    required this.onReplace,
    required this.onAccept,
    this.onComplete,
    this.onNotCompleted,
    this.onEdit,
    this.onDelete,
  });

  final GeneratedMeal meal;
  final int dayIndex;
  final VoidCallback onReplace;
  final VoidCallback onAccept;
  final VoidCallback? onComplete;
  final VoidCallback? onNotCompleted;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  State<_MealCard> createState() => _MealCardState();
}

class _MealCardState extends State<_MealCard> {
  bool _expanded = false;
  String? _imageUrl;
  String? _photographerName;
  String? _photographerUrl;
  String? _unsplashPageUrl;
  bool _showAttribution = false;
  bool _imageFetched = false;

  @override
  void initState() {
    super.initState();
    _fetchImage();
  }

  Future<void> _fetchImage() async {
    if (_imageFetched) return;
    _imageFetched = true;

    // Use provided imageUrl first, then fall back to Unsplash
    if (widget.meal.imageUrl.isNotEmpty) {
      if (mounted) setState(() => _imageUrl = widget.meal.imageUrl);
      return;
    }

    final photo = await UnsplashService.instance.fetchMealImage(
      widget.meal.imageSearchQuery,
      mealTitle: widget.meal.title,
    );
    if (photo != null && mounted) {
      setState(() {
        _imageUrl = photo.smallUrl;
        _photographerName = photo.photographerName;
        _photographerUrl = photo.photographerProfileUrl;
        _unsplashPageUrl = photo.unsplashPageUrl;
        _showAttribution = photo.showUnsplashAttribution;
      });
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Image ─────────────────────────────────────────────────────────
          InkWell(
            onTap: () =>
                context.push('/meal/${widget.meal.id}', extra: widget.meal),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: _imageUrl != null
                  ? Stack(
                      children: [
                        MealNetworkImage(
                          url: _imageUrl!,
                          height: 160,
                          width: double.infinity,
                        ),
                        // Attribution overlay (Unsplash TOS only)
                        if (_showAttribution && _photographerName != null)
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              color: Colors.black.withValues(alpha: 0.5),
                              child: Row(
                                children: [
                                  const Text(
                                    'Photo by ',
                                    style: TextStyle(
                                        color: Colors.white, fontSize: 9),
                                  ),
                                  GestureDetector(
                                    onTap: () => _openUrl(_photographerUrl ??
                                        _unsplashPageUrl ??
                                        ''),
                                    child: Text(
                                      _photographerName!,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                  const Text(
                                    ' on ',
                                    style: TextStyle(
                                        color: Colors.white, fontSize: 9),
                                  ),
                                  GestureDetector(
                                    onTap: () =>
                                        _openUrl(_unsplashPageUrl ?? ''),
                                    child: const Text(
                                      'Unsplash',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    )
                  : _imagePlaceholder(),
            ),
          ),

          // ── Meal Info ─────────────────────────────────────────────────────
          InkWell(
            onTap: () =>
                context.push('/meal/${widget.meal.id}', extra: widget.meal),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text(
                            widget.meal.type.toUpperCase(),
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 8),
                          MealStatusBadge(
                            status: widget.meal.status,
                            compact: true,
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Text(
                            widget.meal.calories,
                            style: const TextStyle(
                                color: AppColors.textMuted, fontSize: 11),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right,
                              size: 16, color: AppColors.textMuted),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.meal.title.trim().isEmpty
                        ? 'Tap Edit to name this ${widget.meal.type.toLowerCase()}'
                        : widget.meal.title,
                    style: TextStyle(
                      color: widget.meal.title.trim().isEmpty
                          ? AppColors.textMuted
                          : AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      fontStyle: widget.meal.title.trim().isEmpty
                          ? FontStyle.italic
                          : FontStyle.normal,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${widget.meal.prepTime} prep  •  ${widget.meal.badgeText}',
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 11),
                  ),

                  // Tutorial link
                  if (widget.meal.youtubeSearchQuery != null &&
                      widget.meal.youtubeSearchQuery!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () {
                        final q = Uri.encodeComponent(
                            widget.meal.youtubeSearchQuery!);
                        _openUrl(
                            'https://www.youtube.com/results?search_query=$q');
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.play_circle_outline,
                              color: Colors.red, size: 16),
                          const SizedBox(width: 4),
                          const Text(
                            'Watch Tutorial ↗',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // ── Expandable ingredients ────────────────────────────────────────
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  Text(
                    _expanded ? 'Hide ingredients' : 'Show ingredients',
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.primary,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),

          if (_expanded) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Builder(
                builder: (context) {
                  final pantryNames = PantryRepository.instance.availableNames;
                  final all = IngredientMatcher.allIngredients(
                    ingredients: widget.meal.ingredients,
                    availableIngredients: widget.meal.availableIngredients,
                    missingIngredients: widget.meal.missingIngredients,
                  );
                  final split = IngredientMatcher.partition(
                    all,
                    pantryNames,
                  );
                  final have = split.inPantry;
                  final need = split.needToBuy;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (have.isNotEmpty) ...[
                        const Text('✅ In pantry:',
                            style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 12)),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: have
                              .map((i) =>
                                  _IngredientChip(label: i, available: true))
                              .toList(),
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (need.isNotEmpty) ...[
                        Text(
                          pantryNames.isEmpty
                              ? '🛒 Need to buy (pantry empty):'
                              : '🛒 Need to buy:',
                          style: const TextStyle(
                              color: AppColors.danger,
                              fontWeight: FontWeight.w700,
                              fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: need
                              .map((i) =>
                                  _IngredientChip(label: i, available: false))
                              .toList(),
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (have.isEmpty && need.isEmpty && all.isNotEmpty) ...[
                        const Text('Ingredients:',
                            style: TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 12)),
                        const SizedBox(height: 4),
                        ...all.map((i) => Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Text('• $i',
                                  style: const TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 12)),
                            )),
                        const SizedBox(height: 8),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],

          // ── Actions ───────────────────────────────────────────────────────
          const Divider(
              height: 1, indent: 12, endIndent: 12, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton.icon(
                      onPressed: widget.onReplace,
                      icon: const Icon(Icons.refresh,
                          size: 14, color: AppColors.primary),
                      label: const Text(
                        'Replace',
                        style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 12),
                      ),
                    ),
                    if (widget.onEdit != null)
                      IconButton(
                        onPressed: widget.onEdit,
                        icon: const Icon(Icons.edit_outlined,
                            size: 18, color: AppColors.textSecondary),
                        tooltip: 'Edit Dish',
                        visualDensity: VisualDensity.compact,
                      ),
                    if (widget.onDelete != null)
                      IconButton(
                        onPressed: widget.onDelete,
                        icon: const Icon(Icons.delete_outline,
                            size: 18, color: AppColors.danger),
                        tooltip: 'Remove Dish',
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
                if (widget.meal.isCompleted)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.infoLight,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: AppColors.info.withValues(alpha: 0.4)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.done_all, size: 14, color: AppColors.info),
                        SizedBox(width: 4),
                        Text(
                          'Completed',
                          style: TextStyle(
                            color: AppColors.info,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (widget.meal.isNotCompleted)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.dangerLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Not Completed',
                      style: TextStyle(
                        color: AppColors.danger,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  )
                else if (widget.meal.isAccepted)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.onNotCompleted != null)
                        TextButton(
                          onPressed: widget.onNotCompleted,
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.danger,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            visualDensity: VisualDensity.compact,
                          ),
                          child: const Text('Skip',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 12)),
                        ),
                      ElevatedButton.icon(
                        onPressed: widget.onComplete,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.info,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.done, size: 14),
                        label: const Text('Done',
                            style: TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 12)),
                      ),
                    ],
                  )
                else
                  ElevatedButton.icon(
                    onPressed: widget.onAccept,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.check, size: 14),
                    label: const Text('Accept',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 12)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      height: 120,
      color: AppColors.primaryLight,
      child: const Center(
        child: Icon(Icons.restaurant, color: AppColors.primary, size: 40),
      ),
    );
  }
}

class _IngredientChip extends StatelessWidget {
  const _IngredientChip({required this.label, required this.available});

  final String label;
  final bool available;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: available ? AppColors.primaryLight : AppColors.dangerLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: available ? AppColors.primary : AppColors.danger,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
