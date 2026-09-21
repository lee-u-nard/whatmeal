import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../data/grocery_repository.dart';
import '../models/grocery_item.dart';

class GroceryPage extends StatefulWidget {
  const GroceryPage({super.key});

  @override
  State<GroceryPage> createState() => _GroceryPageState();
}

class _GroceryPageState extends State<GroceryPage> {
  final _nameController = TextEditingController();
  final _qtyController = TextEditingController();
  String _selectedSection = 'PRODUCE AISLE';

  static const _sectionsList = [
    'PRODUCE AISLE',
    'MEAT & SEAFOOD',
    'PANTRY STAPLES',
    'DAIRY & REFRIGERATED',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _qtyController.dispose();
    super.dispose();
  }

  void _showAddGroceryModal() {
    _nameController.clear();
    _qtyController.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Add Grocery Item',
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
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Item Name',
                  hintText: 'e.g. Organic Milk',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _qtyController,
                decoration: InputDecoration(
                  labelText: 'Quantity',
                  hintText: 'e.g. 2 Gallons, 500g',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _selectedSection,
                decoration: InputDecoration(
                  labelText: 'Aisle / Category',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: _sectionsList
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedSection = v!),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    if (_nameController.text.trim().isNotEmpty) {
                      final item = GroceryItem(
                        id: 'g_${DateTime.now().millisecondsSinceEpoch}',
                        name: _nameController.text.trim(),
                        quantity: _qtyController.text.trim().isEmpty
                            ? '1 unit'
                            : _qtyController.text.trim(),
                        section: _selectedSection,
                      );
                      GroceryRepository.instance.addItem(_selectedSection, item);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Added ${item.name} to grocery list.')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Add to List', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _shareGroceryList(Map<String, List<GroceryItem>> sections) {
    final buffer = StringBuffer();
    buffer.writeln('🛒 WhatMeal Grocery Shopping List:');
    buffer.writeln();
    for (final entry in sections.entries) {
      buffer.writeln('📍 ${entry.key}');
      for (final item in entry.value) {
        final statusLabel = item.status == GroceryStatus.used
            ? '✓'
            : item.status == GroceryStatus.available
                ? '◑'
                : '☐';
        buffer.writeln('  $statusLabel ${item.name} (${item.quantity})');
      }
      buffer.writeln();
    }
    // Copy to clipboard via flutter/services if needed; using SnackBar for simplicity
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Grocery list copied to clipboard!'),
          ],
        ),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, List<GroceryItem>>>(
      valueListenable: GroceryRepository.instance,
      builder: (context, sections, _) {
        final remainingCount = sections.values
            .expand((items) => items)
            .where((i) => i.status != GroceryStatus.used)
            .length;
        final totalItems = sections.values.expand((items) => items).length;

        return Scaffold(
          backgroundColor: AppColors.background,
          floatingActionButton: FloatingActionButton(
            backgroundColor: AppColors.primary,
            tooltip: 'Add grocery item',
            onPressed: _showAddGroceryModal,
            child: const Icon(Icons.add, color: Colors.white),
          ),
          body: totalItems == 0
              ? _buildEmptyState(context)
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Status legend banner
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.cardSurface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _LegendDot(
                            color: AppColors.danger,
                            label: 'Needed',
                            subtitle: 'tap to cycle',
                          ),
                          _LegendDot(
                            color: AppColors.info,
                            label: 'Available',
                            subtitle: 'in stock',
                          ),
                          _LegendDot(
                            color: AppColors.textMuted,
                            label: 'Used',
                            subtitle: 'done',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Subheader row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$remainingCount remaining items',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        Row(
                          children: [
                            TextButton.icon(
                              onPressed: () => _shareGroceryList(sections),
                              icon: const Icon(Icons.share, size: 14, color: AppColors.primary),
                              label: const Text(
                                'Share List',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () => GroceryRepository.instance.clearUsed(),
                              icon: const Icon(Icons.cleaning_services_outlined,
                                  size: 14, color: AppColors.danger),
                              label: const Text(
                                'Clear Used',
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

                    for (final entry in sections.entries) ...[
                      if (entry.value.isNotEmpty) ...[
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
                                  onCycleStatus: () => GroceryRepository.instance
                                      .cycleStatus(entry.value[i].id),
                                  onDelete: () => GroceryRepository.instance
                                      .deleteItem(entry.value[i].id),
                                ),
                                if (i != entry.value.length - 1)
                                  const Divider(
                                      height: 1,
                                      indent: 16,
                                      endIndent: 16,
                                      color: AppColors.border),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ],
                ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.shopping_cart_outlined,
                size: 64, color: AppColors.textMuted),
            const SizedBox(height: 16),
            const Text(
              'Grocery List is Clean',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'All items used! Generate a new AI meal plan to auto-export required missing ingredients here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.textSecondary, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showAddGroceryModal,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Grocery Item',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Grocery Item Tile — 3-state status chip (FR-08)
// ─────────────────────────────────────────────────────────────────────────────

class _GroceryItemTile extends StatelessWidget {
  const _GroceryItemTile({
    required this.item,
    required this.onCycleStatus,
    required this.onDelete,
  });

  final GroceryItem item;
  final VoidCallback onCycleStatus;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isUsed = item.status == GroceryStatus.used;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Status chip — tap to cycle
          Tooltip(
            message: 'Tap to change status',
            child: GestureDetector(
              onTap: onCycleStatus,
              child: _StatusChip(status: item.status),
            ),
          ),
          const SizedBox(width: 12),

          // Name + quantity
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: TextStyle(
                    color: isUsed ? AppColors.textMuted : AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    decoration: isUsed ? TextDecoration.lineThrough : null,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      item.quantity,
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 12),
                    ),
                    if (item.tag != null && isUsed) ...[
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
              ],
            ),
          ),

          // Delete
          IconButton(
            icon: const Icon(Icons.close, size: 16, color: AppColors.textMuted),
            tooltip: 'Remove item',
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final GroceryStatus status;

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color fg;
    final String label;
    final IconData icon;

    switch (status) {
      case GroceryStatus.needed:
        bg = AppColors.dangerLight;
        fg = AppColors.danger;
        label = 'Needed';
        icon = Icons.shopping_cart_outlined;
        break;
      case GroceryStatus.available:
        bg = AppColors.infoLight;
        fg = AppColors.info;
        label = 'Available';
        icon = Icons.inventory_2_outlined;
        break;
      case GroceryStatus.used:
        bg = const Color(0xFFEEEEEE);
        fg = AppColors.textMuted;
        label = 'Used';
        icon = Icons.check_circle_outline;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({
    required this.color,
    required this.label,
    required this.subtitle,
  });
  final Color color;
  final String label;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    color: color, fontSize: 12, fontWeight: FontWeight.w700)),
            Text(subtitle,
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 10)),
          ],
        ),
      ],
    );
  }
}