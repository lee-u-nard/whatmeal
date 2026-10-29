import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../meal/models/meal.dart';
import '../models/saved_meal_plan.dart';

class AddMealDialog extends StatefulWidget {
  const AddMealDialog(
      {super.key,
      required this.dayIndex,
      required this.dayLabel,
      required this.onAdd});
  final int dayIndex;
  final String dayLabel;
  final Future<void> Function(GeneratedMeal) onAdd;

  @override
  State<AddMealDialog> createState() => _AddMealDialogState();
}

class _AddMealDialogState extends State<AddMealDialog> {
  final titleCtrl = TextEditingController();
  final prepTimeCtrl = TextEditingController(text: '20m');
  final caloriesCtrl = TextEditingController(text: '400 kcal');
  final ingredientsCtrl = TextEditingController();
  String selectedType = 'Lunch';
  bool _submitting = false;
  // One identity per dialog, including a retry after an ambiguous write failure.
  late final String _mealId =
      'custom_added_${widget.dayIndex}_${DateTime.now().microsecondsSinceEpoch}';

  @override
  void dispose() {
    titleCtrl.dispose();
    prepTimeCtrl.dispose();
    caloriesCtrl.dispose();
    ingredientsCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting || titleCtrl.text.trim().isEmpty) return;
    setState(() => _submitting = true);
    final meal = GeneratedMeal(
      id: _mealId,
      title: titleCtrl.text.trim(),
      type: selectedType,
      dayIndex: widget.dayIndex,
      prepTime: prepTimeCtrl.text.trim(),
      calories: caloriesCtrl.text.trim(),
      badgeText: 'Home Cooked',
      imageUrl: '',
      ingredients: ingredientsCtrl.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList(),
      macros: const {},
      status: MealStatus.accepted,
    );
    try {
      await widget.onAdd(meal);
    } catch (_) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Meal was not added. Please retry.')));
      }
      return;
    }
    if (!mounted) return;
    // Re-enable pop before closing the dialog's PopScope.
    setState(() => _submitting = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) => PopScope<Object?>(
        canPop: !_submitting,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('Add Dish to ${widget.dayLabel}',
              style: const TextStyle(fontWeight: FontWeight.w800)),
          content: AbsorbPointer(
              absorbing: _submitting,
              child: SingleChildScrollView(
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
                      items: [
                        'Breakfast',
                        'Lunch',
                        'Dinner',
                        'Snack',
                        'Dessert'
                      ]
                          .map(
                              (t) => DropdownMenuItem(value: t, child: Text(t)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => selectedType = val);
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
              )),
          actions: [
            TextButton(
                onPressed: _submitting ? null : () => Navigator.pop(context),
                child: const Text('Cancel',
                    style: TextStyle(color: AppColors.textSecondary))),
            ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Add Dish',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
}
