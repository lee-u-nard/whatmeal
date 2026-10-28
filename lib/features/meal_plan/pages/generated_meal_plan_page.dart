import 'dart:async';
import '../../../core/routing/meal_route.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/llm_service.dart';
import '../../../core/services/ai/generation_failure.dart';
import '../../../core/services/ai/pantry_prompt_context.dart';
import '../../../core/widgets/ai_generation_snack_bar.dart';
import '../../../core/utils/family_permissions.dart';
import '../../meal/widgets/meal_ingredients_panel.dart';
import '../../meal/widgets/unsaved_meal_preview.dart';
import '../../../core/utils/week_calendar.dart';
import '../../auth/data/auth_repository.dart';
import '../../pantry/data/pantry_repository.dart';
import '../../profile/data/family_member_repository.dart';
import '../data/saved_plans_repository.dart';
import '../models/saved_meal_plan.dart';
import '../models/meal_plan.dart';
import '../widgets/unsaved_plan_guard.dart';
import '../widgets/add_meal_dialog.dart';
import '../../meal/models/meal.dart';
import '../../meal/widgets/meal_status_badge.dart';
import '../../meal/widgets/meal_network_image.dart';

class GeneratedMealPlanPage extends StatefulWidget {
  const GeneratedMealPlanPage({super.key, this.draft, this.repository});

  final GeneratedPlanDraft? draft;
  final SavedPlansRepository? repository;

  @override
  State<GeneratedMealPlanPage> createState() => _GeneratedMealPlanPageState();
}

class _GeneratedMealPlanPageState extends State<GeneratedMealPlanPage> {
  SavedPlansRepository get _repo =>
      widget.repository ?? SavedPlansRepository.instance;
  List<GeneratedMeal> get _mealsForSave =>
      widget.draft?.mealsForSaving(_allMeals) ?? List.of(_allMeals);
  int _selectedDayIndex = 0;
  String? _planPath;
  Future<String>? _saving;
  bool _mutating = false;
  bool _saveDialogBusy = false;
  late int _session;

  Future<String> _ensurePersisted() async {
    final repo = _repo;
    if (repo.sessionVersion != _session) {
      throw StateError('Account or household changed. Reopen the plan.');
    }
    if (_planPath != null) return _planPath!;
    return _saving ??= _saveDraft();
  }

  Future<String> _saveDraft() async {
    final repo = _repo;
    final root = repo.workspacePath;
    try {
      final meals = _mealsForSave;
      final days = meals.fold<int>(_numberOfDays,
          (days, meal) => meal.dayIndex + 1 > days ? meal.dayIndex + 1 : days);
      final title = _saveTitleController.text.trim().isEmpty
          ? 'Family Meal Plan'
          : _saveTitleController.text.trim();
      final id = await repo.savePlan(
          MealPlan(
              id: '',
              title: title,
              startDate: _startDate,
              endDate: DateTime(
                  _startDate.year, _startDate.month, _startDate.day + days - 1),
              numberOfDays: days,
              mealTypes: _allMeals.map((meal) => meal.type).toSet().toList(),
              selectedMemberIds: widget.draft?.selectedMemberIds ?? const [],
              cuisinePreferences: widget.draft?.cuisinePreferences ?? const [],
              prioritizePantry: widget.draft?.prioritizePantry ?? true,
              status: meals.isEmpty ? 'draft' : 'saved'),
          meals.map((m) => m.toCore()).toList(),
          allowEmptyDraft: widget.draft?.isManual == true);
      if (repo.sessionVersion != _session || !mounted) {
        throw StateError('Workspace changed.');
      }
      setState(() {
        _planPath = '$root/mealPlans/$id';
        _allMeals = meals;
        _numberOfDays = days;
      });
      return _planPath!;
    } finally {
      _saving = null;
    }
  }

  void _onPersistedPlanChanged() {
    if (!mounted) return;
    final repo = _repo;
    if (repo.sessionVersion != _session) {
      setState(() {
        _allMeals = [];
        _familyMembers = [];
        _saveTitleController.clear();
        _planPath = null;
      });
      return;
    }
    if (_planPath == null) return;
    final plan = repo.value.where((p) => p.sourcePath == _planPath).firstOrNull;
    if (_saving == null) {
      setState(() => _allMeals = List.of(plan?.activeMeals ?? const []));
    }
  }

