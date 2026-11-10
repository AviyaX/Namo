import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../content/model.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../design/widgets/buttons.dart';
import '../design/widgets/empty_state.dart';
import '../design/widgets/list_row.dart';
import '../design/widgets/namo_page.dart';
import '../design/widgets/page_header.dart';
import '../home/card_art.dart';
import '../library/library_gate.dart';
import '../router.dart';
import 'saved.dart';

class SavedScreen extends ConsumerWidget {
  const SavedScreen({super.key = const ValueKey('screen-saved')});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(savedProvider);
    final controller = ref.read(savedProvider.notifier);
    final p = NamoPalette.of(context);
    return NamoPage(
      columnKey: const ValueKey('saved-column'),
      children: [
        const PageHeader(title: 'Saved'),
        const SizedBox(height: NamoSpace.lg),
        LibraryGate(
          builder: (context, library) {
            // Entries the content no longer has are left out, not deleted.
            final bookmarks = <(Bookmark, Reading, Section)>[];
            for (final b in saved.bookmarks) {
              final reading = library.reading(b.readingId);
              if (reading == null) continue;
              for (final s in reading.sections) {
                if (s.id == b.sectionId) bookmarks.add((b, reading, s));
              }
            }
            final favourites = <Reading>[
              for (final id in saved.favourites.toList().reversed)
                ?library.reading(id),
            ];
            if (bookmarks.isEmpty && favourites.isEmpty) {
              return EmptyState(
                icon: Symbols.bookmark_rounded,
                title: 'Nothing saved yet',
                message:
                    'Bookmark a section or favourite a reading and it will '
                    'wait for you here.',
                actionLabel: 'Open the Library',
                onAction: () => context.go(Routes.library),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: NamoSpace.lg),
                  child: Overline('Bookmarks · ${bookmarks.length}', header: true),
                ),
                const SizedBox(height: NamoSpace.sm),
                if (bookmarks.isEmpty) const _Empty('No bookmarks yet.'),
                for (final (b, reading, section) in bookmarks)
                  ListRow(
                    number: section.number,
                    title: section.heading,
                    titleFamily: NamoFonts.sinhala,
                    subtitle: reading.title,
                    onTap: () => context.go(
                      Routes.reader(
                        reading.id,
                        sectionId: section.id,
                        from: ReaderFrom.saved,
                      ),
                    ),
                    action: NamoIconButton(
                      icon: Symbols.close_rounded,
                      tooltip: 'Remove bookmark: ${section.heading}',
                      color: p.textSecondary,
                      onPressed: () =>
                          controller.toggleBookmark(b.readingId, b.sectionId),
                    ),
                  ),
                const SizedBox(height: NamoSpace.xxl),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: NamoSpace.lg),
                  child: Overline('Favourites · ${favourites.length}', header: true),
                ),
                const SizedBox(height: NamoSpace.sm),
                if (favourites.isEmpty) const _Empty('No favourites yet.'),
                for (final reading in favourites)
                  ListRow(
                    leading: TopicThumbnail(
                      categoryId: library.categoryOf(reading.id)?.id ?? '',
                    ),
                    title: reading.title,
                    subtitle: library.categoryOf(reading.id)?.subtitle,
                    onTap: () => context.go(
                      Routes.reader(reading.id, from: ReaderFrom.saved),
                    ),
                    action: NamoIconButton(
                      icon: Symbols.close_rounded,
                      tooltip: 'Remove favourite: ${reading.title}',
                      color: p.textSecondary,
                      onPressed: () => controller.toggleFavourite(reading.id),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: NamoSpace.lg,
      vertical: NamoSpace.sm,
    ),
    child: Text(
      text,
      style: NamoType.body(NamoPalette.of(context).textSecondary),
    ),
  );
}
