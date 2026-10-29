import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../models/grocery_item.dart';

/// The same editor is used for add/edit; failed writes keep the draft open.
class GroceryItemEditor extends StatefulWidget {
  const GroceryItemEditor(
      {super.key, this.existing, required this.onSave, this.isSessionCurrent});
  final GroceryItem? existing;
  final bool Function()? isSessionCurrent;
  final Future<void> Function(GroceryItem) onSave;

  @override
  State<GroceryItemEditor> createState() => _GroceryItemEditorState();
}

class _GroceryItemEditorState extends State<GroceryItemEditor> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name);
  late final _quantity = TextEditingController(text: widget.existing?.quantity);
  static const _sections = [
    'PRODUCE AISLE',
    'MEAT & SEAFOOD',
    'PANTRY STAPLES',
    'DAIRY & REFRIGERATED'
  ];
  late String _section = _sections.contains(widget.existing?.category)
      ? widget.existing!.category
      : _sections.first;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _quantity.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (widget.isSessionCurrent?.call() == false) {
      setState(() => _error =
          'Your account or household changed. Close this editor and reopen it.');
      return;
    }
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final item = (widget.existing ?? GroceryItem(name: '', quantity: ''))
        .copyWith(
            name: _name.text.trim(),
            quantity: _quantity.text.trim(),
            category: _section);
    try {
      await widget.onSave(item);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save grocery item. Please retry.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !_saving,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              MediaQuery.viewInsetsOf(context).bottom +
                  MediaQuery.paddingOf(context).bottom +
                  20),
          child: Form(
              key: _form,
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                          child: Text(
                              widget.existing == null
                                  ? 'Add Grocery Item'
                                  : 'Edit Grocery Item',
                              style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18))),
                      IconButton(
                          tooltip: 'Close',
                          onPressed:
                              _saving ? null : () => Navigator.pop(context),
                          icon: const Icon(Icons.close)),
                    ]),
                    const SizedBox(height: 16),
                    TextFormField(
                        controller: _name,
                        enabled: !_saving,
                        decoration: const InputDecoration(
                            labelText: 'Item Name',
                            hintText: 'e.g. Organic Milk',
                            border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.all(Radius.circular(12)))),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Enter an item name.'
                            : utf8.encode(v.trim()).length > 900
                                ? 'Item name is too long.'
                                : null),
                    const SizedBox(height: 12),
                    TextFormField(
                        controller: _quantity,
                        enabled: !_saving,
                        decoration: const InputDecoration(
                            labelText: 'Quantity',
                            hintText: 'e.g. 2 Gallons, 500g',
                            border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.all(Radius.circular(12)))),
                        validator: (v) => (v?.trim().length ?? 0) > 100
                            ? 'Quantity is too long.'
                            : null),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                        initialValue: _section,
                        isExpanded: true,
                        decoration: const InputDecoration(
                            labelText: 'Aisle / Category',
                            border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.all(Radius.circular(12)))),
                        items: _sections
                            .map((s) =>
                                DropdownMenuItem(value: s, child: Text(s)))
                            .toList(),
                        onChanged: _saving
                            ? null
                            : (v) => setState(() => _section = v!)),
                    if (_error != null)
                      Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(_error!,
                              style: const TextStyle(color: AppColors.danger))),
                    const SizedBox(height: 20),
                    SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                            onPressed: _saving ? null : _save,
                            style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white),
                            child: _saving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : Text(widget.existing == null
                                    ? 'Add to List'
                                    : 'Save Changes'))),
                  ])),
        ),
      );
}
