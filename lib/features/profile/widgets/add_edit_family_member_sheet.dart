import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../models/family_member.dart';

class AddEditFamilyMemberSheet extends StatefulWidget {
  const AddEditFamilyMemberSheet({super.key, this.existingMember});

  final FamilyMember? existingMember;

  @override
  State<AddEditFamilyMemberSheet> createState() => _AddEditFamilyMemberSheetState();
}

class _AddEditFamilyMemberSheetState extends State<AddEditFamilyMemberSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _relationController = TextEditingController();
  final _ageController = TextEditingController(text: '30');

  final _allPreferences = ['Keto', 'High Protein', 'Low Carb', 'Vegetarian Friendly', 'Vegan', 'Dairy Free', 'Sweet Lover'];
  final _allRestrictions = ['Peanut Allergy', 'No Spicy', 'Gluten Free', 'Shellfish Allergy', 'Dairy Allergy', 'Tree Nut'];

  late Set<String> _selectedPreferences;
  late Set<String> _selectedRestrictions;

  @override
  void initState() {
    super.initState();
    if (widget.existingMember != null) {
      _nameController.text = widget.existingMember!.name;
      _relationController.text = widget.existingMember!.relation ?? '';
      _ageController.text = widget.existingMember!.age.toString();
      _selectedPreferences = Set.from(widget.existingMember!.preferences);
      _selectedRestrictions = Set.from(widget.existingMember!.restrictions);
    } else {
      _selectedPreferences = {};
      _selectedRestrictions = {};
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _relationController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final member = FamilyMember(
      id: widget.existingMember?.id ?? 'fm_${DateTime.now().millisecondsSinceEpoch}',
      name: _nameController.text.trim(),
      relation: _relationController.text.trim().isEmpty ? null : _relationController.text.trim(),
      age: int.tryParse(_ageController.text.trim()) ?? 18,
      preferences: _selectedPreferences.toList(),
      restrictions: _selectedRestrictions.toList(),
    );

    Navigator.pop(context, member);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingMember != null;

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
                    isEditing ? 'Edit Family Member' : 'Add Family Member',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textMuted),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'First Name',
                  hintText: 'e.g. Sarah',
                  prefixIcon: const Icon(Icons.person_outline, color: AppColors.textMuted),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
              ),
              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _relationController,
                      decoration: InputDecoration(
                        labelText: 'Role / Relation',
                        hintText: 'e.g. Mom, Dad, Son',
                        prefixIcon: const Icon(Icons.family_restroom, color: AppColors.textMuted),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: TextFormField(
                      controller: _ageController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Age',
                        hintText: '8',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              const Text(
                'Dietary Preferences',
                style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 13),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _allPreferences.map((pref) {
                  final isSelected = _selectedPreferences.contains(pref);
                  return FilterChip(
                    label: Text(pref),
                    selected: isSelected,
                    selectedColor: AppColors.primaryLight,
                    checkmarkColor: AppColors.primary,
                    side: BorderSide(color: isSelected ? AppColors.primary : AppColors.border),
                    labelStyle: TextStyle(
                      color: isSelected ? AppColors.primary : AppColors.textSecondary,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 11,
                    ),
                    onSelected: (val) {
                      setState(() {
                        if (val) {
                          _selectedPreferences.add(pref);
                        } else {
                          _selectedPreferences.remove(pref);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              const Text(
                'Severe Allergies & Restrictions',
                style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700, fontSize: 13),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _allRestrictions.map((r) {
                  final isSelected = _selectedRestrictions.contains(r);
                  return FilterChip(
                    label: Text(r),
                    selected: isSelected,
                    selectedColor: AppColors.dangerLight,
                    checkmarkColor: AppColors.danger,
                    side: BorderSide(color: isSelected ? AppColors.danger : AppColors.border),
                    labelStyle: TextStyle(
                      color: isSelected ? AppColors.danger : AppColors.textSecondary,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 11,
                    ),
                    onSelected: (val) {
                      setState(() {
                        if (val) {
                          _selectedRestrictions.add(r);
                        } else {
                          _selectedRestrictions.remove(r);
                        }
                      });
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    isEditing ? 'Save Changes' : 'Add Family Member',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
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
