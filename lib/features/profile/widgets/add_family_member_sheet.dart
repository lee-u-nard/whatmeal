import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../models/family_member.dart';

class AddFamilyMemberSheet extends StatefulWidget {
  const AddFamilyMemberSheet({super.key});

  @override
  State<AddFamilyMemberSheet> createState() => _AddFamilyMemberSheetState();
}

class _AddFamilyMemberSheetState extends State<AddFamilyMemberSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _relationController = TextEditingController();
  final _ageController = TextEditingController();
  final _prefController = TextEditingController();
  final _restrictController = TextEditingController();
  final List<String> _preferences = [];
  final List<String> _restrictions = [];

  @override
  void dispose() {
    _nameController.dispose();
    _relationController.dispose();
    _ageController.dispose();
    _prefController.dispose();
    _restrictController.dispose();
    super.dispose();
  }

  void _addPreference() {
    final text = _prefController.text.trim();
    if (text.isNotEmpty && !_preferences.contains(text)) {
      setState(() => _preferences.add(text));
      _prefController.clear();
    }
  }

  void _addRestriction() {
    final text = _restrictController.text.trim();
    if (text.isNotEmpty && !_restrictions.contains(text)) {
      setState(() => _restrictions.add(text));
      _restrictController.clear();
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final member = FamilyMember(
      name: _nameController.text.trim(),
      relation: _relationController.text.trim().isEmpty ? null : _relationController.text.trim(),
      age: int.tryParse(_ageController.text) ?? 0,
      preferences: List.from(_preferences),
      restrictions: List.from(_restrictions),
    );
    Navigator.pop(context, member);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Add Family Member', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _relationController,
                decoration: const InputDecoration(labelText: 'Relation (e.g., Dad, Mom, optional)'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _ageController,
                decoration: const InputDecoration(labelText: 'Age'),
                keyboardType: TextInputType.number,
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              // Preferences
              Text('Preferences', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _prefController,
                      decoration: const InputDecoration(hintText: 'e.g., Low-carb'),
                      onSubmitted: (_) => _addPreference(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: AppColors.primary),
                    onPressed: _addPreference,
                  ),
                ],
              ),
              if (_preferences.isNotEmpty)
                Wrap(
                  spacing: 6,
                  children: _preferences.map((p) => Chip(
                    label: Text(p, style: const TextStyle(fontSize: 12)),
                    backgroundColor: AppColors.primaryLight,
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () => setState(() => _preferences.remove(p)),
                  )).toList(),
                ),
              const SizedBox(height: 12),

              // Restrictions
              Text('Restrictions', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _restrictController,
                      decoration: const InputDecoration(hintText: 'e.g., Nut allergy'),
                      onSubmitted: (_) => _addRestriction(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: AppColors.danger),
                    onPressed: _addRestriction,
                  ),
                ],
              ),
              if (_restrictions.isNotEmpty)
                Wrap(
                  spacing: 6,
                  children: _restrictions.map((r) => Chip(
                    label: Text(r, style: const TextStyle(fontSize: 12)),
                    backgroundColor: AppColors.dangerLight,
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () => setState(() => _restrictions.remove(r)),
                  )).toList(),
                ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: FilledButton(onPressed: _submit, child: const Text('Add Member')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
