import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../design/tokens.dart';
import '../design/typography.dart';
import '../design/widgets/buttons.dart';
import '../design/widgets/not_found.dart';
import '../design/widgets/pressable.dart';
import '../router.dart';
import 'bana_catalogue.dart';
import 'bana_progress.dart';
import 'bana_repository.dart';

/// One series: where to carry on from, then every part in order.
class BanaSeriesScreen extends ConsumerWidget {
  const BanaSeriesScreen({super.key, required this.id});

  final String id;

  void _back(BuildContext context) =>
      context.canPop() ? context.pop() : context.go(Routes.bana);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = NamoPalette.of(context);
    final cat = ref.watch(banaCatalogueProvider).value;
    final progress = ref.watch(banaProgressProvider);
    final width = MediaQuery.sizeOf(context).width;
    final column = width >= NamoSizes.wideBreakpoint
        ? NamoSizes.homeColumn
        : NamoSizes.readingColumn;
    final margin = ((width - column) / 2).clamp(
      NamoSizes.pageMargin(width),
      double.infinity,
    );
    final inset = MediaQuery.paddingOf(context);

    final series = cat?.seriesById(id);
    if (cat != null && series == null) return const NotFoundScreen();

    final back = Align(
      alignment: AlignmentDirectional.centerStart,
      child: NamoIconButton(
        icon: Symbols.arrow_back_rounded,
        tooltip: 'Back',
        onPressed: () => _back(context),
      ),
    );

    Widget body;
    if (cat == null || series == null) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      final parts = cat.partsOf(id);
      final lastAt = parts.indexWhere((b) => b.id == progress[id]);
      final target = parts.isEmpty ? null : parts[lastAt < 0 ? 0 : lastAt];
      final topic = cat.topics
          .where((t) => series.topics.contains(t.id))
          .firstOrNull;
      final speaker =
          cat.speakers.where((s) => s.id == series.speaker).firstOrNull?.name ??
          series.speaker;
      final channel = cat.channels[series.channel]?.name ?? series.channel;
      final kicker = [
        'SERIES',
        '${series.parts.length} PARTS',
        ?topic?.si,
      ].join(' · ');
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(kicker, style: NamoType.overline(p.gold)),
          const SizedBox(height: NamoSpace.sm),
          Semantics(
            header: true,
            child: Text(series.title, style: NamoType.screenTitle(p.text)),
          ),
          const SizedBox(height: NamoSpace.sm),
          Text(speaker, style: NamoType.body(p.textSecondary)),
          const SizedBox(height: NamoSpace.xs),
          Text(
            'From YouTube · $channel',
            style: NamoType.caption(p.textSecondary),
          ),
          if (target != null) ...[
            const SizedBox(height: NamoSpace.lg),
            PrimaryButton(
              key: const ValueKey('bana-continue'),
              label: lastAt < 0
                  ? 'Start: part 1'
                  : 'Continue: part ${lastAt + 1}',
              icon: Symbols.play_arrow_rounded,
              onPressed: () => context.push(Routes.banaPlay(target.id)),
            ),
          ],
          const SizedBox(height: NamoSpace.lg),
          for (var i = 0; i < parts.length; i++)
            _PartRow(
              key: ValueKey('bana-part-${parts[i].id}'),
              number: i + 1,
              bana: parts[i],
              current: i == lastAt,
              onTap: () => context.push(Routes.banaPlay(parts[i].id)),
            ),
        ],
      );
    }

    return Scaffold(
      key: const ValueKey('screen-bana-series'),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              margin + inset.left,
              inset.top + NamoSpace.lg,
              margin + inset.right,
              inset.bottom + NamoSpace.xl,
            ),
            sliver: SliverList.list(
              children: [
                back,
                const SizedBox(height: NamoSpace.sm),
                body,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A part: number disc, title and length. The last opened one is tinted.
class _PartRow extends StatelessWidget {
  const _PartRow({
    super.key,
    required this.number,
    required this.bana,
    required this.current,
    required this.onTap,
  });

  final int number;
  final Bana bana;
  final bool current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    const radius = BorderRadius.all(Radius.circular(NamoRadius.sm));
    const disc = NamoSizes.touchTarget - NamoSpace.sm;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: NamoSpace.xs),
      child: Pressable(
        onTap: onTap,
        borderRadius: radius,
        selected: current,
        semanticLabel: 'Part $number, ${bana.title}, ${bana.lengthLabel}',
        excludeChildSemantics: true,
        child: Container(
          constraints: const BoxConstraints(minHeight: NamoSizes.touchTarget),
          padding: const EdgeInsets.all(NamoSpace.sm),
          decoration: BoxDecoration(
            color: current ? p.backgroundAlt : p.backgroundAlt.withAlpha(0),
            borderRadius: radius,
            border: Border.all(color: current ? p.sage : p.border),
          ),
          child: Row(
            children: [
              Container(
                width: disc,
                height: disc,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: current ? p.sage : p.sage.withAlpha(0),
                  border: Border.all(color: current ? p.sage : p.border),
                ),
                child: Text(
                  '$number',
                  style: NamoType.label(current ? p.onSage : p.textSecondary),
                ),
              ),
              const SizedBox(width: NamoSpace.md),
              Expanded(child: Text(bana.title, style: NamoType.body(p.text))),
              const SizedBox(width: NamoSpace.sm),
              Text(bana.lengthLabel, style: NamoType.caption(p.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}
