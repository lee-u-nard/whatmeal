/*import 'package:flutter/material.dart';

class MealPlanPage extends StatelessWidget {
  const MealPlanPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Meal Plan'));
  }
}
*/

// lib/features/meal_plan/pages/meal_plan_page.dart
import 'package:flutter/material.dart';

class MealPlanPage extends StatefulWidget {
  const MealPlanPage({super.key});

  @override
  State<MealPlanPage> createState() => _MealPlanPageState();
}

class _MealPlanPageState extends State<MealPlanPage> {
  // placeholder until family data comes from a real feature
  final _familyMembers = ['Mom', 'Dad', 'Emma', 'Liam'];
  final _selectedFamily = <String>{};

  int _selectedDays = 3;

  final _mealTypes = ['Breakfast', 'Lunch', 'Dinner'];
  final _selectedMealTypes = <String>{'Breakfast', 'Lunch', 'Dinner'};

  bool _prioritizePantry = false;

  final _cuisines = [
    'Italian', 'Asian', 'Mexican', 'Mediterranean', 'American', 'Indian',
  ];
  final _selectedCuisines = <String>{};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Plan Meals For', style: theme.textTheme.titleMedium),
          ..._familyMembers.map(
            (name) => CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(name),
              value: _selectedFamily.contains(name),
              onChanged: (checked) => setState(() {
                checked == true
                    ? _selectedFamily.add(name)
                    : _selectedFamily.remove(name);
              }),
            ),
          ),

          const SizedBox(height: 16),
          Text('Number of Days', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 1, label: Text('1 Days')),
              ButtonSegment(value: 3, label: Text('3 Days')),
              ButtonSegment(value: 5, label: Text('5 Days')),
              ButtonSegment(value: 7, label: Text('7 Days')),
            ],
            selected: {_selectedDays},
            onSelectionChanged: (s) => setState(() => _selectedDays = s.first),
          ),

          const SizedBox(height: 16),
          Text('Include Meal Types', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _mealTypes.map((type) {
              final selected = _selectedMealTypes.contains(type);
              return _GradientToggleChip(
                label: type,
                selected: selected,
                onTap: () => setState(() {
                  selected
                      ? _selectedMealTypes.remove(type)
                      : _selectedMealTypes.add(type);
                }),
              );
            }).toList(),
          ),

          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Prioritize Pantry'),
            subtitle: const Text('Use ingredients soon first'),
            value: _prioritizePantry,
            onChanged: (v) => setState(() => _prioritizePantry = v),
          ),

          const SizedBox(height: 16),
          Text('Cuisine Preferences', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _cuisines.map((cuisine) {
              final selected = _selectedCuisines.contains(cuisine);
              return FilterChip(
                label: Text(cuisine),
                selected: selected,
                onSelected: (v) => setState(() {
                  v ? _selectedCuisines.add(cuisine) : _selectedCuisines.remove(cuisine);
                }),
              );
            }).toList(),
          ),

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                // TODO: send _selectedFamily, _selectedDays, _selectedMealTypes,
                // _prioritizePantry, _selectedCuisines to the generation call
              },
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Generate AI Meal Plan'),
            ),
          ),
        ],
      ),
    );
  }
}


class _GradientToggleChip extends StatelessWidget {
  const _GradientToggleChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(colors: [Color(0xFF43A047), Color(0xFF66BB6A)])
              : null,
          color: selected ? null : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
