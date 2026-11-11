import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../content/model.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../design/widgets/page_header.dart';
import '../design/widgets/progress_line.dart';
import '../design/widgets/surface_card.dart';
import '../reader/position_controller.dart';
import '../router.dart';
import 'card_art.dart';

/// Whether Home shows the Continue reading card: something was read, and
/// that reading is still in [library].
bool hasContinue(PositionState position, Library library) {
  final id = position.lastReadingId;
  return id != null &&
      position.byReading[id] != null &&
      library.reading(id) != null;
}

/// Where the reader left off: the reading, the section and how far through.
/// Builds nothing until something was read, or if that reading is no longer
/// there.
class ContinueCard extends ConsumerWidget {
  const ContinueCard({super.key, required this.library});

  final Library library;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final position = ref.watch(positionProvider);
    final id = position.lastReadingId;
    final progress = id == null ? null : position.byReading[id];
    final reading = id == null ? null : library.reading(id);
    if (progress == null || reading == null) return const SizedBox.shrink();
    // A pirith has no section headings worth showing; its Roman name goes
    // second instead.
    final phrased = reading.isPhrased;
    final heading = phrased
        ? reading.titleRoman
        : reading.sections
              .where((s) => s.id == progress.position.sectionId)
              .firstOrNull
              ?.heading;
    final percent = (progress.progress * 100).round();
    final categoryId = library.categoryOf(reading.id)?.id ?? '';
    final p = NamoPalette.of(context);
    return SurfaceCard(
      onTap: () => context.go(Routes.reader(reading.id, from: ReaderFrom.home)),
      semanticLabel: [
        'Continue reading',
        reading.title,
        ?heading,
        '$percent percent',
      ].join(', '),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TopicThumbnail(categoryId: categoryId),
          const SizedBox(width: NamoSpace.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Overline('Continue reading'),
                const SizedBox(height: NamoSpace.xs),
                Text(
                  reading.title,
                  style: phrased
                      ? NamoType.sectionTitleSinhala(p.text).copyWith(fontSize: 18)
                      : NamoType.cardTitle(p.text),
                ),
                if (heading != null)
                  Text(
                    heading,
                    style: phrased
                        ? NamoType.romanName(p.textSecondary)
                        : NamoType.caption(p.textSecondary),
                  ),
                const SizedBox(height: NamoSpace.md),
                Row(
                  children: [
                    Expanded(child: ProgressLine(value: progress.progress)),
                    const SizedBox(width: NamoSpace.md),
                    Text('$percent%', style: NamoType.caption(p.textSecondary)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
