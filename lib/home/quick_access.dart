import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../content/model.dart';
import '../design/marks.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../design/widgets/surface_card.dart';
import '../router.dart';
import 'card_row.dart';

/// The Quick Access cards: an English label, the section of the topic's
/// first reading it opens, and its mark.
const quickAccess = [
  (label: 'Namaskara', sectionId: 's01', mark: NamoMark.palms),
  (label: 'Tisarana', sectionId: 's02', mark: NamoMark.wheel),
  (label: 'Pancha Sila', sectionId: 's03', mark: NamoMark.lotusBud),
  (label: 'Buddha Guna', sectionId: 's04', mark: NamoMark.seated),
];

typedef QuickAccessEntry = ({String label, String sectionId, NamoMark mark});

/// The [quickAccess] entries whose section is in [category]'s first reading,
/// each with that section. Empty when the topic has no readings.
List<(QuickAccessEntry, Section)> quickAccessCards(Category category) {
  final reading = category.readings.firstOrNull;
  if (reading == null) return const [];
  return [
    for (final e in quickAccess)
      if (reading.sections.where((s) => s.id == e.sectionId).firstOrNull
          case final section?)
        (e, section),
  ];
}

/// Four columns need a row at least this wide (a 360 px phone less its
/// margins).
const _fourColumnsFrom = 328.0;

const _gap = NamoSpace.sm;
const _padding = EdgeInsets.symmetric(
  horizontal: NamoSpace.sm,
  vertical: NamoSpace.lg,
);

/// Home's "Quick Access": a card for each [quickAccessCards] entry of
/// [category], opening the reader at its section, under a title with a "See
/// all" that opens the topic in the Library. Builds nothing when no entry's
/// section is there.
///
/// Four columns when the row is at least 328 wide, else two; fewer when a
/// word of a label or heading (at the device's text size) would not fit its
/// card, so no word is ever broken. Each row of cards is as tall as its
/// tallest.
class QuickAccess extends StatelessWidget {
  const QuickAccess({super.key, required this.category});

  final Category category;

  @override
  Widget build(BuildContext context) {
    final reading = category.readings.firstOrNull;
    final cards = quickAccessCards(category);
    if (reading == null || cards.isEmpty) return const SizedBox.shrink();
    return Column(
      key: const ValueKey('home-quick-access'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HomeBlockTitle(
          'Quick Access',
          onSeeAll: () => context.go(Routes.category(category.id)),
        ),
        const SizedBox(height: NamoSpace.md),
        LayoutBuilder(
          builder: (context, box) {
            final columns = _columns(context, box.maxWidth, cards);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var start = 0; start < cards.length; start += columns) ...[
                  if (start > 0) const SizedBox(height: _gap),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = start; i < start + columns; i++) ...[
                          if (i > start) const SizedBox(width: _gap),
                          Expanded(
                            child: i < cards.length
                                ? _QuickCard(
                                    entry: cards[i].$1,
                                    section: cards[i].$2,
                                    onTap: () => context.go(
                                      Routes.reader(
                                        reading.id,
                                        sectionId: cards[i].$2.id,
                                        from: ReaderFrom.home,
                                      ),
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

/// 4, 2 or 1: the most columns (four only from [_fourColumnsFrom]) in which
/// every word of every card fits on a line of its card.
int _columns(
  BuildContext context,
  double width,
  List<(QuickAccessEntry, Section)> cards,
) {
  final scaler = MediaQuery.textScalerOf(context);
  final p = NamoPalette.of(context);
  final labelStyle = _labelStyle(p), headingStyle = _headingStyle(p);
  var widest = 0.0;
  void measure(String text, TextStyle style) {
    for (final word in text.split(RegExp(r'\s+'))) {
      if (word.isEmpty) continue;
      final painter = TextPainter(
        text: TextSpan(text: word, style: style),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
      )..layout();
      if (painter.width > widest) widest = painter.width;
      painter.dispose();
    }
  }

  for (final (entry, section) in cards) {
    measure(entry.label, labelStyle);
    measure(section.heading, headingStyle);
  }
  bool fits(int n) =>
      (width - (n - 1) * _gap) / n - _padding.horizontal >= widest.ceil();
  if (width >= _fourColumnsFrom && fits(4)) return 4;
  return fits(2) ? 2 : 1;
}

TextStyle _labelStyle(NamoPalette p) => NamoType.cardTitle(p.text);
TextStyle _headingStyle(NamoPalette p) => NamoType.caption(p.textSecondary);

class _QuickCard extends StatelessWidget {
  const _QuickCard({
    required this.entry,
    required this.section,
    required this.onTap,
  });

  final QuickAccessEntry entry;
  final Section section;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: NamoSizes.touchTarget),
      child: TappableCard(
        radius: NamoRadius.card,
        onTap: onTap,
        semanticLabel: '${entry.label}, ${section.heading}',
        child: SurfaceCard(
          key: ValueKey('quick-${entry.sectionId}'),
          padding: _padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: NamoMarkIcon(entry.mark, size: 28, color: p.gold),
              ),
              const SizedBox(height: NamoSpace.sm),
              Text(
                entry.label,
                textAlign: TextAlign.center,
                style: _labelStyle(p),
              ),
              const SizedBox(height: NamoSpace.xs),
              Text(
                section.heading,
                textAlign: TextAlign.center,
                style: _headingStyle(p),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
