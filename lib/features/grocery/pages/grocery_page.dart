import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import '../data/grocery_repository.dart';
import '../models/grocery_item.dart';
import '../widgets/grocery_toolbar.dart';
import '../widgets/grocery_item_editor.dart';
import '../widgets/clear_used_dialog.dart';

class GroceryPage extends StatefulWidget {
  const GroceryPage({super.key, this.repository});
  final GroceryRepository? repository;

  @override
  State<GroceryPage> createState() => _GroceryPageState();
}

class _GroceryPageState extends State<GroceryPage> {
  GroceryRepository get _repo =>
      widget.repository ?? GroceryRepository.instance;
  Future<void> _runMutation(Future<void> Function() operation) async {
    try {
      await operation();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Change was not saved. Check your permissions and connection. Meal requirements must be changed in their source meal.')));
      }
    }
  }

  void _confirmDeleteItem(String itemName, String itemId) {
    final scope = _repo.scopeVersion;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete $itemName?'),
        content: Text(
            'Are you sure you want to remove $itemName from your grocery list?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              await _runMutation(() async {
                if (scope != _repo.scopeVersion) {
                  throw StateError('Workspace changed.');
                }
                await _repo.deleteItem(itemId);
                if (!mounted || !ctx.mounted) return;
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Removed $itemName from grocery list')));
              });
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Delete',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showAddGroceryModal([GroceryItem? existing]) {
    final scope = _repo.scopeVersion;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardSurface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => GroceryItemEditor(
          existing: existing,
          isSessionCurrent: () => scope == _repo.scopeVersion,
          onSave: (item) async {
            if (scope != _repo.scopeVersion) {
              throw StateError('Workspace changed.');
            }
            var added = true;
            if (existing == null) {
              added = await _repo.addItem(item.category, item);
            } else {
              await _repo.updateItem(item);
            }
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(!added
                    ? 'This item is already on your list.'
                    : existing == null
                        ? 'Added ${item.name} to grocery list.'
                        : 'Grocery item updated.')));
          }),
    );
  }

  Future<void> _shareGroceryList(
      Map<String, List<GroceryItem>> sections) async {
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
    try {
      await Clipboard.setData(ClipboardData(text: buffer.toString()));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not copy the list.')));
      }
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Expanded(child: Text('Grocery list copied to clipboard!')),
          ],
        ),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, List<GroceryItem>>>(
      valueListenable: _repo,
      builder: (context, sections, _) {
        final remainingCount = sections.values
            .expand((items) => items)
            .where((i) => i.status == GroceryStatus.needed)
            .length;
        final totalItems = sections.values.expand((items) => items).length;

        return Scaffold(
          backgroundColor: AppColors.background,
          floatingActionButton: FloatingActionButton(
            backgroundColor: AppColors.primary,
            tooltip: 'Add grocery item',
            onPressed: () => _showAddGroceryModal(),
            child: const Icon(Icons.add, color: Colors.white),
          ),
          body: _repo.isLoading
              ? const Center(child: CircularProgressIndicator())
              : _repo.error != null
                  ? Center(
                      child: Padding(
                          padding: const EdgeInsets.all(24),
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                            Text(_repo.error!, textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            ElevatedButton(
                                onPressed: _repo.retry,
                                child: const Text('Retry')),
                          ])))
                  : totalItems == 0
                      ? _buildEmptyState(context)
                      : ListView(
                          padding: const EdgeInsets.all(20),
                          children: [
                            if (_repo.isShared)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryLight,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: AppColors.primary
                                            .withValues(alpha: 0.3)),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.groups,
                                          size: 18, color: AppColors.primary),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Shared family grocery list — updates sync for household members.',
                                          style: TextStyle(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            // Status legend banner
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: AppColors.cardSurface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Wrap(
                                alignment: WrapAlignment.spaceAround,
                                spacing: 12,
                                runSpacing: 8,
                                children: [
                                  _LegendDot(
                                    color: AppColors.danger,
                                    label: 'Needed',
                                    subtitle: 'unchecked',
                                  ),
                                  _LegendDot(
                                    color: AppColors.info,
                                    label: 'Available',
                                    subtitle: 'tap chip',
                                  ),
                                  _LegendDot(
                                    color: AppColors.primary,
                                    label: 'Purchased',
                                    subtitle: 'checkbox ✓',
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Subheader row
                            GroceryToolbar(
                              remainingCount: remainingCount,
                              onShare: () => _shareGroceryList(sections),
                              onClearUsed: () async {
                                final scope = _repo.scopeVersion;
                                if (await confirmClearUsed(context) &&
                                    mounted) {
                                  await _runMutation(() async {
                                    if (scope != _repo.scopeVersion) {
                                      throw StateError('Workspace changed.');
                                    }
                                    await _repo.clearUsed();
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 12),

                            for (final entry in sections.entries) ...[
                              if (entry.value.isNotEmpty) ...[
                                Padding(
                                  padding: const EdgeInsets.only(
                                      top: 8, bottom: 8, left: 4),
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
                                      for (var i = 0;
                                          i < entry.value.length;
                                          i++) ...[
                                        GroceryItemTile(
                                          key: ValueKey(entry.value[i].id),
                                          item: entry.value[i],
                                          onTogglePurchased: (purchased) =>
                                              _runMutation(() =>
                                                  _repo.setPurchased(
                                                      entry.value[i].id!,
                                                      purchased)),
                                          onCycleStatus: () => _runMutation(
                                              () => _repo.cycleStatus(
                                                  entry.value[i].id!)),
                                          onEdit: entry.value[i].sourceMealPaths
                                                  .isEmpty
                                              ? () => _showAddGroceryModal(
                                                  entry.value[i])
                                              : null,
                                          onDelete: () => _confirmDeleteItem(
                                              entry.value[i].name,
                                              entry.value[i].id!),
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
              onPressed: () => _showAddGroceryModal(),
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

class GroceryItemTile extends StatelessWidget {
  const GroceryItemTile({
    super.key,
    required this.item,
    required this.onTogglePurchased,
    required this.onCycleStatus,
    required this.onDelete,
    this.onEdit,
  });

  final GroceryItem item;
  final ValueChanged<bool> onTogglePurchased;
  final VoidCallback onCycleStatus;
  final VoidCallback onDelete;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final isPurchased = item.isPurchased;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Checkbox(
            value: isPurchased,
            activeColor: AppColors.primary,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            onChanged: item.status == GroceryStatus.available
                ? null
                : (v) => onTogglePurchased(v ?? false)),
        const SizedBox(width: 4),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item.name,
              style: TextStyle(
                  color:
                      isPurchased ? AppColors.textMuted : AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  decoration: isPurchased ? TextDecoration.lineThrough : null)),
          Wrap(spacing: 6, runSpacing: 2, children: [
            Text(item.quantity,
                style:
                    const TextStyle(color: AppColors.textMuted, fontSize: 12)),
            if (item.tag != null)
              Text('(${item.tag!})',
                  style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      fontStyle: FontStyle.italic)),
          ]),
          Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
            Tooltip(
                message: 'Tap to change availability status',
                child: GestureDetector(
                    onTap: onCycleStatus,
                    child: _StatusChip(status: item.status))),
            if (onEdit != null)
              IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  tooltip: 'Edit item',
                  onPressed: onEdit),
            IconButton(
                icon: const Icon(Icons.close,
                    size: 16, color: AppColors.textMuted),
                tooltip: 'Remove item',
                onPressed: onDelete),
          ]),
        ])),
      ]),
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
                style:
                    const TextStyle(color: AppColors.textMuted, fontSize: 10)),
          ],
        ),
      ],
    );
  }
}