  void _showUnsavedMeal(GeneratedMeal meal) {
    final repo = _repo;
    if (repo.sessionVersion != _session) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => ListenableBuilder(
        listenable: repo,
        builder: (context, _) => repo.sessionVersion != _session
            ? const Padding(
                padding: EdgeInsets.all(24),
                child:
                    Text('Your account or household changed. Reopen the plan.'))
            : UnsavedMealPreview(
                meal: meal,
                onSave: () {
                  Navigator.pop(sheetContext);
                  if (mounted && repo.sessionVersion == _session) {
                    _showSavePlanDialog();
                  }
                }),
      ),
    );
  }

  Future<void> _setStatus(GeneratedMeal meal, MealStatus status) async {
    if (_mutating) return;
    if (_planPath == null) {
      _showUnsavedMeal(meal);
      return;
    }
    if (status == MealStatus.completed) {
      final problem = mealCookingProblem(meal, PantryRepository.instance,
          expectedScope: _repo.workspacePath);
      if (problem != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(problem)));
        return;
      }
    }
    _mutating = true;
    try {
      final path = await _ensurePersisted();
      await _repo.updateMealStatus(meal.id, status, planPath: path);
      if (!mounted || !context.mounted || _repo.sessionVersion != _session) {
        return;
      }
      setState(() {
        _allMeals = _allMeals
            .map((m) => m.id == meal.id ? m.copyWith(status: status) : m)
            .toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Meal marked ${status.name}. Grocery requirements update from accepted meals.')));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Meal could not be updated. Check the plan and connection, then retry.')));
      }
    } finally {
      _mutating = false;
    }
  }

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
    _planPath = draft?.planPath;
    _session = draft?.sourceSessionVersion ?? _repo.sessionVersion;
    final currentSession = _session == _repo.sessionVersion;
    if (!currentSession) _planPath = null;
    _repo.addListener(_onPersistedPlanChanged);
    _allMeals = currentSession
        ? List<GeneratedMeal>.from(draft?.meals ?? const [])
        : [];
    _numberOfDays = draft?.numberOfDays ?? 7;
    if (_numberOfDays < 1) _numberOfDays = 1;
    _familyMembers = (currentSession
            ? draft?.familyMembers ?? const <String>[]
            : const <String>[])
        .map((id) =>
            FamilyMemberRepository.instance.members
                .where((member) => member.id == id)
                .firstOrNull
                ?.displayName ??
            id)
        .toList();
    _startDate = draft?.startDate ?? WeekCalendar.mondayOf(DateTime.now());
    // New plans open at their chosen start, never at the device's current day.
    _selectedDayIndex = draft?.initialDayIndex ??
        (draft?.meals.isNotEmpty == true
            ? draft!.meals
                .map((meal) => meal.dayIndex)
                .reduce((a, b) => a < b ? a : b)
            : 0);
    _saveTitleController = TextEditingController(
      text: currentSession ? draft?.title ?? 'My Family Meal Plan' : '',
    );
  }

  @override
  void dispose() {
    _repo.removeListener(_onPersistedPlanChanged);
    _saveTitleController.dispose();
    super.dispose();
  }

  // ── Save plan success modal ──────────────────────────────────────────────────

  /// [autoNavigate] = true when called right after a fresh save;
  /// the dialog will auto-redirect to the calendar after 3 s and hide the
  /// "Continue Editing" escape hatch so the user cannot re-trigger save.
  void _showSaveSuccessDialog(String title, {bool autoNavigate = false}) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: !autoNavigate,
      builder: (ctx) => _SaveSuccessDialogContent(
        title: title,
        familyMembers: _familyMembers,
        autoNavigate: autoNavigate,
        onViewCalendar: () {
          Navigator.pop(ctx);
          context.go(mealCalendarRoute(DateTime(
              _startDate.year,
              _startDate.month,
              _startDate.day + _selectedDayIndex.clamp(0, _numberOfDays - 1))));
        },
        onViewAllPlans: () {
          Navigator.pop(ctx);
          context.push('/saved-meal-plans');
        },
        onRename: autoNavigate
            ? null
            : () {
                Navigator.pop(ctx);
                _showSavePlanDialog();
              },
        onContinueEditing: autoNavigate ? null : () => Navigator.pop(ctx),
      ),
    );
  }

  // ── Save plan dialog ────────────────────────────────────────────────────────

  void _showSavePlanDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
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
                  onPressed: _saveDialogBusy ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel',
                      style: TextStyle(color: AppColors.textSecondary)),
                ),
                ElevatedButton(
                  onPressed: _saveDialogBusy
                      ? null
                      : () async {
                          if (_saveDialogBusy) return;
                          final meals = _mealsForSave;
                          if (meals.isEmpty && widget.draft?.isManual != true) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'Add at least one meal before saving.'),
                              ),
                            );
                            return;
                          }
                          final unnamedMeals = meals
                              .where((meal) => meal.title.trim().isEmpty)
                              .toList();
                          if (unnamedMeals.isNotEmpty) {
                            final missingLabels = unnamedMeals
                                .take(3)
                                .map((meal) =>
                                    '${_dayShortLabel(meal.dayIndex)} ${meal.type}')
                                .join(', ');
                            final remaining = unnamedMeals.length - 3;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Add a name for: $missingLabels'
                                  '${remaining > 0 ? ' and $remaining more' : ''}.',
                                ),
                              ),
                            );
                            return;
                          }
                          setDialogState(() => _saveDialogBusy = true);
                          final title = _saveTitleController.text.trim().isEmpty
                              ? 'Family Meal Plan'
                              : _saveTitleController.text.trim();
                          try {
                            final existingPath = _planPath;
                            final path = await _ensurePersisted();
                            if (existingPath != null) {
                              final savedTitle = _repo.value
                                  .where(
                                      (plan) => plan.sourcePath == existingPath)
                                  .firstOrNull
                                  ?.title;
                              if (savedTitle != title) {
                                await _repo.renamePlan(path, title);
                              }
                            }
                            if (_repo.sessionVersion != _session) {
                              return;
                            }
                            if (!ctx.mounted) return;
                            Navigator.pop(ctx);

                            if (mounted) {
                              setState(() {});
                              _showSaveSuccessDialog(title, autoNavigate: true);
                            }
                          } catch (e) {
                            if (!mounted) return;
                            final message = e is StateError
                                ? switch (e.message) {
                                    'Complete the meal names before saving.' =>
                                      'Add a name for every meal before saving.',
                                    'Your role cannot save meals.' =>
                                      'Your household role does not have permission to save meal plans.',
                                    'Account or household changed.' ||
                                    'Account or household changed. Reopen the plan.' =>
                                      'Your account or household changed. Reopen the plan and retry.',
                                    _ => GenerationFailure.from(e).toString(),
                                  }
                                : _saveFailureMessage(e);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(message),
                                backgroundColor: Colors.red,
                              ),
                            );
                          } finally {
                            if (dialogCtx.mounted) {
                              setDialogState(() => _saveDialogBusy = false);
                            }
                            _saveDialogBusy = false;
                          }
                        },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary),
                  child: _saveDialogBusy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Save Plan',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _saveFailureMessage(Object error) {
    if (error is FirebaseException) {
      final message = switch (error.code) {
        'permission-denied' =>
          'Firebase denied saving this plan. Check the deployed Firestore '
              'rules and App Check configuration for this project.',
        'unauthenticated' ||
        'user-token-expired' =>
          'Your Firebase sign-in expired. Sign in again, then retry saving.',
        'unavailable' ||
        'deadline-exceeded' =>
          'Firebase could not save this plan because the service or network '
              'is unavailable. Your plan is still open; retry when connected.',
        _ =>
          'Firebase could not save this plan. Your plan is still open; retry '
              'after checking your Firebase configuration.',
      };
      final plugin = error.plugin.replaceAll(RegExp(r'[^a-zA-Z0-9_.-]'), '');
      final code = error.code.replaceAll(RegExp(r'[^a-zA-Z0-9_.-]'), '');
      return '$message (Firebase: $plugin/$code)';
    }
    return GenerationFailure.from(error).toString();
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
              onPressed: () async {
                final updatedTitle = titleCtrl.text.trim();
                if (updatedTitle.isEmpty) return;

                final rawIngredients = ingredientsCtrl.text
                    .split(',')
                    .map((s) => s.trim())
                    .where((s) => s.isNotEmpty)
                    .toList();

                final updated = meal.copyWith(
                    title: updatedTitle,
                    type: selectedType,
                    prepTime: prepTimeCtrl.text.trim(),
                    calories: caloriesCtrl.text.trim(),
                    badgeText: badgeCtrl.text.trim(),
                    ingredients: rawIngredients);
                try {
                  if (_planPath != null) {
                    await _repo.editMeal(await _ensurePersisted(), updated);
                  }
                  if (!mounted ||
                      !ctx.mounted ||
                      _repo.sessionVersion != _session) {
                    return;
                  }
                  setState(() {
                    _allMeals = _allMeals
                        .map((m) => m.id == meal.id ? updated : m)
                        .toList();
                  });
                } catch (_) {
                  if (mounted && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content:
                            Text('Meal edit was not saved. Please retry.')));
                  }
                  return;
                }
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
    final dayIndex = _selectedDayIndex;
    showDialog(
      context: context,
      builder: (ctx) => AddMealDialog(
        dayIndex: dayIndex,
        dayLabel: _dayLabel(dayIndex),
        onAdd: (newMeal) async {
          final repo = _repo;
          if (!mounted || repo.sessionVersion != _session) {
            throw StateError('Account or household changed.');
          }
          if (_planPath != null) {
            await repo.editMeal(await _ensurePersisted(), newMeal);
          }
          if (!mounted || !ctx.mounted || repo.sessionVersion != _session) {
            throw StateError('Account or household changed.');
          }
          setState(() {
            if (!_allMeals.any((meal) => meal.id == newMeal.id)) {
              _allMeals.add(newMeal);
            }
            if (_numberOfDays < newMeal.dayIndex + 1) {
              _numberOfDays = newMeal.dayIndex + 1;
            }
          });
        },
      ),
    );
  }

  // ── Smart grocery export ────────────────────────────────────────────────────

  Future<void> _generateGroceryList() async {
    if (_planPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Save the meal plan first before exporting to grocery list.')));
      return;
    }
    try {
      await _ensurePersisted();
      if (mounted) context.go('/grocery');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Save a complete plan and accept meals before opening their grocery requirements.')));
      }
    }
  }

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
    if (confirmed != true || !mounted || !context.mounted) return;

    BuildContext? loadingContext;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        loadingContext = ctx;
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
        );
      },
    );

    try {
      final pantryContext = pantryPromptContext(
          PantryRepository.instance.items.values.expand((items) => items),
          now: DateTime.now());
      final selectedIds = widget.draft?.selectedMemberIds ?? const <String>[];
      final participants = FamilyMemberRepository.instance.members
          .where((m) => selectedIds.contains(m.id))
          .toList();
      if (participants.isEmpty ||
          participants.length != selectedIds.toSet().length) {
        throw StateError(
            'Plan participants are unavailable. Reopen or recreate the plan with current profiles.');
      }

      final result = await context.read<LlmService>().replaceMeal(
            uid: uid,
            currentMeal: current.toCore(),
            cuisinePreferences: widget.draft?.cuisinePreferences ?? const [],
            preferences:
                participants.expand((m) => m.preferences).toSet().toList(),
            pantryItems: pantryContext,
            restrictions: participants
                .expand((member) => member.restrictions)
                .toSet()
                .toList(),
          );
      if (!mounted) return;
      if (loadingContext?.mounted == true) Navigator.of(loadingContext!).pop();
      loadingContext = null;
      var replacement = GeneratedMeal.fromCore(
        result.data,
        fallbackIndex: index,
      ).copyWith(
        type: current.type,
        dayIndex: current.dayIndex,
        status: MealStatus.pending,
        badgeText: 'AI Replacement',
        replacedMealId: current.id,
      );
      if (_planPath != null) {
        replacement = await _repo.replaceMeal(current.id, replacement,
            planPath: _planPath!);
      }
      if (!mounted || !context.mounted || _repo.sessionVersion != _session) {
        return;
      }
      setState(() {
        final allIndex = _allMeals.indexWhere((m) => m.id == current.id);
        if (allIndex >= 0) {
          _allMeals[allIndex] = replacement;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        AiGenerationSnackBar(
          result: result,
          successMessage:
              '${current.title} replaced with "${replacement.title}". Status is now Pending.',
        ),
      );
    } catch (e) {
      if (!mounted) return;
      if (loadingContext?.mounted == true) Navigator.of(loadingContext!).pop();
      loadingContext = null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(GenerationFailure.from(e).toString()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return UnsavedPlanGuard(
      hasUnsavedPlan: _planPath == null &&
          _allMeals.isNotEmpty &&
          _session == _repo.sessionVersion,
      onSave: _showSavePlanDialog,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
            onPressed: () => Navigator.of(context).maybePop(),
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
              icon: Icon(
                _planPath != null ? Icons.bookmark : Icons.bookmark_border,
                color: AppColors.primary,
              ),
              tooltip: _planPath != null ? 'Plan Saved' : 'Save Plan',
              onPressed: () {
                if (_planPath != null) {
                  _showSaveSuccessDialog(
                    _saveTitleController.text.trim().isEmpty
                        ? 'Family Meal Plan'
                        : _saveTitleController.text.trim(),
                    autoNavigate: false,
                  );
                } else {
                  _showSavePlanDialog();
                }
              },
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (_session != _repo.sessionVersion)
              const Text(
                  'Account or household changed. Reopen the plan from the current account.'),
            if (_planPath == null &&
                widget.draft?.initialSaveFailed == true &&
                _session == _repo.sessionVersion)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text(
                  'Generated meals are not saved. Keep this editor open and use Save Plan to retry saving without another AI request.',
                  key: ValueKey('generated-plan-not-saved'),
                  style: TextStyle(color: AppColors.warning),
                ),
              ),
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
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.border,
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
              GeneratedMealCard(
                onOpen: () async {
                  final target = _dayMeals[i];
                  if (_planPath == null) {
                    _showUnsavedMeal(target);
                    return;
                  }
                  try {
                    final path = await _ensurePersisted();
                    if (!mounted ||
                        !context.mounted ||
                        _session != _repo.sessionVersion) {
                      return;
                    }
                    context.push(mealRoute(target.id, path));
                  } catch (_) {
                    if (mounted && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text(
                              'Save the plan before opening this meal. Please retry.')));
                    }
                  }
                },
                isSaved: _planPath != null,
                onCook: () => _showUnsavedMeal(_dayMeals[i]),
                meal: _dayMeals[i],
                dayIndex: _selectedDayIndex,
                onReplace: () => _replaceMealWithAi(i),
                onEdit: () => _showEditMealDialog(_dayMeals[i]),
                onDelete: () async {
                  final target = _dayMeals[i];
                  final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                              title: const Text('Remove meal?'),
                              content: Text(
                                  'Remove ${target.title} and its grocery contribution?'),
                              actions: [
                                TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('Cancel')),
                                TextButton(
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('Remove'))
                              ]));
                  if (confirmed != true || !mounted || !context.mounted) return;
                  try {
                    if (_planPath != null) {
                      await _repo.deleteMeal(
                          await _ensurePersisted(), target.id);
                    }
                    if (!mounted || _repo.sessionVersion != _session) {
                      return;
                    }
                    setState(
                        () => _allMeals.removeWhere((m) => m.id == target.id));
                  } catch (_) {
                    if (mounted && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Meal could not be removed. Retry.')));
                    }
                  }
                },
                onAccept: () => _setStatus(_dayMeals[i], MealStatus.accepted),
                onComplete: () =>
                    _setStatus(_dayMeals[i], MealStatus.completed),
                onNotCompleted: () =>
                    _setStatus(_dayMeals[i], MealStatus.notCompleted),
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
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
            ),

            if (_dayMeals.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'No meals for this day. Tap "Add Dish" above to create one.',
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 13),
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
                      side: const BorderSide(
                          color: AppColors.primary, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.shopping_cart_outlined, size: 18),
                    label: const Text('Export Grocery',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _planPath != null
                      ? ElevatedButton.icon(
                          onPressed: () => _showSaveSuccessDialog(
                            _saveTitleController.text.trim().isEmpty
                                ? 'Family Meal Plan'
                                : _saveTitleController.text.trim(),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          icon:
                              const Icon(Icons.check_circle_outline, size: 18),
                          label: const Text('Plan Saved',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 13)),
                        )
                      : ElevatedButton.icon(
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
                              style: TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 13)),
                        ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ── Meal card widget ──────────────────────────────────────────────────────────

