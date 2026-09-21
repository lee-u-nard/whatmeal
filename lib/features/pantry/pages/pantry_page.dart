import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../data/pantry_repository.dart';
import '../models/pantry_item.dart';
import '../widgets/add_pantry_item_sheet.dart';

class PantryPage extends StatefulWidget {
  const PantryPage({super.key});

  @override
  State<PantryPage> createState() => _PantryPageState();
}

class _PantryPageState extends State<PantryPage> {
  String _searchQuery = '';
  bool _onlyExpiringSoon = false;

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Filter Pantry Items',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: AppColors.textMuted),
                        tooltip: 'Close',
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    activeThumbColor: AppColors.danger,
                    title: const Text(
                      'Show Only Expiring Soon (<= 5 days)',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    value: _onlyExpiringSoon,
                    onChanged: (val) {
                      setSheetState(() => _onlyExpiringSoon = val);
                      setState(() => _onlyExpiringSoon = val);
                    },
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Apply Filter', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _editItem(PantryItem item, String category) async {
    final result = await showModalBottomSheet<NewPantryItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => AddPantryItemSheet(
        existingItem: item,
        existingCategory: category,
      ),
    );

    if (result != null && mounted) {
      if (result.category != category) {
        PantryRepository.instance.deleteItem(item.id);
        PantryRepository.instance.addItem(result.category, result.item);
      } else {
        PantryRepository.instance.updateItem(category, result.item);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Updated ${result.item.name}')),
      );
    }
  }

  void _confirmDeleteItem(PantryItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete ${item.name}?'),
        content: Text('Are you sure you want to remove ${item.name} from your pantry inventory?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              PantryRepository.instance.deleteItem(item.id);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Removed ${item.name} from pantry.')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, List<PantryItem>>>(
      valueListenable: PantryRepository.instance,
      builder: (context, categories, _) {
        final filteredEntries = categories.entries.map((entry) {
          final items = _filterItems(entry.value);
          return MapEntry(entry.key, items);
        }).where((e) => e.value.isNotEmpty).toList();

        final totalItems = categories.values.expand((element) => element).length;

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
                    color: _onlyExpiringSoon ? AppColors.danger : AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.filter_list, color: Colors.white, size: 20),
                    tooltip: 'Filter options',
                    onPressed: _showFilterSheet,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            if (totalItems == 0) ...[
              _buildEmptyPantryState(context),
            ] else if (filteredEntries.isEmpty) ...[
              _buildEmptySearchState(),
            ] else ...[
              for (final entry in filteredEntries) ...[
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
                      for (var i = 0; i < entry.value.length; i++) ...[
                        _PantryItemTile(
                          item: entry.value[i],
                          category: entry.key,
                          onEdit: () => _editItem(entry.value[i], entry.key),
                          onDelete: () => _confirmDeleteItem(entry.value[i]),
                          onStatusChanged: (newStatus) {
                            PantryRepository.instance.setItemStatus(entry.value[i].id, newStatus);
                          },
                        ),
                        if (i != entry.value.length - 1)
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

  Widget _buildEmptySearchState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          const Icon(Icons.search_off, size: 48, color: AppColors.textMuted),
          const SizedBox(height: 12),
          Text(
            'No ingredients matching "$_searchQuery"',
            style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 15),
          ),
          const SizedBox(height: 4),
          const Text('Try adjusting your search query or filters.', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildEmptyPantryState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          const Icon(Icons.kitchen_outlined, size: 64, color: AppColors.textMuted),
          const SizedBox(height: 16),
          const Text(
            'Your Pantry is Empty',
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 18),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add ingredients you currently have at home so AI can prioritize expiring items.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () async {
              final result = await showModalBottomSheet<NewPantryItem>(
                context: context,
                isScrollControlled: true,
                builder: (_) => const AddPantryItemSheet(),
              );
              if (result != null) {
                PantryRepository.instance.addItem(result.category, result.item);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('Add Ingredient', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  List<PantryItem> _filterItems(List<PantryItem> items) {
    return items.where((i) {
      final matchesSearch = _searchQuery.isEmpty || i.name.toLowerCase().contains(_searchQuery);
      final matchesExpiry = !_onlyExpiringSoon || i.isExpiringSoon;
      return matchesSearch && matchesExpiry;
    }).toList();
  }
}

class _PantryItemTile extends StatelessWidget {
  const _PantryItemTile({
    required this.item,
    required this.category,
    required this.onEdit,
    required this.onDelete,
    required this.onStatusChanged,
  });

  final PantryItem item;
  final String category;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<PantryStatus> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final expiryColor = item.isExpiringSoon ? AppColors.danger : AppColors.primary;
    final expiryBg = item.isExpiringSoon ? AppColors.dangerLight : AppColors.primaryLight;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: expiryColor,
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
                  style: TextStyle(
                    color: item.status == PantryStatus.used ? AppColors.textMuted : AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    decoration: item.status == PantryStatus.used ? TextDecoration.lineThrough : null,
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
          // Status Chip (FR-08: Available / Used / Needed)
          Tooltip(
            message: 'Tap to change status (Available / Used / Needed)',
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () {
                final nextIndex = (item.status.index + 1) % PantryStatus.values.length;
                onStatusChanged(PantryStatus.values[nextIndex]);
              },
              child: _buildStatusChip(item.status),
            ),
          ),
          const SizedBox(width: 6),
          // Expiry tag
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: expiryBg,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  item.isExpiringSoon ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                  size: 12,
                  color: expiryColor,
                ),
                const SizedBox(width: 2),
                Text(
                  '${item.expiresInDays}d',
                  style: TextStyle(
                    color: expiryColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          // Actions menu (FR-03: Edit + Delete)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 18, color: AppColors.textMuted),
            tooltip: 'Item options',
            onSelected: (val) {
              if (val == 'edit') onEdit();
              if (val == 'delete') onDelete();
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_outlined, size: 16, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text('Edit Item'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, size: 16, color: AppColors.danger),
                    SizedBox(width: 8),
                    Text('Delete Item', style: TextStyle(color: AppColors.danger)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(PantryStatus status) {
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case PantryStatus.available:
        bg = AppColors.primaryLight;
        fg = AppColors.primary;
        label = 'Available';
        break;
      case PantryStatus.used:
        bg = const Color(0xFFEEEEEE);
        fg = AppColors.textMuted;
        label = 'Used';
        break;
      case PantryStatus.needed:
        bg = AppColors.dangerLight;
        fg = AppColors.danger;
        label = 'Needed';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}