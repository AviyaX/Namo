import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design/tokens.dart';
import '../design/widgets/list_row.dart';
import '../router.dart';
import 'library_gate.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key = const ValueKey('screen-library')});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Library')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: NamoSizes.readingColumn),
          child: LibraryGate(
            builder: (context, library) => ListView(
              children: [
                for (final c in library.categories)
                  ListRow(
                    title: c.title,
                    subtitle: c.subtitle,
                    onTap: () => context.go(Routes.category(c.id)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
