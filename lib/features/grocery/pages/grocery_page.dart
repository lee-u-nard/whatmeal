import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../models/grocery_item.dart';

class GroceryPage extends StatefulWidget {
  const GroceryPage({super.key});

  @override
  State<GroceryPage> createState() => _GroceryPageState();
}

class _GroceryPageState extends State<GroceryPage> {
  final _sections = <String, List<GroceryItem>>{
    'PRODUCE AISLE': [
      GroceryItem(name: 'Asparagus bundle', quantity: '1 unit'),
      GroceryItem(name: 'Lemons', quantity: '3 units'),
      GroceryItem(name: 'Avocados', quantity: '2 units', checked: true, tag: 'In Pantry'),
    ],
    'MEAT & SEAFOOD': [
      GroceryItem(name: 'Fresh Atlantic Salmon', quantity: '500g'),
      GroceryItem(name: 'Chicken Breast', quantity: '1.2 kg'),
    ],
    'PANTRY STAPLES': [
      GroceryItem(name: 'Organic Honey', quantity: '1 jar'),
      GroceryItem(name: 'Almond Flour', quantity: '400g'),
    ],
  };

  int get _remainingCount =>
      _sections.values.expand((items) => items).where((i) => !i.checked).length;

  void _clearChecked() {
    setState(() {
      for (final items in _sections.values) {
        items.removeWhere((i) => i.checked);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Subheader row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$_remainingCount remaining items',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            Row(
              children: [
                TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Grocery list copied to clipboard!')),
                    );
                  },
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
                  onPressed: _clearChecked,
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

        for (final entry in _sections.entries) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 8, left: 4),
            child: Text(
              entry.key,
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
                    onChanged: (checked) => setState(() => entry.value[i].checked = checked),
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