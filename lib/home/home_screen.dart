import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../content/content_repository.dart';
import '../content/model.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../library/library_gate.dart';
import '../reader/position_controller.dart';
import '../router.dart';
import 'reading_card.dart';

/// The width of the Home column on wide screens: room for a few cards a row.
const _wideColumn = 1040.0;

/// A wide card is between these widths.
const _cardMin = 320.0, _cardMax = 360.0, _gap = 16.0;

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key = const ValueKey('screen-home')});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = NamoPalette.of(context);
    final wide = MediaQuery.sizeOf(context).width >= NamoSizes.wideBreakpoint;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
                maxWidth: wide ? _wideColumn : NamoSizes.readingColumn),
            child: ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
                  child: Semantics(
                    header: true,
                    child: Text('Namo',
                        style: namoText(NamoFonts.english,
                            size: 32, color: p.heading, weight: 600)),
                  ),
                ),
                LibraryGate(
                  builder: (context, library) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _ContinueReading(),
                      _Cards(categories: library.categories, wide: wide),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The category cards: one a row, as wide as the column, on a phone; a
/// wrapping grid of cards [_cardMin]-[_cardMax] wide, from the left edge, on
/// a wide screen.
class _Cards extends StatelessWidget {
  const _Cards({required this.categories, required this.wide});

  final List<Category> categories;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: LayoutBuilder(
        builder: (context, box) {
          final width = box.maxWidth;
          final double cardWidth;
          if (wide) {
            final perRow =
                ((width + _gap) / (_cardMin + _gap)).floor().clamp(1, 1000);
            cardWidth =
                ((width - (perRow - 1) * _gap) / perRow).clamp(_cardMin, _cardMax);
          } else {
            cardWidth = width;
          }
          return Wrap(
            spacing: _gap,
            runSpacing: _gap,
            children: [
              for (final c in categories)
                SizedBox(width: cardWidth, child: ReadingCard(category: c)),
            ],
          );
        },
      ),
    );
  }
}

/// Where the reader left off: the reading, the section and how far through.
/// Absent until something was read, or if that reading is no longer there.
class _ContinueReading extends ConsumerWidget {
  const _ContinueReading();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final position = ref.watch(positionProvider);
    final library = ref.watch(libraryProvider).value;
    final id = position.lastReadingId;
    final progress = id == null ? null : position.byReading[id];
    final reading = id == null ? null : library?.reading(id);
    if (progress == null || reading == null) return const SizedBox.shrink();
    final heading = reading.sections
        .where((s) => s.id == progress.position.sectionId)
        .firstOrNull
        ?.heading;
    final p = NamoPalette.of(context);
    return Semantics(
      button: true,
      container: true,
      excludeSemantics: true,
      label: [
        'Continue reading',
        reading.title,
        ?heading,
        '${(progress.progress * 100).round()} percent',
      ].join(', '),
      onTap: () => context.go(Routes.reader(reading.id)),
      child: InkWell(
        onTap: () => context.go(Routes.reader(reading.id)),
        splashFactory: NoSplash.splashFactory,
        highlightColor: p.surface,
        hoverColor: p.surface,
        focusColor: p.focus,
        child: Container(
          constraints: const BoxConstraints(minHeight: NamoSizes.touchTarget),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: p.divider, width: 1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Continue reading',
                style: namoText(
                  NamoFonts.english,
                  size: 14,
                  color: p.textQuiet,
                  weight: 600,
                ),
              ),
              Text(
                reading.title,
                style: namoText(NamoFonts.english, size: 18, color: p.text),
              ),
              if (heading != null)
                Text(
                  heading,
                  style: namoText(
                    NamoFonts.sinhala,
                    size: 14,
                    color: p.textQuiet,
                  ),
                ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: progress.progress,
                minHeight: 2,
                color: p.accent,
                backgroundColor: p.divider,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
