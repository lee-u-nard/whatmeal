import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/llm_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/models/app_notification.dart';
import '../../../core/utils/family_permissions.dart';
import '../../../core/utils/ingredient_matcher.dart';
import '../../../core/utils/week_calendar.dart';
import '../../auth/data/auth_repository.dart';
import '../../pantry/data/pantry_repository.dart';
import '../../grocery/data/grocery_repository.dart';
import '../../grocery/models/grocery_item.dart';
import '../../profile/data/family_member_repository.dart';
import '../../profile/models/family_member.dart';
import '../../ai_settings/models/ai_provider.dart';
import '../../ai_settings/data/ai_provider_repository.dart';
import '../models/saved_meal_plan.dart';
import '../data/saved_plans_repository.dart';
import '../widgets/meal_calendar_workspace.dart';
import '../../meal/models/meal.dart';

class MealPlanPage extends StatefulWidget {
  const MealPlanPage({super.key});

  @override
  State<MealPlanPage> createState() => _MealPlanPageState();
}

class _MealPlanPageState extends State<MealPlanPage> {
  /// Toggle between AI Generation and Manual Custom Plan creation.
  bool _isAiMode = true;

  /// When true, the create/generate form is expanded below the calendar.
  bool _showCreator = false;
  final _creatorKey = GlobalKey();
  late final TextEditingController _customTitleController;
  late final TextEditingController _budgetController;

  /// IDs (not names) of currently selected family members.
  final _selectedMemberIds = <String>{};

  /// Default to a full Mon–Sun week.
  int _selectedDays = 7;

  final _mealTypes = ['Breakfast', 'Lunch', 'Dinner'];
  final _selectedMealTypes = <String>{'Breakfast', 'Lunch', 'Dinner'};

  bool _prioritizePantry = true;

  static const _allCuisines = [
    'Filipino',
    'Chinese',
    'Japanese',
    'Korean',
    'Thai',
    'Vietnamese',
    'Indonesian',
    'Indian',
    'Mediterranean',
    'Italian',
    'Mexican',
    'American',
    'Middle Eastern',
    'French',
    'Spanish',
    'Greek',
    'Brazilian',
    'Caribbean',
    'African',
  ];

  /// Cuisine selection is OPTIONAL — empty means "any cuisine".
  final _selectedCuisines = <String>{};

  @override
  void initState() {
    super.initState();
    _customTitleController = TextEditingController(text: 'My Family Meal Plan');
    _budgetController = TextEditingController();
  }

