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
import '../design/widgets/surface_card.dart';
import '../router.dart';
import 'flow_reading.dart';
import 'flows.dart';
import 'new_flow_sheet.dart';

/// The Library's "My flows": the person's flows in the order they were made,
/// each opening in the reader and with a button to edit it, and a way to
/// make a new one. With no flows it is a card that says what a flow is.
class MyFlowsPart extends ConsumerWidget {
  const MyFlowsPart({super.key, required this.library});

  final Library library;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = NamoPalette.of(context);
    final flows = ref.watch(flowsProvider).flows;
    final newFlow = QuietButton(
      key: const ValueKey('new-flow'),
      label: 'New flow',
      icon: Symbols.add_rounded,
      onPressed: () => showNewFlowSheet(context, library: library),
    );
    return Column(
      key: const ValueKey('my-flows'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: NamoSpace.lg),
          child: Overline('My flows', header: true),
        ),
        const SizedBox(height: NamoSpace.sm),
        if (flows.isEmpty)
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Make your own flow', style: NamoType.cardTitle(p.text)),
                const SizedBox(height: NamoSpace.xs),
                Text(
                  'Choose the sections you chant, in your order.',
                  style: NamoType.body(p.textSecondary),
                ),
                const SizedBox(height: NamoSpace.lg),
                newFlow,
              ],
            ),
          )
        else ...[
          for (final flow in flows)
            ListRow(
              key: ValueKey('flow-open-${flow.id}'),
              leading: const _FlowMark(),
              title: flow.name,
              caption: sectionCount(liveRefs(flow, library).length),
              onTap: () => context.go(Routes.reader(flow.id)),
              action: NamoIconButton(
                key: ValueKey('flow-edit-${flow.id}'),
                icon: Symbols.edit_rounded,
                tooltip: 'Edit flow',
                color: p.textSecondary,
                onPressed: () => context.go(Routes.flowEditor(flow.id)),
              ),
            ),
          const SizedBox(height: NamoSpace.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: NamoSpace.lg),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: newFlow,
            ),
          ),
        ],
      ],
    );
  }
}

/// A flow's square beside its name, the size of a topic's picture: the
/// quiet ground with a list mark in gold.
class _FlowMark extends StatelessWidget {
  const _FlowMark();

  static const _size = 56.0;

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    return SizedBox.square(
      dimension: _size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: p.backgroundAlt,
          borderRadius: BorderRadius.circular(NamoRadius.sm),
        ),
        child: Icon(
          Symbols.format_list_numbered_rounded,
          size: NamoSizes.icon,
          weight: 300,
          color: p.gold,
        ),
      ),
    );
  }
}
