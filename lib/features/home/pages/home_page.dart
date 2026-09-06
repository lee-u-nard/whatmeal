import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_shell.dart';

/// Add AppShell later when sharing a widgets
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  static final _meals = List.generate(
    5,
    (i) => {
      'id': '$i',
      'name': 'Meal ${i + 1}',
      'calories': '${350 + i * 50} kcal',
    },
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    // generate meal plan
                  },
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Generate Plan'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.go('/pantry'),
                  icon: const Icon(Icons.kitchen),
                  label: const Text('View Pantry'),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _meals.length,
            itemBuilder: (context, index) {
              final meal = _meals[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.restaurant)),
                  title: Text(meal['name']!),
                  subtitle: Text(meal['calories']!),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/meal/${meal['id']}'),
                ),
              );
            },
          ),
        ),
      ],
    );
    /*
    return AppShell(
      title: 'WhatMeal',
      body: Center(child: Text('Welcome to WhatMeal')),
    );
    */
  }
}