  @override
  void dispose() {
    _customTitleController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  void _createCustomMealPlan() {
    final members = FamilyMemberRepository.instance.members;
    final selected =
        members.where((m) => _selectedMemberIds.contains(m.id)).toList();

    if (selected.isEmpty) {
      _showError(
        title: 'Select Family Members',
        message: 'Please select at least one family member to plan meals for.',
      );
      return;
    }
    if (_selectedMealTypes.isEmpty) {
      _showError(
        title: 'Select Meal Types',
        message:
            'Please select at least one meal type (Breakfast, Lunch, or Dinner).',
      );
      return;
    }

    final memberNames = selected.map((m) => m.displayName).toList();
    final initialMeals = <GeneratedMeal>[];
    final title = _customTitleController.text.trim().isEmpty
        ? 'Custom Meal Plan'
        : _customTitleController.text.trim();

    for (var day = 0; day < _selectedDays; day++) {
      for (final type in _selectedMealTypes) {
        initialMeals.add(
          GeneratedMeal(
            id: 'custom_${day}_${type.toLowerCase()}_${DateTime.now().microsecondsSinceEpoch}',
            title: '',
            type: type,
            dayIndex: day,
            prepTime: '',
            calories: '',
            badgeText: 'Custom',
            imageUrl: '',
            ingredients: const [],
            macros: const {
              'Protein': '',
              'Carbs': '',
              'Fats': '',
            },
            status: MealStatus.accepted,
          ),
        );
      }
    }

    context.push(
      '/generated-plan',
      extra: GeneratedPlanDraft(
        meals: initialMeals,
        familyMembers: memberNames,
        numberOfDays: _selectedDays,
        startDate: WeekCalendar.mondayOf(DateTime.now()),
        title: title,
      ),
    );
  }

  Future<void> _generateMealPlan() async {
    final members = FamilyMemberRepository.instance.members;
    final selected =
        members.where((m) => _selectedMemberIds.contains(m.id)).toList();

    if (selected.isEmpty) {
      _showError(
        title: 'Select Family Members',
        message: 'Please select at least one family member to plan meals for.',
      );
      return;
    }
    if (_selectedMealTypes.isEmpty) {
      _showError(
        title: 'Select Meal Types',
        message:
            'Please select at least one meal type (Breakfast, Lunch, or Dinner).',
      );
      return;
    }

    final uid = AuthRepository.instance.currentUser?.uid;
    if (uid == null) {
      _showError(
        title: 'Sign in required',
        message: 'Please sign in to generate a meal plan.',
      );
      return;
    }

    final aiConfig = AiProviderRepository.instance.value;
    final providerName = aiConfig.providerType.displayName;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                    color: AppColors.primary, strokeWidth: 3),
              ),
              const SizedBox(height: 20),
              const Text(
                'Generating AI Meal Plan',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                'Using $providerName for ${selected.map((m) => m.name).join(", ")}…',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      // Gather pantry items
      final pantryNames = PantryRepository.instance.availableNames;

      // Gather grocery items
      final groceryNames = GroceryRepository.instance.allItemNames;

      // Gather combined restrictions and preferences across selected members
      final restrictions =
          selected.expand((m) => m.restrictions).toSet().toList();
      final preferences =
          selected.expand((m) => m.preferences).toSet().toList();
      final memberAges = {for (final m in selected) m.name: m.age};
      final memberNames = selected.map((m) => m.name).toList();
      final budget = _budgetController.text.trim();

      final result = await context.read<LlmService>().generateMealPlan(
            uid: uid,
            familyMemberNames: memberNames,
            numberOfDays: _selectedDays,
            mealTypes: _selectedMealTypes.toList(),
            cuisinePreferences: _selectedCuisines.toList(),
            prioritizePantry: _prioritizePantry,
            pantryItems: pantryNames,
            groceryItems: groceryNames,
            restrictions: restrictions,
            preferences: preferences,
            memberAges: memberAges,
            budget: budget.isEmpty ? null : budget,
          );

      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      final meals = <GeneratedMeal>[];
      for (var i = 0; i < result.data.length; i++) {
        meals.add(GeneratedMeal.fromCore(result.data[i], fallbackIndex: i));
      }

      // Notify the household that a meal plan is ready
      NotificationService.instance.notifyHouseholdMembers(
        title: 'Meal Plan Ready 🍽️',
        body:
            'A $_selectedDays-day AI meal plan for ${memberNames.join(", ")} has been generated'
            '${result.usedFallback ? ' (via Gemini fallback)' : ''}.',
        type: AppNotificationType.mealPlanGenerated,
        includeSelf: true,
      );

      if (result.usedFallback && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Your custom AI provider failed — used built-in Gemini instead.',
            ),
            backgroundColor: AppColors.warning,
          ),
        );
      }

      context.push(
        '/generated-plan',
        extra: GeneratedPlanDraft(
          meals: meals,
          familyMembers: memberNames,
          numberOfDays: _selectedDays,
          startDate: WeekCalendar.mondayOf(DateTime.now()),
        ),
      );
    } on QuotaExceededException {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      _showError(
        title: 'Daily limit reached',
        message: 'Built-in Gemini generations for today are used up. '
            'Try again tomorrow, or add an OpenAI / Claude / Groq key in AI Settings.',
        canRetry: false,
      );
    } on AiProviderException catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      _showError(
        title: '${e.provider.displayName} Error',
        message: e.toString(),
      );
    } catch (e) {
      debugPrint('[MealPlan] generate failed: $e');
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      final message = e is FirebaseAiNotEnabledException
          ? e.toString()
          : e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
      _showError(
        title: 'Generation failed',
        message: message.isNotEmpty
            ? message
            : "Couldn't generate a plan right now. Please try again or check AI Settings.",
      );
    }
  }

  void _openCreator({bool aiMode = true}) {
    setState(() {
      _isAiMode = aiMode;
      _showCreator = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _creatorKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _generateGroceryFromCalendar() async {
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

    final weekMonday = WeekCalendar.mondayOf(DateTime.now());
    final pantryNames = PantryRepository.instance.availableNames;
    final groceryNames = GroceryRepository.instance.allItemNames;
    final newItems = <GroceryItem>[];
    final seen = <String>{};

    for (final plan in SavedPlansRepository.instance.value) {
      for (final meal in plan.activeMeals) {
        if (!(meal.isAccepted || meal.isCompleted)) continue;
        final date = plan.dateForMeal(meal);
        if (!WeekCalendar.isInWeek(date, weekMonday)) continue;

        final all = IngredientMatcher.allIngredients(
          ingredients: meal.ingredients,
          availableIngredients: meal.availableIngredients,
          missingIngredients: meal.missingIngredients,
        );
        final need = IngredientMatcher.partition(all, pantryNames).needToBuy;
        for (final ingredient in need) {
          final key = IngredientMatcher.normalize(ingredient);
          if (key.isEmpty || !seen.add(key)) continue;
          if (IngredientMatcher.isInPantry(ingredient, groceryNames)) continue;
          newItems.add(GroceryItem(
            name: ingredient,
            quantity: '1',
            section: 'OTHER',
          ));
        }
      }
    }

    if (newItems.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No missing ingredients for accepted meals this week '
            '(or pantry already covers them).',
          ),
        ),
      );
      return;
    }

    try {
      final added = await GroceryRepository.instance.addMultipleItems(newItems);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added $added items to Grocery List'),
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
          content: Text('Could not update grocery list: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  void _showError({
    required String title,
    required String message,
    bool canRetry = true,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.danger),
            const SizedBox(width: 8),
            Expanded(child: Text(title)),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Dismiss',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          OutlinedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.push('/ai-settings');
            },
            child: const Text('AI Settings'),
          ),
          if (canRetry)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _generateMealPlan();
              },
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Retry',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700)),
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
        // Initialise selected IDs on first load (select all by default)
        if (_selectedMemberIds.isEmpty && members.isNotEmpty) {
          _selectedMemberIds.addAll(members.map((m) => m.id));
        }

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ── Meal Calendar (primary workspace) ──────────────────────────
            MealCalendarWorkspace(
              onCreatePlan: () => _openCreator(aiMode: true),
              onGenerateGrocery: _generateGroceryFromCalendar,
            ),

            const SizedBox(height: 28),
            const Divider(color: AppColors.border),
            const SizedBox(height: 8),

            // ── Create / Generate form ─────────────────────────────────────
            KeyedSubtree(
              key: _creatorKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header row ─────────────────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _isAiMode
                            ? 'Generate AI Meal Plan'
                            : 'Create Custom Meal Plan',
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 18),
                      ),
                      TextButton(
                        onPressed: () =>
                            setState(() => _showCreator = !_showCreator),
                        child: Text(
                          _showCreator ? 'Hide' : 'Show',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  if (_showCreator) ...[
                    const SizedBox(height: 16),

                    // ── Mode Switcher Tab (AI Generator vs Create Own Plan) ─────────
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.cardSurface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _isAiMode = true),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: _isAiMode
                                      ? AppColors.primary
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                alignment: Alignment.center,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.auto_awesome,
                                        size: 16,
                                        color: _isAiMode
                                            ? Colors.white
                                            : AppColors.textSecondary),
                                    const SizedBox(width: 6),
                                    Text(
                                      'AI Generator',
                                      style: TextStyle(
                                        color: _isAiMode
                                            ? Colors.white
                                            : AppColors.textSecondary,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => _isAiMode = false),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: !_isAiMode
                                      ? AppColors.primary
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                alignment: Alignment.center,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.edit_note_rounded,
                                        size: 18,
                                        color: !_isAiMode
                                            ? Colors.white
                                            : AppColors.textSecondary),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Create Own Plan',
                                      style: TextStyle(
                                        color: !_isAiMode
                                            ? Colors.white
                                            : AppColors.textSecondary,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Custom Plan Title Input (When in manual mode) ───────────────
                    if (!_isAiMode) ...[
                      const Text(
                        'Plan Title',
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _customTitleController,
                        decoration: InputDecoration(
                          hintText: 'e.g., Weekly Family Menu',
                          prefixIcon: const Icon(Icons.edit_calendar,
                              color: AppColors.primary, size: 20),
                          filled: true,
                          fillColor: AppColors.cardSurface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: AppColors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: AppColors.border),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // ── Plan Meals For ──────────────────────────────────────────────
                    const Text(
                      'Plan Meals For',
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14),
                    ),
                    const SizedBox(height: 8),

                    if (members.isEmpty) ...[
                      // Empty state — no family members added yet
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.cardSurface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.group_add_outlined,
                                size: 40, color: AppColors.textMuted),
                            const SizedBox(height: 12),
                            const Text(
                              'No family members yet',
                              style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Add family members in the Profile tab so the AI can plan meals tailored for everyone.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                  height: 1.4),
                            ),
                            const SizedBox(height: 14),
                            ElevatedButton.icon(
                              onPressed: () {
                                // Switch to Profile tab (index 4)
                                // Use go_router to navigate to the profile branch
                                context.go('/profile');
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.person_add_outlined,
                                  size: 16),
                              label: const Text('Go to Profile',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.cardSurface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          children: members.map((member) {
                            final isChecked =
                                _selectedMemberIds.contains(member.id);
                            return CheckboxListTile(
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              visualDensity: VisualDensity.compact,
                              title: Text(
                                member.displayName,
                                style: TextStyle(
                                  color: isChecked
                                      ? AppColors.primary
                                      : AppColors.textPrimary,
                                  fontWeight: isChecked
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  fontSize: 13,
                                ),
                              ),
                              subtitle: member.restrictions.isNotEmpty
                                  ? Text(
                                      member.restrictions.take(2).join(', ') +
                                          (member.restrictions.length > 2
                                              ? '…'
                                              : ''),
                                      style: const TextStyle(
                                          color: AppColors.danger,
                                          fontSize: 10),
                                    )
                                  : null,
                              activeColor: AppColors.primary,
                              checkColor: Colors.white,
                              value: isChecked,
                              onChanged: (checked) {
                                setState(() {
                                  if (checked == true) {
                                    _selectedMemberIds.add(member.id);
                                  } else {
                                    _selectedMemberIds.remove(member.id);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // ── Number of Days ──────────────────────────────────────────────
                    const Text(
                      'Number of Days',
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14),
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
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.cardSurface,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.border,
                                  ),
                                ),
                                child: Text(
                                  '$days Day${days > 1 ? 's' : ''}',
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : AppColors.textSecondary,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
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

                    // ── Meal Types ─────────────────────────────────────────────────
                    const Text(
                      'Include Meal Types',
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14),
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
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.primaryLight
                                      : AppColors.cardSurface,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.border,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (isSelected)
                                      const Padding(
                                        padding: EdgeInsets.only(right: 4),
                                        child: Icon(Icons.check,
                                            size: 14, color: AppColors.primary),
                                      ),
                                    Text(
                                      type,
                                      style: TextStyle(
                                        color: isSelected
                                            ? AppColors.primary
                                            : AppColors.textSecondary,
                                        fontWeight: isSelected
                                            ? FontWeight.w700
                                            : FontWeight.w500,
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

                    if (_isAiMode) ...[
                      const SizedBox(height: 20),

                      // ── Prioritize Pantry ───────────────────────────────────────────
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
                                      fontSize: 14),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Use ingredients already available first',
                                  style: TextStyle(
                                      color: AppColors.textMuted, fontSize: 11),
                                ),
                              ],
                            ),
                            Switch(
                              value: _prioritizePantry,
                              activeTrackColor: AppColors.primary,
                              onChanged: (val) =>
                                  setState(() => _prioritizePantry = val),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ── Budget guideline ───────────────────────────────────────────
                      const Text(
                        'Weekly Budget (optional)',
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _budgetController,
                        keyboardType: TextInputType.text,
                        decoration: InputDecoration(
                          hintText: 'e.g. \$50/week or under ₱2000',
                          prefixIcon: const Icon(Icons.payments_outlined,
                              color: AppColors.primary, size: 20),
                          filled: true,
                          fillColor: AppColors.cardSurface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: AppColors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: AppColors.border),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ── Cuisine Preferences ─────────────────────────────────────────
                      Row(
                        children: [
                          const Text(
                            'Cuisine Preferences',
                            style: TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 14),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Optional',
                              style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Leave all unselected for any cuisine.',
                        style:
                            TextStyle(color: AppColors.textMuted, fontSize: 11),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _allCuisines.map((cuisine) {
                          final isSelected =
                              _selectedCuisines.contains(cuisine);
                          return FilterChip(
                            label: Text(cuisine),
                            selected: isSelected,
                            selectedColor: AppColors.primaryLight,
                            checkmarkColor: AppColors.primary,
                            backgroundColor: AppColors.cardSurface,
                            side: BorderSide(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.border,
                            ),
                            labelStyle: TextStyle(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
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
                    ],

                    const SizedBox(height: 28),

                    // ── Primary Action CTA ──────────────────────────────────────────
                    SizedBox(
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: members.isEmpty
                            ? null
                            : (_isAiMode
                                ? _generateMealPlan
                                : _createCustomMealPlan),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: AppColors.border,
                          elevation: 2,
                          shadowColor: const Color.fromRGBO(27, 42, 30, 0.2),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: Icon(
                            _isAiMode
                                ? Icons.auto_awesome
                                : Icons.edit_calendar,
                            size: 20),
                        label: Text(
                          _isAiMode
                              ? 'Generate AI Meal Plan'
                              : 'Create Custom Meal Plan',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 16),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),
                  ], // end if (_showCreator)
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
