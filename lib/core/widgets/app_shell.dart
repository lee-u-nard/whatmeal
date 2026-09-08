import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/pantry/data/pantry_repository.dart';
import '../../features/pantry/widgets/add_pantry_item_sheet.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _titles = ['Home', 'Meal Plan', 'Pantry', 'Grocery', 'Profile'];

  static Widget? _fabForTab(int index, BuildContext context) {
    if (index != 2) return null;
    return FloatingActionButton(
      backgroundColor: Colors.green,
      onPressed: () async {
        final result = await showModalBottomSheet<NewPantryItem>(
          context: context,
          isScrollControlled: true,
          builder: (_) => const AddPantryItemSheet(),
        );
        if (result != null) {
          PantryRepository.instance.addItem(result.category, result.item);
        }
      },
      child: const Icon(Icons.add),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[navigationShell.currentIndex]),
        actions: [
          IconButton(
            icon: const CircleAvatar(child: Icon(Icons.person)),
            onPressed: () => navigationShell.goBranch(4),
          ),
        ],
      ),
      floatingActionButton: _fabForTab(navigationShell.currentIndex, context),
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(
            icon: Icon(Icons.restaurant_menu),
            label: 'Meal Plan',
          ),
          NavigationDestination(icon: Icon(Icons.kitchen), label: 'Pantry'),
          NavigationDestination(
            icon: Icon(Icons.shopping_cart),
            label: 'Grocery',
          ),
          NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
