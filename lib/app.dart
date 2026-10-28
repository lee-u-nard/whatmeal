import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/data/auth_repository.dart';

class WhatMealApp extends StatefulWidget {
  const WhatMealApp({super.key, this.navigatorKey});

  final GlobalKey<NavigatorState>? navigatorKey;

  @override
  State<WhatMealApp> createState() => _WhatMealAppState();
}

class _WhatMealAppState extends State<WhatMealApp> {
  GoRouter? _router;

  @override
  void initState() {
    super.initState();
    _router = createAppRouter(AuthRepository.instance,
        navigatorKey: widget.navigatorKey);
    AuthRepository.instance.addListener(_onAuthChanged);
  }

  void _onAuthChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    AuthRepository.instance.removeListener(_onAuthChanged);
    _router?.dispose();
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
