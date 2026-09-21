import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../data/grocery_repository.dart';
import '../models/grocery_item.dart';

class GroceryPage extends StatelessWidget {
  const GroceryPage({super.key});

  void _showAddItemDialog(BuildContext context) {
    final nameController = TextEditingController();
    final quantityController = TextEditingController();
    String category = 'Produce';
    const categories = ['Produce', 'Meat & Seafood', 'Dairy & Eggs', 'Pantry Staples', 'Frozen', 'Bakery', 'Other'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Add Grocery Item'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Item Name', hintText: 'e.g. Olive Oil'),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: quantityController,
                decoration: const InputDecoration(labelText: 'Quantity', hintText: 'e.g. 1 bottle, 500g'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setState(() => category = v!),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: () {
                final name = nameController.text.trim();
                final qty = quantityController.text.trim();
                if (name.isNotEmpty) {
                  context.read<GroceryRepository>().addItem(
                        GroceryItem(
                          name: name,
                          quantity: qty.isEmpty ? '1 unit' : qty,
                          category: category,
                        ),
                      );
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _shareList(BuildContext context, Map<String, List<GroceryItem>> sections) {
    final buffer = StringBuffer('🛒 WhatMeal Grocery List:\n\n');
    for (final entry in sections.entries) {
      buffer.writeln('${entry.key}:');
      for (final item in entry.value) {
        final check = item.checked ? '✅' : '⬜';
        buffer.writeln('  $check ${item.name} (${item.quantity})');
      }
      buffer.writeln();
    }
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Grocery list copied to clipboard!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GroceryRepository>(
      builder: (context, repo, _) {
        final sections = repo.sections;
        final totalItems = sections.values.expand((items) => items).toList();
        final remainingCount = totalItems.where((i) => !i.checked).length;

        return Scaffold(
          floatingActionButton: FloatingActionButton(
            backgroundColor: AppColors.primary,
            shape: const CircleBorder(),
            elevation: 4,
            onPressed: () => _showAddItemDialog(context),
            child: const Icon(Icons.add, color: Colors.white),
          ),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Subheader row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$remainingCount remaining items',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: totalItems.isEmpty ? null : () => _shareList(context, sections),
                        child: const Text(
                          'Share List',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: totalItems.any((i) => i.checked)
                            ? () => repo.clearChecked()
                            : null,
                        child: const Text(
                          'Clear Checked',
                          style: TextStyle(
                            color: AppColors.danger,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (sections.isEmpty)
                Container(
                  padding: const EdgeInsets.all(32),
                  margin: const EdgeInsets.only(top: 20),
                  decoration: BoxDecoration(
                    color: AppColors.cardSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.shopping_basket_outlined, size: 48, color: AppColors.textMuted),
                      const SizedBox(height: 12),
                      const Text(
                        'Your Grocery List is Empty',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Tap the + button to add items, or generate a meal plan to auto-populate your groceries!',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () => _showAddItemDialog(context),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Add First Item'),
                        style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                      ),
                    ],
                  ),
                )
              else
                for (final entry in sections.entries) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 8, left: 4),
                    child: Text(
                      entry.key.toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.cardSurface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        for (var i = 0; i < entry.value.length; i++) ...[
                          _GroceryItemTile(
                            item: entry.value[i],
                            onChanged: (checked) {
                              if (entry.value[i].id != null) {
                                repo.toggleChecked(entry.value[i].id!, checked);
                              }
                            },
                          ),
                          if (i != entry.value.length - 1)
                            const Divider(height: 1, indent: 16, endIndent: 16, color: AppColors.border),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
            ],
          ),
        );
      },
    );
  }
}

class _GroceryItemTile extends StatelessWidget {
  const _GroceryItemTile({required this.item, required this.onChanged});

  final GroceryItem item;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      value: item.checked,
      onChanged: (v) => onChanged(v ?? false),
      activeColor: AppColors.primary,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      controlAffinity: ListTileControlAffinity.leading,
      title: Row(
        children: [
          Flexible(
            child: Text(
              item.name,
              style: TextStyle(
                color: item.checked ? AppColors.textMuted : AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
                decoration: item.checked ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          if (item.checked && item.tag != null) ...[
            const SizedBox(width: 6),
            Text(
              '(${item.tag})',
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
      secondary: Text(
        item.quantity,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
    );
  }
}