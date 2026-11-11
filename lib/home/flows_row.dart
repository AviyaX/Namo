import 'package:flutter/material.dart' hide Flow;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../content/model.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../design/widgets/surface_card.dart';
import '../flows/flow_reading.dart';
import '../flows/flows.dart';
import '../router.dart';
import 'section_strip.dart';

/// The width of one flow card.
const _cardWidth = 168.0;

/// Home's "Your flows": the person's flows in the order they were made, as
/// small cards in a row that scrolls sideways; each opens the flow in the
/// reader (which goes to the flow's remembered place by itself). A flow with
/// no sections left is listed too. Builds nothing when there are no flows.
class FlowsRow extends ConsumerWidget {
  const FlowsRow({super.key, required this.library});

  final Library library;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flows = ref.watch(flowsProvider).flows;
    if (flows.isEmpty) return const SizedBox.shrink();
    final p = NamoPalette.of(context);
    return Column(
      key: const ValueKey('home-flows'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text('Your flows', style: NamoType.sectionTitle(p.text)),
        ),
        const SizedBox(height: NamoSpace.md),
        EqualHeightRow(
          children: [
            for (final flow in flows)
              _FlowCard(
                key: ValueKey('home-flow-${flow.id}'),
                name: flow.name,
                count: sectionCount(liveRefs(flow, library).length),
                onTap: () => context.go(
                  Routes.reader(flow.id, from: ReaderFrom.home),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _FlowCard extends StatelessWidget {
  const _FlowCard({
    super.key,
    required this.name,
    required this.count,
    required this.onTap,
  });

  final String name;
  final String count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    return SizedBox(
      width: _cardWidth,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: NamoSizes.touchTarget),
        child: TappableCard(
          onTap: onTap,
          semanticLabel: '$name, $count',
          child: SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: NamoType.cardTitle(p.text),
                ),
                const SizedBox(height: NamoSpace.xs),
                Text(count, style: NamoType.caption(p.textSecondary)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
