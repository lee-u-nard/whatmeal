import 'package:flutter/material.dart';
import '../models/pantry_item.dart';

class NewPantryItem {
  const NewPantryItem({required this.category, required this.item});
  final String category;
  final PantryItem item;
}

/// Bottom sheet for adding a new pantry ingredient or editing an existing one (FR-03).
class AddPantryItemSheet extends StatefulWidget {
  const AddPantryItemSheet({
    super.key,
    this.existingItem,
    this.existingCategory,
    this.onSave,
  });

  final PantryItem? existingItem;
  final String? existingCategory;
  final Future<void> Function(NewPantryItem value)? onSave;

  @override
  State<AddPantryItemSheet> createState() => _AddPantryItemSheetState();
}

class _AddPantryItemSheetState extends State<AddPantryItemSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _quantityController;
  late String _category;
  DateTime? _expirationDate;
  bool _saving = false;
  String? _error;

  static const _categories = [
    'Proteins',
    'Vegetables',
    'Dairy',
    'Pantry Staples'
  ];

  bool get _isEditing => widget.existingItem != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final item = widget.existingItem!;
      _nameController = TextEditingController(text: item.name);
      _quantityController = TextEditingController(text: item.quantity);
      _category = widget.existingCategory ?? item.category;
      _expirationDate = item.expirationDate;
    } else {
      _nameController = TextEditingController();
      _quantityController = TextEditingController();
      _category = _categories.first;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _pickExpirationDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final selected = DateUtils.dateOnly(_expirationDate ?? today);
    final picked = await showDatePicker(
      context: context,
      initialDate: _expirationDate ?? today.add(const Duration(days: 7)),
      firstDate: selected.isBefore(today) ? selected : today,
      lastDate: selected.isAfter(today.add(const Duration(days: 365)))
          ? selected
          : today.add(const Duration(days: 365)),
    );
    if (picked != null && mounted) setState(() => _expirationDate = picked);
  }

  Future<void> _submit() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate() || _expirationDate == null) {
      if (_expirationDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select an expiration date.')),
        );
      }
      return;
    }
    final item = PantryItem(
      id: widget.existingItem?.id ??
          'p_${DateTime.now().millisecondsSinceEpoch}',
      name: _nameController.text.trim(),
      quantity: _quantityController.text.trim(),
      category: _category,
      expirationDate: _expirationDate,
      status: widget.existingItem?.status ?? PantryStatus.available,
      addedBy: widget.existingItem?.addedBy,
      createdAt: widget.existingItem?.createdAt,
    );
    final result = NewPantryItem(category: _category, item: item);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave?.call(result);
      if (mounted) Navigator.pop(context, result);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Ingredient was not saved. Please retry.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
        canPop: !_saving,
        child: AbsorbPointer(
            absorbing: _saving,
            child: Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.viewInsetsOf(context).bottom +
                    MediaQuery.paddingOf(context).bottom +
                    20,
              ),
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                              child: Text(
                            _isEditing ? 'Edit Ingredient' : 'Add Ingredient',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                          )),
                          IconButton(
                            icon: const Icon(Icons.close),
                            tooltip: 'Close',
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Ingredient Name',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Required'
                            : v.trim().length > 200
                                ? 'Use at most 200 characters'
                                : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _quantityController,
                        decoration: const InputDecoration(
                          labelText: 'Quantity (e.g. 1.2 kg, 4 units)',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Required'
                            : v.trim().length > 100
                                ? 'Use at most 100 characters'
                                : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: _category,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(),
                        ),
                        items: {..._categories, _category}
                            .map((c) =>
                                DropdownMenuItem(value: c, child: Text(c)))
                            .toList(),
                        onChanged: (v) => setState(() => _category = v!),
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        shape: RoundedRectangleBorder(
                          side: const BorderSide(color: Colors.grey),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        title: Text(
                          _expirationDate == null
                              ? 'Select expiration date'
                              : 'Expires: ${_expirationDate!.toLocal().toString().split(' ')[0]}',
                        ),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: _pickExpirationDate,
                      ),
                      if (_error != null)
                        Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(_error!,
                                style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.error))),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton(
                          onPressed: _saving ? null : _submit,
                          child: _saving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : Text(
                                  _isEditing ? 'Save Changes' : 'Add to Pantry',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )));
  }
}
