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
  });

  final PantryItem? existingItem;
  final String? existingCategory;

  @override
  State<AddPantryItemSheet> createState() => _AddPantryItemSheetState();
}

class _AddPantryItemSheetState extends State<AddPantryItemSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _quantityController;
  late String _category;
  DateTime? _expirationDate;

  static const _categories = ['Proteins', 'Vegetables', 'Dairy', 'Pantry Staples'];

  bool get _isEditing => widget.existingItem != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final item = widget.existingItem!;
      _nameController = TextEditingController(text: item.name);
      _quantityController = TextEditingController(text: item.quantity);
      _category = widget.existingCategory ?? _categories.first;
      // Reconstruct approximate expiration date from expiresInDays
      _expirationDate = DateTime.now().add(Duration(days: item.expiresInDays));
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
    final picked = await showDatePicker(
      context: context,
      initialDate: _expirationDate ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _expirationDate = picked);
  }

  void _submit() {
    if (!_formKey.currentState!.validate() || _expirationDate == null) {
      if (_expirationDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select an expiration date.')),
        );
      }
      return;
    }
    final daysLeft = _expirationDate!.difference(DateTime.now()).inDays;
    final item = PantryItem(
      id: widget.existingItem?.id ?? 'p_${DateTime.now().millisecondsSinceEpoch}',
      name: _nameController.text.trim(),
      quantity: _quantityController.text.trim(),
      expiresInDays: daysLeft,
      isExpiringSoon: daysLeft <= 5,
      status: widget.existingItem?.status ?? PantryStatus.available,
    );
    Navigator.pop(context, NewPantryItem(category: _category, item: item));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
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
                  Text(
                    _isEditing ? 'Edit Ingredient' : 'Add Ingredient',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
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
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _quantityController,
                decoration: const InputDecoration(
                  labelText: 'Quantity (e.g. 1.2 kg, 4 units)',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _categories.contains(_category) ? _category : _categories.first,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: _categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
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
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: _submit,
                  child: Text(
                    _isEditing ? 'Save Changes' : 'Add to Pantry',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}