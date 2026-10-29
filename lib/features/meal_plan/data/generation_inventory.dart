import '../../../core/services/ai/pantry_prompt_context.dart';
import '../../grocery/data/grocery_repository.dart';
import '../../pantry/data/pantry_repository.dart';

class GenerationInventoryUnavailable implements Exception {
  const GenerationInventoryUnavailable();

  @override
  String toString() =>
      'Pantry or grocery data is still loading or could not be loaded. '
      'Retry loading, then generate again once your items are available.';
}

/// Capture only ready inventory belonging to the originating workspace.
/// Called before any provider request or quota reservation.
class GenerationInventory {
  const GenerationInventory(this.pantryItems, this.groceryItems);

  final List<String> pantryItems;
  final List<String> groceryItems;

  factory GenerationInventory.capture({
    required String workspacePath,
    required PantryRepository pantry,
    required GroceryRepository groceries,
    required DateTime now,
  }) {
    if (pantry.scopePath != workspacePath ||
        groceries.scopePath != workspacePath ||
        pantry.isLoading ||
        groceries.isLoading ||
        pantry.error != null ||
        groceries.error != null) {
      throw const GenerationInventoryUnavailable();
    }
    return GenerationInventory(
      pantryPromptContext(pantry.items.values.expand((items) => items),
          now: now),
      List.of(groceries.allItemNames),
    );
  }
}