class GeneratedMealCard extends StatefulWidget {
  const GeneratedMealCard({
    super.key,
    required this.onOpen,
    required this.meal,
    required this.dayIndex,
    required this.onReplace,
    required this.onAccept,
    this.onComplete,
    this.onNotCompleted,
    this.onEdit,
    this.onDelete,
    this.isSaved = true,
    this.onCook,
  });

  final VoidCallback onOpen;
  final bool isSaved;
  final VoidCallback? onCook;
  final GeneratedMeal meal;
  final int dayIndex;
  final VoidCallback onReplace;
  final VoidCallback onAccept;
  final VoidCallback? onComplete;
  final VoidCallback? onNotCompleted;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  State<GeneratedMealCard> createState() => _MealCardState();
}

class _MealCardState extends State<GeneratedMealCard> {
  bool _expanded = false;
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
              onTap: widget.onOpen,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                  child: MealNetworkImage(
                      url: widget.meal.imageUrl,
                      mealTitle: widget.meal.title,
                      height: 160,
                      width: double.infinity))),

          InkWell(
            onTap: widget.onOpen,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
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
                          MealStatusBadge(
                            status: widget.meal.status,
                            compact: true,
                          ),
                        ],
                      ),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
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
                  Expanded(
                    child: Text(
                      _expanded ? 'Hide ingredients' : 'Show ingredients',
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 12),
                    ),
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
                child: MealIngredientsPanel(meal: widget.meal)),
          ],

          const Divider(
              height: 1, indent: 12, endIndent: 12, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 8,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
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
                if (!widget.isSaved)
                  FilledButton.icon(
                      onPressed: widget.onCook,
                      icon: const Icon(Icons.restaurant, size: 16),
                      label: const Text('Cook'))
                else if (widget.meal.isCompleted)
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
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
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
}

