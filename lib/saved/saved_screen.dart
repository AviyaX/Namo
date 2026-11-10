import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../content/model.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../library/library_gate.dart';
import '../router.dart';
import '../settings/setting_controls.dart';
import 'saved.dart';

class SavedScreen extends ConsumerWidget {
  const SavedScreen({super.key = const ValueKey('screen-saved')});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(savedProvider);
    final controller = ref.read(savedProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: const Text('Saved')),
      body: LibraryGate(
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
          return Center(
            child: ConstrainedBox(
              key: const ValueKey('saved-column'),
              constraints: const BoxConstraints(
                maxWidth: NamoSizes.readingColumn,
              ),
              child: ListView(
                padding: const EdgeInsets.only(bottom: 16),
                children: [
                  const SettingsHeading('Bookmarks'),
                  if (bookmarks.isEmpty) const _Empty('No bookmarks yet.'),
                  for (final (b, reading, section) in bookmarks)
                    _SavedRow(
                      title: section.heading,
                      titleFamily: NamoFonts.sinhala,
                      subtitle: reading.title,
                      removeLabel: 'Remove bookmark: ${section.heading}',
                      onOpen: () => context.go(
                        Routes.reader(
                          reading.id,
                          sectionId: section.id,
                          from: ReaderFrom.saved,
                        ),
                      ),
                      onRemove: () =>
                          controller.toggleBookmark(b.readingId, b.sectionId),
                    ),
                  const SettingsHeading('Favourites'),
                  if (favourites.isEmpty) const _Empty('No favourites yet.'),
                  for (final reading in favourites)
                    _SavedRow(
                      title: reading.title,
                      removeLabel: 'Remove favourite: ${reading.title}',
                      onOpen: () => context.go(
                        Routes.reader(reading.id, from: ReaderFrom.saved),
                      ),
                      onRemove: () => controller.toggleFavourite(reading.id),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
    child: Text(
      text,
      style: namoText(
        NamoFonts.english,
        size: 16,
        color: NamoPalette.of(context).textQuiet,
      ),
    ),
  );
}

/// A row that opens its entry, with a remove button at the end.
class _SavedRow extends StatelessWidget {
  const _SavedRow({
    required this.title,
    required this.removeLabel,
    required this.onOpen,
    required this.onRemove,
    this.titleFamily = NamoFonts.english,
    this.subtitle,
  });

  final String title;
  final String titleFamily;
  final String? subtitle;
  final String removeLabel;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: p.divider, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              button: true,
              container: true,
              excludeSemantics: true,
              label: [title, ?subtitle].join(', '),
              onTap: onOpen,
              child: InkWell(
                onTap: onOpen,
                splashFactory: NoSplash.splashFactory,
                highlightColor: p.surface,
                hoverColor: p.surface,
                focusColor: p.focus,
                child: Container(
                  constraints: const BoxConstraints(
                    minHeight: NamoSizes.touchTarget,
                  ),
                  alignment: AlignmentDirectional.centerStart,
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: namoText(titleFamily, size: 18, color: p.text),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: namoText(
                            NamoFonts.english,
                            size: 14,
                            color: p.textQuiet,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: removeLabel,
            color: p.textQuiet,
            constraints: const BoxConstraints(
              minWidth: NamoSizes.touchTarget,
              minHeight: NamoSizes.touchTarget,
            ),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}
