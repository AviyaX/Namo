import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../design/marks.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../design/widgets/buttons.dart';
import '../design/widgets/page_header.dart';
import '../design/widgets/pressable.dart';
import '../design/widgets/surface_card.dart';
import '../router.dart';
import '../saved/saved.dart';
import '../settings/reading_language.dart';
import 'today.dart';

/// Today's verse in the chosen languages (the Pali when none of them has
/// it), its topic and section heading, a bookmark button and a way to read
/// it in its place.
class GathaCard extends ConsumerWidget {
  const GathaCard({
    super.key,
    required this.pick,
    required this.selection,
    required this.topicTitle,
    this.fontScale = 1.0,
    this.lineSpacing = 1.6,
  });

  final GathaPick pick;
  final LanguageSelection selection;

  /// The title of the topic the verse is from; empty when it has none.
  final String topicTitle;

  /// The reader's text size and line spacing, so the verse looks here as it
  /// does there.
  final double fontScale;
  final double lineSpacing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = NamoPalette.of(context);
    final texts = gathaTexts(pick.verse, selection);
    final bookmarked = ref.watch(
      savedProvider.select((s) => s.isBookmarked(pick.reading.id, pick.section.id)),
    );
    final heading = pick.section.heading;
    return SurfaceCard(
      framed: true,
      child: Stack(
        children: [
          PositionedDirectional(
            end: -NamoSpace.md,
            top: 0,
            bottom: 0,
            width: 120,
            child: const IgnorePointer(child: LeafWatermark()),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const NamoMarkIcon(NamoMark.lotus, size: 20),
                  const SizedBox(width: NamoSpace.sm),
                  const Expanded(child: Overline("Today's gatha", accent: true)),
                  NamoIconButton(
                    key: const ValueKey('gatha-bookmark'),
                    icon: Symbols.bookmark_rounded,
                    filled: bookmarked,
                    color: bookmarked ? p.gold : p.textSecondary,
                    tooltip: bookmarked ? 'Remove bookmark' : 'Bookmark this section',
                    onPressed: () => ref
                        .read(savedProvider.notifier)
                        .toggleBookmark(pick.reading.id, pick.section.id),
                  ),
                ],
              ),
              const SizedBox(height: NamoSpace.sm),
              for (final (i, (language, text)) in texts.indexed) ...[
                if (i > 0) const SizedBox(height: NamoSpace.md),
                Text(
                  text,
                  key: ValueKey('gatha-text-$i'),
                  style: readingStyle(
                    language,
                    fontScale: fontScale,
                    lineSpacing: lineSpacing,
                    color: i == 0 ? p.text : p.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: NamoSpace.md),
              Container(width: 32, height: 2, color: p.gold),
              const SizedBox(height: NamoSpace.sm),
              Text(
                topicTitle.isEmpty ? heading : '$topicTitle · $heading',
                style: NamoType.caption(p.textSecondary),
              ),
              const SizedBox(height: NamoSpace.md),
              _ReadInContext(
                onPressed: () => context.go(
                  Routes.reader(
                    pick.reading.id,
                    sectionId: pick.section.id,
                    from: ReaderFrom.home,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The "Read in context" pill: a thin outline, a book, the words, an arrow.
class _ReadInContext extends StatelessWidget {
  const _ReadInContext({required this.onPressed});

  final VoidCallback onPressed;

  static const _shape = BorderRadius.all(Radius.circular(NamoSizes.touchTarget / 2));

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    Icon glyph(IconData icon) =>
        Icon(icon, size: NamoSizes.iconSmall, weight: 300, color: p.text);
    return Pressable(
      onTap: onPressed,
      borderRadius: _shape,
      semanticLabel: 'Read in context',
      excludeChildSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: NamoSizes.touchTarget),
        padding: const EdgeInsets.symmetric(
            horizontal: NamoSpace.lg, vertical: NamoSpace.sm),
        decoration: BoxDecoration(
          borderRadius: _shape,
          border: Border.all(color: p.textSecondary),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            glyph(Symbols.menu_book_rounded),
            const SizedBox(width: NamoSpace.sm),
            Flexible(
              child: Text('Read in context', style: NamoType.label(p.text)),
            ),
            const SizedBox(width: NamoSpace.sm),
            glyph(Symbols.arrow_right_alt_rounded),
          ],
        ),
      ),
    );
  }
}
