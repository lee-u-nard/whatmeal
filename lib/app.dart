import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/services/auth_service.dart';
import 'core/services/user_service.dart';
import 'features/pantry/data/pantry_repository.dart';
import 'features/grocery/data/grocery_repository.dart';
import 'features/profile/data/family_member_repository.dart';
import 'features/meal_plan/data/meal_plan_repository.dart';

class WhatMealApp extends StatefulWidget {
  const WhatMealApp({super.key});

  @override
  State<WhatMealApp> createState() => _WhatMealAppState();
}

class _WhatMealAppState extends State<WhatMealApp> {
  GoRouter? _router;
  StreamSubscription? _userSub;
  String? _lastFamilyId;
  String? _lastUid;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final authService = context.watch<AuthService>();
    _router ??= createAppRouter(authService);
    _syncFamilyScope();
  }

  void _syncFamilyScope() {
    final authService = context.read<AuthService>();
    final userService = context.read<UserService>();
    final currentUid = authService.uid;

    if (currentUid != _lastUid) {
      _lastUid = currentUid;
      _userSub?.cancel();

      if (currentUid != null) {
        _userSub = userService.userStream(currentUid).listen((userDoc) {
          final familyId = userDoc?.familyId;
          if (familyId != _lastFamilyId) {
            _lastFamilyId = familyId;
            if (mounted) {
              _applyFamilyId(familyId);
            }
          }
        });
      } else {
        _lastFamilyId = null;
        _applyFamilyId(null);
      }
    }
  }

  void _applyFamilyId(String? familyId) {
    context.read<PantryRepository>().setFamilyId(familyId);
    context.read<GroceryRepository>().setFamilyId(familyId);
    context.read<FamilyMemberRepository>().setFamilyId(familyId);
    context.read<MealPlanRepository>().setFamilyId(familyId);
  }

  @override
  void dispose() {
    _userSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'WhatMeal',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      routerConfig: _router!,
    );
  }
}