class _SaveSuccessDialogContent extends StatefulWidget {
  const _SaveSuccessDialogContent({
    required this.title,
    required this.familyMembers,
    required this.autoNavigate,
    required this.onViewCalendar,
    required this.onViewAllPlans,
    this.onRename,
    this.onContinueEditing,
  });

  final String title;
  final List<String> familyMembers;
  final bool autoNavigate;
  final VoidCallback onViewCalendar;
  final VoidCallback onViewAllPlans;
  final VoidCallback? onRename;
  final VoidCallback? onContinueEditing;

  @override
  State<_SaveSuccessDialogContent> createState() =>
      _SaveSuccessDialogContentState();
}

class _SaveSuccessDialogContentState extends State<_SaveSuccessDialogContent>
    with SingleTickerProviderStateMixin {
  static const _countdownSeconds = 3;
  int _remaining = _countdownSeconds;
  Timer? _timer;
  late final AnimationController _scaleCtrl;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _scaleAnim = CurvedAnimation(parent: _scaleCtrl, curve: Curves.elasticOut);
    _scaleCtrl.forward();

    if (widget.autoNavigate) {
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) {
          t.cancel();
          return;
        }
        setState(() => _remaining--);
        if (_remaining <= 0) {
          t.cancel();
          widget.onViewCalendar();
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scaleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Animated checkmark ────────────────────────────────────────────
          ScaleTransition(
            scale: _scaleAnim,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (widget.autoNavigate)
                  SizedBox(
                    width: 72,
                    height: 72,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(
                        begin: 1.0,
                        end: (_countdownSeconds - _remaining) /
                            _countdownSeconds,
                      ),
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.linear,
                      builder: (ctx, value, _) => CircularProgressIndicator(
                        value: value,
                        strokeWidth: 3,
                        backgroundColor:
                            AppColors.primary.withValues(alpha: 0.12),
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                Container(
                  width: 60,
                  height: 60,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.primary,
                    size: 38,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // ── Title ─────────────────────────────────────────────────────────
          const Text(
            'Meal Plan Saved! 🎉',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),

          // ── Plan name row ─────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  '"${widget.title}"',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
              if (widget.onRename != null)
                IconButton(
                  icon: const Icon(Icons.edit_outlined,
                      size: 16, color: AppColors.textMuted),
                  tooltip: 'Rename plan',
                  padding: const EdgeInsets.only(left: 4),
                  constraints: const BoxConstraints(),
                  onPressed: widget.onRename,
                ),
            ],
          ),

          if (widget.familyMembers.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 2),
              child: Text(
                'For: ${widget.familyMembers.join(', ')}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          const SizedBox(height: 6),
          const Text(
            'Your plan is synced and visible on your household meal calendar.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),

          // ── Auto-nav countdown hint ───────────────────────────────────────
          if (widget.autoNavigate) ...[
            const SizedBox(height: 10),
            Text(
              'Redirecting to calendar in $_remaining s…',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textMuted.withValues(alpha: 0.8),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],

          const SizedBox(height: 22),

          // ── Primary CTA ───────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                _timer?.cancel();
                widget.onViewCalendar();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.calendar_month, size: 18),
              label: Text(
                widget.autoNavigate ? 'Go to Calendar Now' : 'View on Calendar',
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // ── Secondary CTA ─────────────────────────────────────────────────
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                _timer?.cancel();
                widget.onViewAllPlans();
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.bookmark_outline, size: 18),
              label: const Text(
                'View All Saved Plans',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ),

          // ── Continue editing (only when revisiting via bookmark) ──────────
          if (widget.onContinueEditing != null) ...[
            const SizedBox(height: 4),
            TextButton(
              onPressed: widget.onContinueEditing,
              child: const Text(
                'Continue Editing',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
