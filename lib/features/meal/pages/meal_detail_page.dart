import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/llm_service.dart';
import '../../../core/services/auth_service.dart';
import '../../meal_plan/data/meal_plan_repository.dart';
import '../models/meal.dart';

class MealDetailPage extends StatefulWidget {
  const MealDetailPage({super.key, required this.mealId, this.planId});

  final String mealId;
  final String? planId;

  @override
  State<MealDetailPage> createState() => _MealDetailPageState();
}

class _MealDetailPageState extends State<MealDetailPage> {
  Meal? _meal;
  bool _isLoading = false;
  bool _isReplacing = false;
  bool _isFavorite = false;
  bool _isAccepted = false;

  @override
  void initState() {
    super.initState();
    _loadMeal();
  }

  Future<void> _loadMeal() async {
    if (widget.planId != null) {
      setState(() => _isLoading = true);
      try {
        final meal = await context
            .read<MealPlanRepository>()
            .getMeal(widget.planId!, widget.mealId);
        if (meal != null && mounted) {
          setState(() {
            _meal = meal;
            _isFavorite = meal.isFavorite;
            _isAccepted = meal.accepted;
          });
        }
      } catch (e) {
        debugPrint('Error loading meal: $e');
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleFavorite() async {
    setState(() => _isFavorite = !_isFavorite);
    if (widget.planId != null) {
      await context
          .read<MealPlanRepository>()
          .toggleFavorite(widget.planId!, widget.mealId, _isFavorite);
    }
  }

  Future<void> _acceptMeal() async {
    setState(() => _isAccepted = true);
    if (widget.planId != null) {
      await context
          .read<MealPlanRepository>()
          .toggleAccepted(widget.planId!, widget.mealId, true);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Meal accepted for your weekly schedule!')),
      );
    }
  }

  Future<void> _replaceWithAi() async {
    final uid = context.read<AuthService>().uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in first.')),
      );
      return;
    }

    setState(() => _isReplacing = true);
    final llmService = context.read<LlmService>();
    final mealPlanRepo = context.read<MealPlanRepository>();

    try {
      final current = _meal ?? _sampleMeal;
      final result = await llmService.replaceMeal(
        uid: uid,
        currentMeal: current,
      );
      final replacement = result.data;
      if (widget.planId != null) {
        await mealPlanRepo.updateMeal(widget.planId!, widget.mealId, replacement);
      }
      if (mounted) {
        setState(() => _meal = replacement);
        if (result.usedFallback) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Using free built-in AI (your custom key had an issue).'),
              duration: Duration(seconds: 3),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Replaced with ${replacement.title}!')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('AI Replacement: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isReplacing = false);
    }
  }

  Meal get _sampleMeal => Meal(
        id: widget.mealId,
        title: 'Honey Garlic Pan Seared Salmon',
        subtitle: 'Mediterranean • 25m prep & cook',
        badgeText: 'Dinner Special',
        calories: '450 kcal',
        prepTime: '10 min',
        cookTime: '15 min',
        servings: '4 servings',
        protein: '38g',
        carbs: '12g',
        fats: '18g',
        imageUrl:
            'https://images.unsplash.com/photo-1467003909585-2f8a72700288?auto=format&fit=crop&w=800&q=80',
        ingredients: const [
          Ingredient(name: 'Salmon Fillets', amount: '4 pieces'),
          Ingredient(name: 'Garlic Cloves', amount: '4 minced'),
          Ingredient(name: 'Raw Honey', amount: '3 tbsp'),
          Ingredient(name: 'Low-Sodium Soy Sauce', amount: '2 tbsp'),
          Ingredient(name: 'Olive Oil', amount: '1 tbsp'),
        ],
      );

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final meal = _meal ?? _sampleMeal;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: AppColors.textPrimary, size: 28),
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
                icon: Icon(
                  _isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: _isFavorite ? AppColors.danger : AppColors.textPrimary,
                  size: 20,
                ),
                onPressed: _toggleFavorite,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              children: [
                // Hero Image Container with tag
                Container(
                  height: 220,
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    image: DecorationImage(
                      image: NetworkImage(
                        meal.imageUrl ??
                            'https://images.unsplash.com/photo-1467003909585-2f8a72700288?auto=format&fit=crop&w=800&q=80',
                      ),
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: Stack(
                    children: [
                      if (meal.badgeText != null)
                        Positioned(
                          left: 16,
                          bottom: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              meal.badgeText!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Title and basic metadata
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        meal.title,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        meal.subtitle ?? 'Delicious home-cooked meal',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Four-column specs row
                      Row(
                        children: [
                          Expanded(child: _buildSpecCard('Prep Time', meal.prepTime ?? '10m')),
                          const SizedBox(width: 8),
                          Expanded(child: _buildSpecCard('Cook Time', meal.cookTime ?? '15m')),
                          const SizedBox(width: 8),
                          Expanded(child: _buildSpecCard('Servings', meal.servings ?? '4')),
                          const SizedBox(width: 8),
                          Expanded(child: _buildSpecCard('Calories', meal.calories ?? '450')),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Macronutrients
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.cardSurface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Macronutrients per serving',
                              style: TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildMacroChip('Protein: ${meal.protein ?? "35g"}', AppColors.primaryLight, AppColors.primary),
                                _buildMacroChip('Carbs: ${meal.carbs ?? "15g"}', AppColors.infoLight, AppColors.info),
                                _buildMacroChip('Fats: ${meal.fats ?? "18g"}', AppColors.warningLight, AppColors.warning),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Ingredients List
                      const Text(
                        'Ingredients',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.cardSurface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          children: [
                            for (var i = 0; i < meal.ingredients.length; i++) ...[
                              _buildIngredientRow(meal.ingredients[i].name, meal.ingredients[i].amount),
                              if (i != meal.ingredients.length - 1)
                                const Divider(height: 1, indent: 16, endIndent: 16, color: AppColors.border),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Bottom Action Buttons
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppColors.cardSurface,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isReplacing ? null : _replaceWithAi,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: _isReplacing
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.auto_awesome, size: 18),
                    label: const Text('Replace with AI', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _acceptMeal,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isAccepted ? AppColors.textMuted : AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: Icon(_isAccepted ? Icons.check_circle : Icons.check, size: 18),
                    label: Text(_isAccepted ? 'Accepted' : 'Accept Meal', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecCard(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroChip(String label, Color bg, Color text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: text,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildIngredientRow(String name, String amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            name,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          Text(
            amount,
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
