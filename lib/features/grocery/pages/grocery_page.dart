/*import 'package:flutter/material.dart';


class GroceryPage extends StatelessWidget {
  const GroceryPage({super.key});

  @override
  Widget build(BuildContext centext) {
    return const Center(child: Text('Grocery'));
  } 
}
*/

// lib/features/grocery/pages/grocery_page.dart
import 'package:flutter/material.dart';
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
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('$_remainingCount remaining items', style: Theme.of(context).textTheme.bodyMedium),
            Row(
              children: [
                TextButton(
                  onPressed: () {/* TODO: share list */},
                  style: TextButton.styleFrom(foregroundColor: Colors.green.shade700),
                  child: const Text('Share List'),
                ),
                TextButton(
                  onPressed: _clearChecked,
                  style: TextButton.styleFrom(foregroundColor: Colors.red.shade700),
                  child: const Text('Clear Checked'),
                ),
              ],
            ),
          ],
        ),
        for (final entry in _sections.entries) ...[
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 8, left: 4),
            child: Text(
              entry.key,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                for (var i = 0; i < entry.value.length; i++) ...[
                  _GroceryItemTile(
                    item: entry.value[i],
                    onChanged: (checked) => setState(() => entry.value[i].checked = checked),
                  ),
                  if (i != entry.value.length - 1)
                    const Divider(height: 1, indent: 16, endIndent: 16),
                ],
              ],
            ),
          ),
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
      activeColor: Colors.green.shade700,
      controlAffinity: ListTileControlAffinity.leading,
      title: Row(
        children: [
          Flexible(
            child: Text(
              item.name,
              style: item.checked
                  ? TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey.shade500)
                  : null,
            ),
          ),
          if (item.checked && item.tag != null) ...[
            const SizedBox(width: 6),
            Text('(${item.tag})',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontStyle: FontStyle.italic)),
          ],
        ],
      ),
      secondary: Text(item.quantity, style: TextStyle(color: Colors.grey.shade600)),
    );
  }
}