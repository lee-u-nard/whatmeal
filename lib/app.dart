import 'package:flutter/material.dart';
import 'core/routing/app_router.dart';
// import 'features/home/pages/home_page.dart';

class WhatMealApp extends StatelessWidget {
  const WhatMealApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'WhatMeal',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      routerConfig: appRouter,
    );
  }
}
