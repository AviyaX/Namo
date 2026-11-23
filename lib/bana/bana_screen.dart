import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../design/tokens.dart';
import '../design/typography.dart';
import '../design/widgets/app_shell.dart';
import '../design/widgets/page_header.dart';
import '../design/widgets/search_field.dart';
import '../router.dart';
import 'bana_catalogue.dart';
import 'bana_progress.dart';
import 'bana_repository.dart';
import 'bana_widgets.dart';

/// The Bana tab: YouTube dharma talks, narrowed by monk, topic and search.
class BanaScreen extends ConsumerStatefulWidget {
  const BanaScreen({super.key = const ValueKey('screen-bana')});

  @override
  ConsumerState<BanaScreen> createState() => _BanaScreenState();
}

class _BanaScreenState extends ConsumerState<BanaScreen> {
  final _query = TextEditingController();
  final _searchFocus = FocusNode();
  String? _speaker;
  String? _topic;

  @override
  void dispose() {
    _query.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _reset() {
    _searchFocus.unfocus();
    if (_query.text.isEmpty && _speaker == null && _topic == null) return;
    _query.clear();
    setState(() {
      _speaker = null;
      _topic = null;
    });
  }

  /// Choosing a monk drops a topic he has no bana in.
  void _pickSpeaker(BanaCatalogue cat, String? id) => setState(() {
    _speaker = id;
    if (_topic != null && !cat.topicsFor(id).contains(_topic)) _topic = null;
  });

  @override
  Widget build(BuildContext context) {
    ref.listen(tabPressedAgainProvider, (_, next) {
      if (next?.$1 == TabIndex.bana) _reset();
    });
    final p = NamoPalette.of(context);
    final cat = ref.watch(banaCatalogueProvider).value;
    final progress = ref.watch(banaProgressProvider);
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= NamoSizes.wideBreakpoint;
    final column = wide ? NamoSizes.homeColumn : NamoSizes.readingColumn;
    // The column is centred: the margin grows when the screen is wider.
    final margin = ((width - column) / 2).clamp(
      NamoSizes.pageMargin(width),
      double.infinity,
    );
    final inset = MediaQuery.paddingOf(context);

    final items = cat?.filter(
      speakerId: _speaker,
      topicId: _topic,
      query: _query.text,
    );
    String name(String id) =>
        cat?.speakers.where((s) => s.id == id).firstOrNull?.name ?? id;
    final available = cat?.topicsFor(_speaker) ?? const <String>{};

    Widget chips(List<Widget> children) => SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: NamoSpace.sm),
            children[i],
          ],
        ],
      ),
    );

    final header = <Widget>[
      const PageHeader(title: 'බණ · Bana'),
      if (cat != null) ...[
        const SizedBox(height: NamoSpace.xs),
        Text(
          '${cat.bana.length} bana · ${cat.speakers.length} venerable speakers',
          style: NamoType.caption(p.textSecondary),
        ),
      ],
      const SizedBox(height: NamoSpace.lg),
      SearchField(
        key: const ValueKey('bana-search'),
        controller: _query,
        focusNode: _searchFocus,
        label: 'Search bana',
        onChanged: (_) => setState(() {}),
      ),
      if (cat != null) ...[
        const SizedBox(height: NamoSpace.lg),
        const Overline('VENERABLE SPEAKER'),
        const SizedBox(height: NamoSpace.sm),
        chips([
          BanaChip(
            key: const ValueKey('bana-speaker-all'),
            label: 'All speakers',
            selected: _speaker == null,
            onTap: () => _pickSpeaker(cat, null),
          ),
          for (final s in cat.speakers)
            BanaChip(
              key: ValueKey('bana-speaker-${s.id}'),
              label: s.name,
              selected: _speaker == s.id,
              onTap: () => _pickSpeaker(cat, s.id),
            ),
        ]),
        const SizedBox(height: NamoSpace.lg),
        const Overline('TOPIC'),
        const SizedBox(height: NamoSpace.sm),
        chips([
          BanaChip(
            key: const ValueKey('bana-topic-all'),
            label: 'All',
            selected: _topic == null,
            onTap: () => setState(() => _topic = null),
          ),
          for (final t in cat.topics)
            if (available.contains(t.id))
              BanaChip(
                key: ValueKey('bana-topic-${t.id}'),
                label: t.si,
                semanticLabel: t.en,
                selected: _topic == t.id,
                onTap: () => setState(() => _topic = t.id),
              ),
        ]),
      ],
      const SizedBox(height: NamoSpace.lg),
    ];

    Widget item(BanaItem it) => switch (it) {
      SeriesItem(:final series) => Padding(
        padding: const EdgeInsets.symmetric(vertical: NamoSpace.xs),
        child: SeriesCard(
          key: ValueKey('bana-series-${series.id}'),
          series: series,
          speakerName: name(series.speaker),
          lastPart: _lastPartNumber(series, progress),
          onTap: () => context.push(Routes.banaSeries(series.id)),
        ),
      ),
      SingleItem(:final bana) => BanaTile(
        key: ValueKey('bana-tile-${bana.id}'),
        bana: bana,
        speakerName: name(bana.speaker),
        onTap: () => context.push(Routes.banaPlay(bana.id)),
      ),
    };

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              margin + inset.left,
              inset.top + NamoSpace.xl,
              margin + inset.right,
              inset.bottom + NamoSpace.xl,
            ),
            sliver: SliverMainAxisGroup(
              slivers: [
                SliverList.list(children: header),
                if (cat == null)
                  const SliverToBoxAdapter(
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (items!.isEmpty)
                  SliverToBoxAdapter(
                    child: Text(
                      'Nothing matches.',
                      style: NamoType.body(p.textSecondary),
                    ),
                  )
                else
                  SliverList.builder(
                    itemCount: items.length,
                    itemBuilder: (_, i) => item(items[i]),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The part number of the video last opened in [series], if any.
  int? _lastPartNumber(BanaSeries series, Map<String, String> progress) {
    final video = progress[series.id];
    if (video == null) return null;
    final at = series.parts.indexOf(video);
    return at < 0 ? null : at + 1;
  }
}
