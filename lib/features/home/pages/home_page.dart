import 'package:flutter/material.dart';

import '../../../core/widgets/app_shell.dart';

/// Add AppShell later when sharing a widgets
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Home'));
    /*
    return AppShell(
      title: 'WhatMeal',
      body: Center(child: Text('Welcome to WhatMeal')),
    );
    */
  }
}
