import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/llm_service.dart';
import '../../../core/utils/week_calendar.dart';
import '../../../core/routing/meal_route.dart';
import '../../../core/utils/family_permissions.dart';
import '../../auth/data/auth_repository.dart';
import '../../pantry/data/pantry_repository.dart';
import '../../grocery/data/grocery_repository.dart';
import '../../profile/data/family_member_repository.dart';
import '../../profile/models/family_member.dart';
import '../../ai_settings/models/ai_provider.dart';
import '../../ai_settings/data/ai_provider_repository.dart';
import '../models/saved_meal_plan.dart';
import '../../../core/services/ai/generation_failure.dart';
import '../data/generation_inventory.dart';
import '../data/saved_plans_repository.dart';
import '../widgets/meal_calendar_workspace.dart';
import '../widgets/meal_participant_tile.dart';
import '../../../core/widgets/labeled_action_row.dart';
import '../../../core/widgets/ai_generation_snack_bar.dart';
import '../../meal/models/meal.dart';

class MealPlanPage extends StatefulWidget {
  const MealPlanPage(
      {super.key,
      this.initialDate,
      this.memberRepository,
      this.savedPlansRepository});
  final DateTime? initialDate;
  final FamilyMemberRepository? memberRepository;
  final SavedPlansRepository? savedPlansRepository;

  @override
  State<MealPlanPage> createState() => _MealPlanPageState();
}

class _MealPlanPageState extends State<MealPlanPage> {
  FamilyMemberRepository get _members =>
      widget.memberRepository ?? FamilyMemberRepository.instance;
  SavedPlansRepository get _plans =>
      widget.savedPlansRepository ?? SavedPlansRepository.instance;

  /// Toggle between AI Generation and Manual Custom Plan creation.
  bool _isAiMode = true;
  bool _isGenerating = false;
  late DateTime _selectedPlanDate;

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

  /// Leave unset until the user chooses a cuisine for AI generation.
  final _selectedCuisines = <String>{};

  @override
  void initState() {
    super.initState();
    _selectedPlanDate = WeekCalendar.dateOnly(
        widget.initialDate ?? WeekCalendar.mondayOf(DateTime.now()));
    _customTitleController = TextEditingController(text: 'My Family Meal Plan');
    _budgetController = TextEditingController();
  }

