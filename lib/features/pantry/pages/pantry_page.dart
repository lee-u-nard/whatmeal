import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../data/pantry_repository.dart';
import '../models/pantry_item.dart';

class PantryPage extends StatefulWidget {
  const PantryPage({super.key});

  @override
  State<PantryPage> createState() => _PantryPageState();
}

class _PantryPageState extends State<PantryPage> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Consumer<PantryRepository>(
      builder: (context, pantryRepo, _) {
        final categories = pantryRepo.items;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Search and Filter Bar Row
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.cardSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: TextField(
                      onChanged: (q) => setState(() => _searchQuery = q.toLowerCase()),
                      decoration: const InputDecoration(
                        hintText: 'Search ingredients',
                        hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
                        prefixIcon: Icon(Icons.search, color: AppColors.textMuted, size: 20),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.filter_list, color: Colors.white, size: 20),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Filter options opened')),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Categorized Items
            for (final entry in categories.entries) ...[
              if (_filterItems(entry.value).isNotEmpty) ...[
                Text(
                  entry.key,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
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
                      for (var i = 0; i < _filterItems(entry.value).length; i++) ...[
                        _PantryItemTile(item: _filterItems(entry.value)[i]),
                        if (i != _filterItems(entry.value).length - 1)
                          const Divider(height: 1, indent: 16, endIndent: 16, color: AppColors.border),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ],
          ],
        );
      },
    );
  }

  List<PantryItem> _filterItems(List<PantryItem> items) {
    if (_searchQuery.isEmpty) return items;
    return items.where((i) => i.name.toLowerCase().contains(_searchQuery)).toList();
  }
}

class _PantryItemTile extends StatelessWidget {
  const _PantryItemTile({required this.item});

  final PantryItem item;

  @override
  Widget build(BuildContext context) {
    final statusColor = item.isExpiringSoon ? AppColors.danger : AppColors.primary;
    final statusBg = item.isExpiringSoon ? AppColors.dangerLight : AppColors.primaryLight;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  item.quantity,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusBg,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  item.isExpiringSoon ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                  size: 14,
                  color: statusColor,
                ),
                const SizedBox(width: 4),
                Text(
                  'Exp. in ${item.expiresInDays} days',
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}