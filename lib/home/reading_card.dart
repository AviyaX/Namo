import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../content/model.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../router.dart';
import 'card_art.dart';

/// A category on Home: a 16:9 picture slot, then the title, the Sinhala
/// subtitle and the number of sections. One button for the whole card.
///
/// A category with one reading opens that reading (the reader returns to the
/// remembered place); one with several opens the Library with it open.
class ReadingCard extends StatelessWidget {
  const ReadingCard({super.key, required this.category});

  final Category category;

  int get _sections =>
      category.readings.fold(0, (sum, r) => sum + r.sections.length);

  String get _count => _sections == 1 ? '1 section' : '$_sections sections';

  void _open(BuildContext context) => context.go(
    category.readings.length == 1
        ? Routes.reader(category.readings.single.id, from: ReaderFrom.home)
        : Routes.category(category.id),
  );

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    return Semantics(
      button: true,
      container: true,
      excludeSemantics: true,
      label: '${category.title}, ${category.subtitle}, $_count',
      onTap: () => _open(context),
      child: Material(
        color: p.background,
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          side: BorderSide(color: p.divider, width: 1),
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: CardArt(categoryId: category.id),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.title,
                        style: namoText(
                          NamoFonts.english,
                          size: 18,
                          color: p.text,
                        ),
                      ),
                      Text(
                        category.subtitle,
                        style: namoText(
                          NamoFonts.sinhala,
                          size: 14,
                          color: p.textQuiet,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _count,
                        style: namoText(
                          NamoFonts.english,
                          size: 14,
                          color: p.textQuiet,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Above the picture, so hover, focus and press tint all of it.
            Positioned.fill(
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: () => _open(context),
                  splashFactory: NoSplash.splashFactory,
                  highlightColor: p.heading.withValues(alpha: 0.10),
                  hoverColor: p.heading.withValues(alpha: 0.08),
                  focusColor: p.focus,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
