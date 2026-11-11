import 'package:flutter/material.dart' hide Flow;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../content/content_repository.dart';
import '../content/model.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../design/widgets/list_row.dart';
import '../design/widgets/page_header.dart';
import '../design/widgets/sheet_frame.dart';
import 'flow_name_sheet.dart' show FlowSheetScaffold, showFlowSheet;
import 'flow_reading.dart' show flowSectionId;
import 'flows.dart';

/// Every section of the library, each with a tick that says whether it is in
/// flow [flowId]; a tick adds the section to the end of the flow, and taking
/// it off removes it.
Future<void> showAddSectionsSheet(
  BuildContext context, {
  required String flowId,
}) => showFlowSheet<void>(context, (_) => _AddSectionsSheet(flowId: flowId));

/// One line of the sheet: a category's title, a reading's title, or a
/// section that can be ticked.
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

/// The lines for [library], in library order. A reading with one section is
/// one line under the reading's title (and its Roman title); a reading with
/// several has its title over them when its category has other readings.
List<_Line> _lines(Library library) => [
  for (final c in library.categories) ...[
    _GroupLabel(c.title),
    for (final r in c.readings)
      if (r.sections.length == 1)
        _SectionLine(
          ref: FlowRef(readingId: r.id, sectionId: r.sections.single.id),
          number: c.numberOf(r.id),
          title: r.title,
          subtitle: r.titleRoman,
        )
      else ...[
        if (c.readings.length > 1) _ReadingLabel(r.title),
        for (final s in r.sections)
          _SectionLine(
            ref: FlowRef(readingId: r.id, sectionId: s.id),
            number: s.number,
            title: s.heading,
          ),
      ],
  ],
];

class _AddSectionsSheet extends ConsumerWidget {
  const _AddSectionsSheet({required this.flowId});

  final String flowId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(libraryProvider).value;
    final flow = ref.watch(flowsProvider).flow(flowId);
    final lines = library == null ? const <_Line>[] : _lines(library);
    final p = NamoPalette.of(context);
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
          final _SectionLine line => _tickRow(context, ref, flow, line),
        },
      ),
    );
  }

  Widget _tickRow(
    BuildContext context,
    WidgetRef ref,
    Flow? flow,
    _SectionLine line,
  ) {
    final p = NamoPalette.of(context);
    final ticked = flow?.sections.contains(line.ref) ?? false;
    final flows = ref.read(flowsProvider.notifier);
    return ListRow(
      key: ValueKey('add-tick-${flowSectionId(line.ref)}'),
      leading: Icon(
        ticked
            ? Symbols.check_box_rounded
            : Symbols.check_box_outline_blank_rounded,
        size: NamoSizes.icon,
        weight: 300,
        fill: ticked ? 1 : 0,
        color: ticked ? p.sage : p.textSecondary,
      ),
      number: line.number,
      title: line.title,
      titleFamily: NamoFonts.sinhala,
      subtitle: line.subtitle,
      subtitleFamily: NamoFonts.romanPali,
      checked: ticked,
      onTap: () => ticked
          ? flows.remove(flowId, line.ref)
          : flows.add(flowId, line.ref),
    );
  }
}
