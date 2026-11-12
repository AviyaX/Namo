import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/tokens.dart';
import '../design/widgets/app_shell.dart';
import '../design/widgets/namo_page.dart';
import '../design/widgets/page_header.dart';
import '../design/widgets/search_field.dart';
import 'tipitaka_labels.dart';
import 'tipitaka_repository.dart';
import 'tipitaka_search.dart';
import 'tipitaka_state.dart';
import 'tipitaka_tree.dart';
import 'tipitaka_widgets.dart';

/// The Tripitaka tab's first page: a search by name, the text last read, and
/// the three pitakas. While the search box holds something to match, the
/// matching names take the place of the rest.
class TipitakaHomeScreen extends ConsumerStatefulWidget {
  const TipitakaHomeScreen({super.key = const ValueKey('screen-tripitaka')});

  @override
  ConsumerState<TipitakaHomeScreen> createState() => _TipitakaHomeScreenState();
}

class _TipitakaHomeScreenState extends ConsumerState<TipitakaHomeScreen> {
  final _query = TextEditingController();
  final _searchFocus = FocusNode();

  /// The tree whose stale places and bookmarks were last dropped.
  TipitakaTree? _pruned;

  @override
  void dispose() {
    _query.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _searchFocus.unfocus();
    if (_query.text.isEmpty) return;
    _query.clear();
    setState(() {});
  }

  /// Once per loaded tree: forget places and bookmarks it no longer has.
  void _pruneOnce(TipitakaTree tree) {
    if (identical(_pruned, tree)) return;
    _pruned = tree;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) pruneTipitakaState(ref, tree);
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(tabPressedAgainProvider, (_, next) {
      if (next?.$1 == TabIndex.tripitaka) _clearSearch();
    });
    final loaded = ref.watch(tipitakaTreeProvider);
    final tree = loaded.value;
    if (tree != null) _pruneOnce(tree);
    final wide = MediaQuery.sizeOf(context).width >= NamoSizes.wideBreakpoint;

    final Widget body;
    if (tree != null) {
      final query = _query.text;
      body = foldTipitakaQuery(query).isNotEmpty
          ? TipitakaResults(tree: tree, query: query)
          : _Browse(tree: tree, wide: wide);
    } else if (loaded.hasError && !loaded.isLoading) {
      body = const TipitakaLoadError();
    } else {
      body = const TipitakaLoading();
    }

    return NamoPage(
      maxWidth: wide ? NamoSizes.homeColumn : NamoSizes.readingColumn,
      children: [
        const PageHeader(
          title: tipitakaPageTitle,
          caption: tipitakaPageCaption,
        ),
        const SizedBox(height: NamoSpace.lg),
        SearchField(
          key: const ValueKey('tipitaka-search'),
          controller: _query,
          focusNode: _searchFocus,
          label: 'Search by name',
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: NamoSpace.lg),
        body,
      ],
    );
  }
}

/// The Continue card, when there is a text to continue, and the pitakas.
class _Browse extends ConsumerWidget {
  const _Browse({required this.tree, required this.wide});

  final TipitakaTree tree;
  final bool wide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recent = ref.watch(tipitakaPlacesProvider).recent;
    final place = recent.where((p) => tree.isReading(p.key)).firstOrNull;
    final pitakas = [
      for (final key in TipitakaTree.roots) ?tree.node(key),
    ];
    final cards = [
      for (final node in pitakas)
        TipitakaPitakaCard(
          key: ValueKey('tipitaka-pitaka-${node.key}'),
          tree: tree,
          node: node,
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (place != null) ...[
          TipitakaContinueCard(tree: tree, place: place),
          const SizedBox(height: NamoSpace.xl),
        ],
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(width: NamoSpace.md),
                Expanded(child: cards[i]),
              ],
            ],
          )
        else
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(height: NamoSpace.md),
            cards[i],
          ],
      ],
    );
  }
}
