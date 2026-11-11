import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The ids of the Library categories whose sections are showing. Held for as
/// long as the app runs, so the list is still open after a visit to another
/// tab or to the reader. It is not written to storage.
class OpenCategories extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  void toggle(String id) =>
      state = state.contains(id) ? ({...state}..remove(id)) : {...state, id};

  void open(String id) {
    if (!state.contains(id)) state = {...state, id};
  }
}

final openCategoriesProvider =
    NotifierProvider<OpenCategories, Set<String>>(OpenCategories.new);
