import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../content/model.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../design/widgets/page_header.dart';
import '../design/widgets/progress_line.dart';
import '../design/widgets/surface_card.dart';
import '../flows/flow_reading.dart';
import '../flows/flows.dart' show FlowsState, flowsProvider, isFlowId;
import '../reader/position_controller.dart';
import '../router.dart';
import 'card_art.dart';

/// Whether Home shows the Continue reading card: something was read, and
/// that reading is still there (in [library], or a flow in [flows] that
/// still has a section).
bool hasContinue(PositionState position, Library library, FlowsState flows) {
  final id = position.lastReadingId;
  if (id == null || position.byReading[id] == null) return false;
  final reading = resolveReading(library, flows, id);
  return reading != null && reading.sections.isNotEmpty;
}

/// Where the reader left off: the reading (or flow), the section and how far
/// through. Builds nothing until something was read, or if that reading is
/// no longer there (or is a flow with no sections).
class ContinueCard extends ConsumerWidget {
  const ContinueCard({super.key, required this.library});

  final Library library;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final position = ref.watch(positionProvider);
    final id = position.lastReadingId;
    final progress = id == null ? null : position.byReading[id];
    final reading = id == null
        ? null
        : resolveReading(library, ref.watch(flowsProvider), id);
    if (progress == null || reading == null || reading.sections.isEmpty) {
      return const SizedBox.shrink();
    }
    // A pirith has no section headings worth showing; its Roman name goes
    // second instead. A flow, even of pirith only, shows its section.
    final phrased = !isFlowId(reading.id) && reading.isPhrased;
    final category = library.categoryOf(reading.id);
    final section = phrased
        ? reading.titleRoman
        : reading.sections
              .where((s) => s.id == progress.position.sectionId)
              .firstOrNull
              ?.heading;
    // A heading the same as the title (an Introduction) gives the topic's
    // name instead.
    final heading = section == reading.title && category != null
        ? category.shortTitle ?? category.title
        : section;
    final percent = (progress.progress * 100).round();
    final categoryId = category?.id ?? '';
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
