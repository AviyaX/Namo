import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design/tokens.dart';
import '../design/typography.dart';
import '../design/widgets/list_row.dart';
import '../design/widgets/not_found.dart';
import '../router.dart';
import 'library_gate.dart';

class ReadingContentsScreen extends StatelessWidget {
  const ReadingContentsScreen({super.key, required this.readingId});

  final String readingId;

  @override
  Widget build(BuildContext context) {
    return LibraryGate(builder: (context, library) {
      final reading = library.reading(readingId);
      if (reading == null) return const NotFoundScreen();
      return Scaffold(
        appBar: AppBar(title: Text(reading.title)),
        body: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: NamoSizes.readingColumn),
            child: ListView(
              children: [
                for (final s in reading.sections)
                  ListRow(
                    number: s.number,
                    title: s.heading,
                    titleFamily: NamoFonts.sinhala,
                    onTap: () => context
                        .go(Routes.reader(reading.id, sectionId: s.id)),
                  ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

/// Stands in for the reader until it is built.
class ReaderPlaceholderScreen extends StatelessWidget {
  const ReaderPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: const Center(child: Text('The reader arrives in Stage 4.')),
    );
  }
}
