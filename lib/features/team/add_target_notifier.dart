import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The empty slot the user has chosen for the next Pokémon they pick, or null
/// if they have not chosen one (the next pick then takes the first empty slot).
///
/// Set by tapping an empty slot, and used up by the next pick.
class AddTargetNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void choose(int? index) => state = index;
}

final addTargetProvider = NotifierProvider<AddTargetNotifier, int?>(
  AddTargetNotifier.new,
);