  @override
  void didUpdateWidget(covariant MealPlanPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialDate != null &&
        widget.initialDate != oldWidget.initialDate) {
      _selectedPlanDate = WeekCalendar.dateOnly(widget.initialDate!);
    }
  }

  @override
  void dispose() {
    _customTitleController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  void _createCustomMealPlan() {
    final members = _members.members;
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
        isManual: true,
        meals: initialMeals,
        familyMembers: memberNames,
        selectedMemberIds: selected.map((m) => m.id).toList(),
        cuisinePreferences: _selectedCuisines.toList(),
        numberOfDays: _selectedDays,
        startDate: _selectedPlanDate,
        title: title,
        prioritizePantry: _prioritizePantry,
        sourceSessionVersion: _plans.sessionVersion,
      ),
    );
  }

  Future<void> _generateMealPlan() async {
    if (_isGenerating) return;
    if (!FamilyPermissions.canAcceptMeal) {
      _showError(
          title: 'View-only access',
          message: 'Your household role cannot create meal plans.');
      return;
    }
    final repository = _plans;
    final session = repository.sessionVersion;
    // Freeze the selection for this request; never replace it with today's week.
    final planStartDate = _selectedPlanDate;
    if (_selectedCuisines.isEmpty) {
      _showError(
          title: 'Select Cuisine',
          message:
              'Choose at least one cuisine before generating recommendations.');
      return;
    }
    final members = _members.members;
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

    // Capture the originating workspace before spending generation quota.
    // Firebase Auth may exist before its account profile has finished loading.
    final root = repository.workspacePath;
    if (root == null || AuthRepository.instance.value?.id != uid) {
      _showError(
        title: 'Account still loading',
        message: 'Please wait for your account data to load, then retry.',
      );
      return;
    }

    final GenerationInventory inventory;
    try {
      inventory = GenerationInventory.capture(
        workspacePath: root,
        pantry: PantryRepository.instance,
        groceries: GroceryRepository.instance,
        now: DateTime.now(),
      );
    } on GenerationInventoryUnavailable catch (error) {
      _showError(
        title: 'Inventory unavailable',
        message: error.toString(),
        onRetry: () {
          PantryRepository.instance.retry();
          GroceryRepository.instance.retry();
        },
      );
      return;
    }

    final aiSettings = AiProviderRepository.instance;
    final settingsError = aiSettings.generationReadinessError;
    if (settingsError != null) {
      _showError(
          title: 'AI settings not ready',
          message: settingsError,
          onRetry: aiSettings.retry);
      return;
    }
    final aiConfig = aiSettings.value;
    final providerName = aiConfig.providerType.displayName;

    _isGenerating = true;
    BuildContext? progressContext;
    void closeProgress() {
      final dialog = progressContext;
      progressContext = null;
      if (dialog != null && dialog.mounted) Navigator.of(dialog).pop();
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        progressContext = ctx;
        return PopScope(
            canPop: false,
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
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
            ));
      },
    );

    try {
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
            pantryItems: inventory.pantryItems,
            groceryItems: inventory.groceryItems,
            restrictions: restrictions,
            preferences: preferences,
            memberAges: memberAges,
            budget: budget.isEmpty ? null : budget,
          );

      if (!mounted) return;

      if (session != _plans.sessionVersion) {
        closeProgress();
        return;
      }
      final meals = <GeneratedMeal>[];
      for (var i = 0; i < result.data.length; i++) {
        meals.add(GeneratedMeal.fromCore(result.data[i], fallbackIndex: i));
      }

      final startDate = planStartDate;
      final draft = GeneratedPlanDraft(
        meals: meals,
        familyMembers: memberNames,
        selectedMemberIds: selected.map((m) => m.id).toList(),
        cuisinePreferences: _selectedCuisines.toList(),
        numberOfDays: _selectedDays,
        startDate: startDate,
        title: 'Meal Plan',
        prioritizePantry: _prioritizePantry,
        sourceSessionVersion: session,
      );
      closeProgress();
      if (!mounted || session != repository.sessionVersion) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(AiGenerationSnackBar(
        result: result,
      ));

      context.push(
        '/generated-plan',
        extra: draft,
      );
    } on QuotaExceededException {
      if (!mounted) return;
      closeProgress();
      _showError(
        title: 'Daily limit reached',
        message: 'Built-in Gemini generations for today are used up. '
            'Try again tomorrow, or add an OpenAI / Claude / Groq key in AI Settings.',
        canRetry: false,
      );
    } on AiProviderException catch (e) {
      if (!mounted) return;
      closeProgress();
      _showError(
        title: '${e.provider.displayName} Error',
        message: e.toString(),
      );
    } catch (e) {
      debugPrint('[MealPlan] generate failed: ${e.runtimeType}');
      if (!mounted) return;
      closeProgress();
      _showError(
          title: e is AiSetupFailure ? 'AI setup failed' : 'Generation failed',
          message: e is AiSetupFailure
              ? e.toString()
              : GenerationFailure.from(e).toString());
    } finally {
      _isGenerating = false;
      closeProgress();
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
    context.go('/grocery');
  }

  void _showError({
    required String title,
    required String message,
    bool canRetry = true,
    VoidCallback? onRetry,
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
                (onRetry ?? _generateMealPlan)();
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
      valueListenable: _members,
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
              repository: _plans,
              selectedDate: _selectedPlanDate,
              onDateSelected: (date) {
                setState(() => _selectedPlanDate = date);
                context.replace(mealCalendarRoute(date));
              },
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
                            return MealParticipantTile(
                              name: member.displayName,
                              restrictions: member.restrictions,
                              selected: isChecked,
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
                        child: LabeledActionRow(
                          label: const Column(
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
                          action: Switch(
                            value: _prioritizePantry,
                            activeTrackColor: AppColors.primary,
                            onChanged: (val) =>
                                setState(() => _prioritizePantry = val),
                          ),
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
                        'Choose cuisines before generating AI recommendations.',
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
