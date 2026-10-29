import '../../../core/routing/meal_route.dart';
import 'dart:async';
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
import '../../../core/utils/week_calendar.dart';
import '../../auth/data/auth_repository.dart';
import '../../pantry/data/pantry_repository.dart';
import '../../profile/data/family_member_repository.dart';
import '../../meal_plan/models/saved_meal_plan.dart';
import '../../meal_plan/data/saved_plans_repository.dart';
import '../models/meal.dart';
import '../widgets/meal_status_badge.dart';
import '../widgets/meal_network_image.dart';
import '../widgets/meal_ingredients_panel.dart';

class MealDetailPage extends StatefulWidget {
  const MealDetailPage({
    super.key,
    required this.mealId,
    this.meal,
    this.planPath,
  });

  final String mealId;
  final String? planPath;

  /// The full meal object passed from the previous screen via router `extra`.
  /// When null the page tries to resolve the meal from SavedPlansRepository.
  final GeneratedMeal? meal;

  @override
  State<MealDetailPage> createState() => _MealDetailPageState();
}

class _MealDetailPageState extends State<MealDetailPage> {
  late String _currentMealId;
  late final int _openedSession;
  String? _planPath;
  bool get _sessionActive =>
      _openedSession == SavedPlansRepository.instance.sessionVersion;
  GeneratedMeal? _meal;
  bool _isFavorite = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _currentMealId = widget.mealId;
    _planPath = widget.planPath;
    _openedSession = SavedPlansRepository.instance.sessionVersion;
    SavedPlansRepository.instance.addListener(_onPlansChanged);
    _resolveMeal();
  }

  @override
  void dispose() {
    SavedPlansRepository.instance.removeListener(_onPlansChanged);
    super.dispose();
  }

  void _onPlansChanged() {
    if (!mounted) return;
    _resolveMeal();
  }

  // ── Resolve meal ─────────────────────────────────────────────────────────────

  void _resolveMeal() {
    final resolved = resolveSavedMeal(SavedPlansRepository.instance.value,
        mealId: _currentMealId,
        planPath: _planPath,
        openedSession: _openedSession,
        currentSession: SavedPlansRepository.instance.sessionVersion);
    final found = resolved?.meal;
    if (resolved != null) {
      _planPath = resolved.plan.sourcePath;
      _currentMealId = resolved.meal.id;
    }

    setState(() {
      _meal = found;
      _isFavorite = found?.isFavorite ?? false;
      _loading = false;
    });
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _openYouTube() {
    final q = _meal?.youtubeSearchQuery;
    if (q == null || q.isEmpty) return;
    final encoded = Uri.encodeComponent(q);
    _openUrl('https://www.youtube.com/results?search_query=$encoded');
  }

  // ── Meal status & replacement lifecycle ─────────────────────────────────────

  Future<void> _updateStatus(MealStatus newStatus) async {
    final meal = _meal;
    if (meal == null || !_sessionActive) return;

    if ((newStatus == MealStatus.accepted ||
            newStatus == MealStatus.completed ||
            newStatus == MealStatus.notCompleted) &&
        !FamilyPermissions.canAcceptMeal) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(FamilyPermissions.denialMessage('update meal status')),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    // Show confirmation for important status changes
    String? confirmMessage;
    switch (newStatus) {
      case MealStatus.accepted:
        confirmMessage = 'Are you sure you want to accept this meal?';
        break;
      case MealStatus.completed:
        confirmMessage =
            'Confirm you have checked the recipe quantities and cooked this meal.';
        break;
      case MealStatus.notCompleted:
        confirmMessage =
            'Are you sure you want to mark this meal as not completed?';
        break;
      default:
        break;
    }

    if (confirmMessage != null) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(_getStatusTitle(newStatus)),
          content: Text(confirmMessage!),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Confirm',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted || !_sessionActive) return;
    }

    if (newStatus == MealStatus.completed) {
      final problem = mealCookingProblem(meal, PantryRepository.instance,
          expectedScope: SavedPlansRepository.instance.workspacePath);
      if (problem != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(problem)));
        return;
      }
    }

    // No optimistic update - let Firestore listener update state after write
    try {
      await SavedPlansRepository.instance.updateMealStatus(meal.id, newStatus,
          planPath: _planPath, expectedSession: _openedSession);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('Meal status was not saved. Reopen the plan and retry.')));
      }
      return;
    }

    if (!mounted) return;
    String message = '';
    switch (newStatus) {
      case MealStatus.pending:
        message = '${meal.title} set to Pending decision.';
        break;
      case MealStatus.accepted:
        message = '${meal.title} accepted!';
        break;
      case MealStatus.completed:
        message = 'Great job! Marked ${meal.title} as completed.';
        break;
      case MealStatus.notCompleted:
        message = 'Marked ${meal.title} as not completed / skipped.';
        break;
      case MealStatus.replaced:
        message = '${meal.title} marked as replaced.';
        break;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: newStatus == MealStatus.completed
            ? const Color(0xFF00695C)
            : (newStatus == MealStatus.notCompleted
                ? AppColors.danger
                : AppColors.primary),
      ),
    );
  }

  String _getStatusTitle(MealStatus status) {
    switch (status) {
      case MealStatus.accepted:
        return 'Accept Meal';
      case MealStatus.completed:
        return 'Mark as Completed';
      case MealStatus.notCompleted:
        return 'Mark as Not Completed';
      case MealStatus.pending:
        return 'Set to Pending';
      case MealStatus.replaced:
        return 'Mark as Replaced';
    }
  }

  Future<void> _replaceWithAi() async {
    final session = SavedPlansRepository.instance.sessionVersion;
    final meal = _meal;
    if (meal == null || !_sessionActive) return;

    if (!FamilyPermissions.canReplaceMeal) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(FamilyPermissions.denialMessage('replace meals')),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final uid = AuthRepository.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to replace a meal with AI.')),
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
    if (confirmed != true || !mounted || !_sessionActive) return;

    if (!mounted) return;
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
                  'Asking AI for a replacement recipe…',
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
      final selectedIds = SavedPlansRepository.instance.value
              .where((p) => p.sourcePath == _planPath)
              .singleOrNull
              ?.familyMembers ??
          const <String>[];
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
            currentMeal: meal.toCore(),
            preferences:
                participants.expand((m) => m.preferences).toSet().toList(),
            cuisinePreferences: SavedPlansRepository.instance.value
                    .where((p) => p.sourcePath == _planPath)
                    .firstOrNull
                    ?.cuisinePreferences ??
                const [],
            pantryItems: pantryContext,
            restrictions: participants
                .expand((member) => member.restrictions)
                .toSet()
                .toList(),
          );

      if (!mounted) return;
      if (loadingContext?.mounted == true) Navigator.of(loadingContext!).pop();
      loadingContext = null;

      if (session != SavedPlansRepository.instance.sessionVersion) return;
      var replacement = GeneratedMeal.fromCore(
        result.data,
        fallbackIndex: meal.dayIndex,
      ).copyWith(
        status: MealStatus.pending,
        badgeText: 'AI Replacement',
        replacedMealId: meal.id,
      );

      replacement = await SavedPlansRepository.instance.replaceMeal(
          meal.id, replacement,
          planPath: _planPath, expectedSession: _openedSession);

      if (!mounted || !_sessionActive) return;
      _currentMealId = replacement.id;
      setState(() {
        _meal = replacement;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        AiGenerationSnackBar(
          result: result,
          successMessage:
              'Meal replaced with "${replacement.title}". Status is now Pending.',
        ),
      );
    } catch (e) {
      if (!mounted) return;
      if (loadingContext?.mounted == true) Navigator.of(loadingContext!).pop();
      loadingContext = null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(GenerationFailure.from(e).toString()),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left,
              color: AppColors.textPrimary, size: 28),
          tooltip: 'Back',
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Meal Details',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        actions: [
          if (_meal != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.cardSurface,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border),
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  tooltip: _isFavorite ? 'Remove favorite' : 'Add favorite',
                  icon: Icon(
                    _isFavorite ? Icons.favorite : Icons.favorite_border,
                    color:
                        _isFavorite ? AppColors.danger : AppColors.textPrimary,
                    size: 20,
                  ),
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final next = !_isFavorite;
                    final meal = _meal;
                    if (meal == null || !_sessionActive) return;
                    try {
                      await SavedPlansRepository.instance.toggleFavorite(
                          meal.id, next,
                          planPath: _planPath, expectedSession: _openedSession);
                    } catch (_) {
                      if (mounted && _sessionActive) {
                        messenger.showSnackBar(const SnackBar(
                            content:
                                Text('Favorite was not saved. Please retry.')));
                      }
                      return;
                    }
                    if (!mounted || !_sessionActive) return;
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(next
                            ? 'Saved to family favorites'
                            : 'Removed from favorites'),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : _meal == null
              ? _buildNotFound()
              : _buildContent(_meal!),
    );
  }

  // ── Not-found state ──────────────────────────────────────────────────────────

  Widget _buildNotFound() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.no_meals, size: 64, color: AppColors.textMuted),
            const SizedBox(height: 16),
            const Text(
              'Meal Not Found',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'This meal could not be found. It may have been removed or the plan was not loaded.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.textSecondary, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => context.pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.arrow_back, size: 16),
              label: const Text('Go Back',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Main content ─────────────────────────────────────────────────────────────

  Widget _buildContent(GeneratedMeal meal) {
    final protein = meal.macros['Protein'] ?? '';
    final carbs = meal.macros['Carbs'] ?? '';
    final fats = meal.macros['Fats'] ?? '';

    return Column(
      children: [
        Expanded(
          child: ListView(
            children: [
              // ── Hero image ─────────────────────────────────────────────────
              Container(
                height: 220,
                margin: const EdgeInsets.all(16),
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: AppColors.cardSurface,
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    MealNetworkImage(
                        url: meal.imageUrl,
                        mealTitle: meal.title,
                        fit: BoxFit.cover),

                    Positioned(
                      left: 16,
                      bottom: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          meal.type,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),

                    // Unsplash attribution overlay (only when using Unsplash)
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Status banner & Badge row ────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          meal.type.toUpperCase(),
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            letterSpacing: 0.8,
                          ),
                        ),
                        MealStatusBadge(status: meal.status),
                      ],
                    ),
                    const SizedBox(height: 8),

                    if (meal.isReplaced) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline,
                                size: 16, color: Colors.grey),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'This meal was replaced by a newer AI recipe.',
                                style: TextStyle(
                                    color: Colors.black54, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // ── Title & badge row ────────────────────────────────────
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            meal.title,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 22,
                            ),
                          ),
                        ),
                        if (meal.badgeText.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              meal.badgeText,
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Calories subtitle
                    if (meal.calories.isNotEmpty)
                      Text(
                        '${meal.calories} calories',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),

                    const SizedBox(height: 16),

                    // ── Quick specs row ─────────────────────────────────────
                    Row(
                      children: [
                        if (meal.prepTime.isNotEmpty)
                          Expanded(
                              child:
                                  _buildSpecCard('Prep Time', meal.prepTime)),
                        if (meal.prepTime.isNotEmpty) const SizedBox(width: 8),
                        if (meal.servings != null &&
                            meal.servings!.isNotEmpty) ...[
                          Expanded(
                              child:
                                  _buildSpecCard('Servings', meal.servings!)),
                          const SizedBox(width: 8),
                        ],
                        Expanded(child: _buildSpecCard('Type', meal.type)),
                        const SizedBox(width: 8),
                        Expanded(
                            child: _buildSpecCard(
                                'Day',
                                WeekCalendar
                                    .fullDays[meal.dayIndex.clamp(0, 6)])),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // ── Tags ─────────────────────────────────────────────────
                    if (meal.displayTags.isNotEmpty) ...[
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: meal.displayTags.map((tag) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              tag,
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ── Why recommended ──────────────────────────────────────
                    if (meal.reasoning != null &&
                        meal.reasoning!.trim().isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.infoLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: AppColors.info.withValues(alpha: 0.25)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.auto_awesome,
                                    size: 16, color: AppColors.info),
                                SizedBox(width: 6),
                                Text(
                                  'Why this meal',
                                  style: TextStyle(
                                    color: AppColors.info,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              meal.reasoning!,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // ── Macros ───────────────────────────────────────────────
                    if (protein.isNotEmpty ||
                        carbs.isNotEmpty ||
                        fats.isNotEmpty) ...[
                      const Text(
                        'Macro Breakdown',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (protein.isNotEmpty)
                            _buildMacroChip('$protein Protein',
                                AppColors.infoLight, AppColors.info),
                          if (protein.isNotEmpty) const SizedBox(width: 8),
                          if (carbs.isNotEmpty)
                            _buildMacroChip('$carbs Carbs',
                                AppColors.dangerLight, AppColors.danger),
                          if (carbs.isNotEmpty) const SizedBox(width: 8),
                          if (fats.isNotEmpty)
                            _buildMacroChip('$fats Fats',
                                AppColors.warningLight, AppColors.warning),
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],

                    // ── YouTube tutorial link ────────────────────────────────
                    if (meal.youtubeSearchQuery != null &&
                        meal.youtubeSearchQuery!.isNotEmpty) ...[
                      GestureDetector(
                        onTap: _openYouTube,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.red.withValues(alpha: 0.2)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.play_circle_filled,
                                  color: Colors.red, size: 24),
                              SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Watch Cooking Tutorial',
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      'Opens YouTube search for this recipe',
                                      style: TextStyle(
                                          color: AppColors.textMuted,
                                          fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.open_in_new,
                                  color: Colors.red, size: 16),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // ── Ingredients ──────────────────────────────────────────
                    const Text(
                      'Ingredients',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 10),

                    MealIngredientsPanel(meal: meal),

                    if (meal.instructions.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      const Text(
                        'Cooking Instructions',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.cardSurface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (var i = 0;
                                i < meal.instructions.length;
                                i++) ...[
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 24,
                                    height: 24,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryLight,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${i + 1}',
                                      style: const TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      meal.instructions[i],
                                      style: const TextStyle(
                                        color: AppColors.textPrimary,
                                        fontSize: 13,
                                        height: 1.45,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (i < meal.instructions.length - 1)
                                const SizedBox(height: 12),
                            ],
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ── Bottom action bar ───────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: const BoxDecoration(
            color: AppColors.cardSurface,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Primary lifecycle action row
                if (meal.isPending) ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _replaceWithAi,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(
                                color: AppColors.primary, width: 1.5),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Replace Meal',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 13)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: () => _updateStatus(MealStatus.accepted),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.check, size: 18),
                          label: const Text('Accept Meal',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 13)),
                        ),
                      ),
                    ],
                  ),
                ] else if (meal.isAccepted) ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              _updateStatus(MealStatus.notCompleted),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.danger,
                            side: const BorderSide(
                                color: AppColors.danger, width: 1.2),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.close, size: 18),
                          label: const Text('Not Completed',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 12)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: () => _updateStatus(MealStatus.completed),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2E7D32),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.task_alt, size: 18),
                          label: const Text('Mark Completed',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 13)),
                        ),
                      ),
                    ],
                  ),
                ] else if (meal.isCompleted) ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _updateStatus(MealStatus.accepted),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.border),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.undo, size: 16),
                          label: const Text('Undo / Mark Accepted',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 12)),
                        ),
                      ),
                    ],
                  ),
                ] else if (meal.isNotCompleted) ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _updateStatus(MealStatus.accepted),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('Re-accept',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 12)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _updateStatus(MealStatus.completed),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2E7D32),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.task_alt, size: 16),
                          label: const Text('Mark Done',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 12)),
                        ),
                      ),
                    ],
                  ),
                ],

                // Secondary actions row (Tutorial & Replacement options)
                if (!meal.isReplaced) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (meal.youtubeSearchQuery != null &&
                          meal.youtubeSearchQuery!.isNotEmpty) ...[
                        TextButton.icon(
                          onPressed: _openYouTube,
                          icon: const Icon(Icons.play_circle_fill,
                              size: 16, color: Colors.red),
                          label: const Text(
                            'Watch Tutorial',
                            style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.w700,
                                fontSize: 12),
                          ),
                        ),
                      ],
                      if (meal.isAccepted || meal.isNotCompleted) ...[
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: _replaceWithAi,
                          icon: const Icon(Icons.auto_awesome,
                              size: 16, color: AppColors.primary),
                          label: const Text(
                            'Replace with AI',
                            style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 12),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Helper widgets ───────────────────────────────────────────────────────────

  Widget _buildSpecCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroChip(String label, Color bg, Color text) {
    return Flexible(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
        child: Text(
          label,
          style:
              TextStyle(color: text, fontWeight: FontWeight.w700, fontSize: 12),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
