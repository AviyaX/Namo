import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design/tokens.dart';
import '../design/typography.dart';
import '../design/widgets/buttons.dart';
import '../design/widgets/page_header.dart';
import '../design/widgets/surface_card.dart';
import '../router.dart';
import '../settings/reading_language.dart';
import 'today.dart';

/// Today's verse in the chosen languages (the Pali when none of them has
/// it), its section heading and a way to read it in its place.
class GathaCard extends StatelessWidget {
  const GathaCard({
    super.key,
    required this.pick,
    required this.selection,
    this.fontScale = 1.0,
    this.lineSpacing = 1.6,
  });

  final GathaPick pick;
  final LanguageSelection selection;

  /// The reader's text size and line spacing, so the verse looks here as it
  /// does there.
  final double fontScale;
  final double lineSpacing;

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    final texts = gathaTexts(pick.verse, selection);
    return SurfaceCard(
      leadingLine: p.gold,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Overline("Today's gatha"),
          const SizedBox(height: NamoSpace.md),
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
          Text(pick.section.heading, style: NamoType.caption(p.textSecondary)),
          const SizedBox(height: NamoSpace.sm),
          TextAction(
            label: 'Read in context',
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
    );
  }
}
