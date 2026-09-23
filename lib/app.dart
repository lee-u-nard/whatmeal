import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/services/user_service.dart';
import 'features/auth/data/auth_repository.dart';
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
  void initState() {
    super.initState();
    _router = createAppRouter(AuthRepository.instance);
    AuthRepository.instance.addListener(_onAuthChanged);
    _syncFamilyScope();
  }

  void _onAuthChanged() {
    _syncFamilyScope();
    if (mounted) setState(() {});
  }

  void _syncFamilyScope() {
    final userService = context.read<UserService>();
    final currentUid = AuthRepository.instance.currentUser?.uid;

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
    // FamilyId logic is now self-contained in MealPlanRepository
  }

  @override
  void dispose() {
    AuthRepository.instance.removeListener(_onAuthChanged);
    _userSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (AuthRepository.instance.isInitializing) {
      return MaterialApp(
        title: 'WhatMeal',
        theme: AppTheme.lightTheme,
        debugShowCheckedModeBanner: false,
        home: const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return MaterialApp.router(
      title: 'WhatMeal',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      routerConfig: _router!,
    );
  }
}
