import 'package:flutter/material.dart' hide Flow;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../content/content_repository.dart';
import '../content/model.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../design/widgets/empty_state.dart';
import '../design/widgets/list_row.dart';
import '../design/widgets/page_header.dart';
import '../design/widgets/sheet_frame.dart';
import 'flow_name_sheet.dart' show FlowSheetScaffold, showFlowSheet;
import 'flow_reading.dart' show flowSectionId;
import 'flows.dart';

/// The sections of the library that are not yet in flow [flowId]. Tapping one
/// adds it to the end of the flow and takes it off this list; a section is
/// taken out of a flow in the editor.
Future<void> showAddSectionsSheet(
  BuildContext context, {
  required String flowId,
}) => showFlowSheet<void>(context, (_) => _AddSectionsSheet(flowId: flowId));

/// One line of the sheet: a category's title, a reading's title, or a
/// section that can be added.
sealed class _Line {
  const _Line();
}

class _GroupLabel extends _Line {
  const _GroupLabel(this.title);
  final String title;
}

class _ReadingLabel extends _Line {
  const _ReadingLabel(this.title);
  final String title;
}

class _SectionLine extends _Line {
  const _SectionLine({
    required this.ref,
    required this.number,
    required this.title,
    this.subtitle,
  });

  final FlowRef ref;
  final int number;
  final String title;
  final String? subtitle;
}

/// The lines for [library] without the sections in [taken], in library
/// order. A reading with one section is one line under the reading's title
/// (and its Roman title); a reading with several has its title over them when
/// its category has other readings. A category or reading with nothing left
/// to add is left out.
List<_Line> _lines(Library library, Set<FlowRef> taken) {
  final lines = <_Line>[];
  for (final c in library.categories) {
    final inCategory = <_Line>[];
    for (final r in c.readings) {
      if (r.sections.length == 1) {
        final ref = FlowRef(readingId: r.id, sectionId: r.sections.single.id);
        if (!taken.contains(ref)) {
          inCategory.add(
            _SectionLine(
              ref: ref,
              number: c.numberOf(r.id),
              title: r.title,
              subtitle: r.titleRoman,
            ),
          );
        }
        continue;
      }
      final left = [
        for (final s in r.sections)
          if (!taken.contains(FlowRef(readingId: r.id, sectionId: s.id)))
            _SectionLine(
              ref: FlowRef(readingId: r.id, sectionId: s.id),
              number: s.number,
              title: s.heading,
            ),
      ];
      if (left.isEmpty) continue;
      if (c.readings.length > 1) inCategory.add(_ReadingLabel(r.title));
      inCategory.addAll(left);
    }
    if (inCategory.isEmpty) continue;
    lines
      ..add(_GroupLabel(c.title))
      ..addAll(inCategory);
  }
  return lines;
}

class _AddSectionsSheet extends ConsumerWidget {
  const _AddSectionsSheet({required this.flowId});

  final String flowId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(libraryProvider).value;
    final flow = ref.watch(flowsProvider).flow(flowId);
    final lines = library == null
        ? const <_Line>[]
        : _lines(library, {...?flow?.sections});
    final p = NamoPalette.of(context);
    if (library != null && lines.isEmpty) {
      return const FlowSheetScaffold(
        frame: SheetFrame(
          title: 'Add sections',
          children: [
            EmptyState(
              key: ValueKey('add-none-left'),
              icon: Symbols.playlist_add_check_rounded,
              title: 'Every section is already in this flow.',
            ),
          ],
        ),
      );
    }
    return FlowSheetScaffold(
      frame: SheetFrame.builder(
        title: 'Add sections',
        itemCount: lines.length,
        itemBuilder: (context, i) => switch (lines[i]) {
          _GroupLabel(:final title) => Padding(
            padding: EdgeInsets.fromLTRB(
              NamoSpace.lg,
              i == 0 ? 0 : NamoSpace.xl,
              NamoSpace.lg,
              NamoSpace.xs,
            ),
            child: Overline(title, header: true),
          ),
          _ReadingLabel(:final title) => Padding(
            padding: const EdgeInsets.fromLTRB(
              NamoSpace.lg,
              NamoSpace.lg,
              NamoSpace.lg,
              NamoSpace.xs,
            ),
            child: Semantics(
              header: true,
              child: Text(title, style: NamoType.readingTitle(p.text)),
            ),
          ),
          final _SectionLine line => _addRow(context, ref, line),
        },
      ),
    );
  }

  Widget _addRow(BuildContext context, WidgetRef ref, _SectionLine line) {
    final p = NamoPalette.of(context);
    return ListRow(
      key: ValueKey('add-tick-${flowSectionId(line.ref)}'),
      leading: Icon(
        Symbols.add_rounded,
        size: NamoSizes.icon,
        weight: 300,
        color: p.textSecondary,
      ),
      number: line.number,
      title: line.title,
      titleFamily: NamoFonts.sinhala,
      subtitle: line.subtitle,
      subtitleFamily: NamoFonts.romanPali,
      onTap: () => ref.read(flowsProvider.notifier).add(flowId, line.ref),
    );
  }
}
