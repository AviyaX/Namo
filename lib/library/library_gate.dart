import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../content/content_repository.dart';
import '../content/model.dart';
import '../design/tokens.dart';
import '../design/widgets/empty_state.dart';

/// Builds [builder] once the library has loaded; shows something quiet while
/// loading and a plain message if the text could not be loaded.
class LibraryGate extends ConsumerWidget {
  const LibraryGate({super.key, required this.builder});

  final Widget Function(BuildContext context, Library library) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(libraryProvider).when(
          data: (library) => builder(context, library),
          loading: () => Center(
            child: Padding(
              padding: const EdgeInsets.all(NamoSpace.xl),
              child: SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: NamoPalette.of(context).sage,
                ),
              ),
            ),
          ),
          error: (_, _) => const EmptyState(
            icon: Symbols.error_outline_rounded,
            title: 'The text could not be loaded.',
            message: '',
          ),
        );
  }
}
