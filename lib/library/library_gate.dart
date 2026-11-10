import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../content/content_repository.dart';
import '../content/model.dart';
import '../design/tokens.dart';
import '../design/typography.dart';

/// Builds [builder] once the library has loaded; shows something quiet while
/// loading and a plain message if the text could not be loaded.
class LibraryGate extends ConsumerWidget {
  const LibraryGate({super.key, required this.builder});

  final Widget Function(BuildContext context, Library library) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(libraryProvider).when(
          data: (library) => builder(context, library),
          loading: () => const SizedBox.shrink(),
          error: (_, _) => Center(
            child: Text(
              'The text could not be loaded.',
              style: namoText(NamoFonts.english,
                  size: 16, color: NamoPalette.of(context).text),
            ),
          ),
        );
  }
}
