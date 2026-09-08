/* import 'package:flutter/material.dart';

class PantryPage extends StatelessWidget {
  const PantryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Pantry'));
  }
}
*/

// lib/features/pantry/pages/pantry_page.dart
import 'package:flutter/material.dart';
import '../data/pantry_repository.dart';
import '../models/pantry_item.dart';

class PantryPage extends StatelessWidget {
  const PantryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ValueListenableBuilder<Map<String, List<PantryItem>>>(
      valueListenable: PantryRepository.instance,
      builder: (context, categories, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: SearchBar(
                      hintText: 'Search ingredients',
                      leading: const Icon(Icons.search),
                      onChanged: (query) {/* TODO */},
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    style: IconButton.styleFrom(backgroundColor: Colors.green),
                    onPressed: () {/* TODO */},
                    icon: const Icon(Icons.filter_list, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              for (final entry in categories.entries) ...[
                Text(entry.key, style: theme.textTheme.titleMedium),
                ...entry.value.map((item) => _PantryItemTile(item: item)),
                const SizedBox(height: 12),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _PantryItemTile extends StatelessWidget {
  const _PantryItemTile({required this.item});
  final PantryItem item;

  @override
  Widget build(BuildContext context) {
    final statusColor = item.isExpiringSoon ? Colors.red : Colors.green;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 12, height: 12, margin: const EdgeInsets.only(top: 4),
        decoration: BoxDecoration(color: statusColor, borderRadius: BorderRadius.circular(3)),
      ),
      title: Text(item.name),
      subtitle: Text(item.quantity, style: Theme.of(context).textTheme.bodySmall),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber_rounded, size: 16, color: statusColor),
          const SizedBox(width: 4),
          Text('Exp. in ${item.expiresInDays} days', style: TextStyle(color: statusColor, fontSize: 12)),
        ],
      ),
    );
  }
}