import 'dart:math' as math;

import 'package:flutter/material.dart' hide Flow;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../content/model.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../design/widgets/buttons.dart';
import '../design/widgets/list_row.dart';
import '../design/widgets/page_header.dart';
import '../design/widgets/sheet_frame.dart';
import '../router.dart';
import 'flow_name_sheet.dart';
import 'flows.dart';

/// Asks for a new flow's name and what it starts from ("Nothing", or every
/// section of one reading). On "Create" the flow is made and its editor
/// opens; a dismissed sheet makes nothing.
Future<void> showNewFlowSheet(
  BuildContext context, {
  required Library library,
}) async {
  final choice = await showFlowSheet<({String name, Reading? from})>(
    context,
    (_) => _NewFlowSheet(library: library),
  );
  if (choice == null || !context.mounted) return;
  final flow = ProviderScope.containerOf(
    context,
    listen: false,
  ).read(flowsProvider.notifier).create(choice.name, from: choice.from);
  context.go(Routes.flowEditor(flow.id));
}

/// One line of the "Start from" list: a category's title or a reading.
sealed class _Line {
  const _Line();
}

class _Nothing extends _Line {
  const _Nothing();
}

class _GroupLabel extends _Line {
  const _GroupLabel(this.title);
  final String title;
}

class _ReadingLine extends _Line {
  const _ReadingLine(this.reading);
  final Reading reading;
}

List<_Line> _lines(Library library) => [
  const _Nothing(),
  for (final c in library.categories) ...[
    _GroupLabel(c.title),
    for (final r in c.readings) _ReadingLine(r),
  ],
];

class _NewFlowSheet extends StatefulWidget {
  const _NewFlowSheet({required this.library});

  final Library library;

  @override
  State<_NewFlowSheet> createState() => _NewFlowSheetState();
}

class _NewFlowSheetState extends State<_NewFlowSheet> {
  final _name = TextEditingController();

  /// The reading the flow starts from; null is "Nothing".
  Reading? _from;

  late final _choices = _lines(widget.library);

  /// The height of the "Start from" list, which scrolls inside the sheet.
  static const _minListHeight = 176.0, _maxListHeight = 360.0;
  static const _listShare = 0.4;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _create() => Navigator.of(context).pop((name: _name.text, from: _from));

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    final height = MediaQuery.sizeOf(context).height;
    final listHeight = math.min(
      _maxListHeight,
      math.max(_minListHeight, height * _listShare),
    );
    const radius = BorderRadius.all(Radius.circular(NamoRadius.sm));
    return FlowSheetScaffold(
      frame: SheetFrame(
        title: 'New flow',
        children: [
          FlowNameField(controller: _name, hint: 'Morning'),
          const SizedBox(height: NamoSpace.lg),
          const Overline('Start from', header: true),
          const SizedBox(height: NamoSpace.sm),
          SizedBox(
            height: listHeight,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: radius,
                border: Border.all(color: p.border),
              ),
              child: ClipRRect(
                borderRadius: radius,
                child: ListView.builder(
                  key: const ValueKey('new-flow-choices'),
                  // The sheet's own scroll view is the primary one.
                  primary: false,
                  padding: const EdgeInsets.symmetric(vertical: NamoSpace.xs),
                  itemCount: _choices.length,
                  itemBuilder: (context, i) => switch (_choices[i]) {
                    _Nothing() => _choice(
                      key: 'start-from-nothing',
                      title: 'Nothing',
                      reading: null,
                    ),
                    _GroupLabel(:final title) => Padding(
                      padding: const EdgeInsets.fromLTRB(
                        NamoSpace.lg,
                        NamoSpace.lg,
                        NamoSpace.lg,
                        NamoSpace.xs,
                      ),
                      child: Overline(title, header: true),
                    ),
                    _ReadingLine(:final reading) => _choice(
                      key: 'start-from-${reading.id}',
                      title: reading.title,
                      subtitle: reading.titleRoman,
                      reading: reading,
                    ),
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: NamoSpace.lg),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: PrimaryButton(
              key: const ValueKey('new-flow-create'),
              label: 'Create',
              onPressed: _create,
            ),
          ),
        ],
      ),
    );
  }

  /// A row of the single-choice list; [reading] null is "Nothing".
  Widget _choice({
    required String key,
    required String title,
    String? subtitle,
    required Reading? reading,
  }) {
    final p = NamoPalette.of(context);
    final chosen = _from?.id == reading?.id;
    return ListRow(
      key: ValueKey(key),
      leading: Icon(
        chosen
            ? Symbols.radio_button_checked_rounded
            : Symbols.radio_button_unchecked_rounded,
        size: NamoSizes.icon,
        weight: 300,
        color: chosen ? p.sage : p.textSecondary,
      ),
      title: title,
      titleFamily: NamoFonts.sinhala,
      subtitle: subtitle,
      subtitleFamily: NamoFonts.romanPali,
      checked: chosen,
      inMutuallyExclusiveGroup: true,
      onTap: () => setState(() => _from = reading),
    );
  }
}
