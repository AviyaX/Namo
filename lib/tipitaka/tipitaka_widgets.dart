/// The pieces of the Tripitaka tab's pages: the path line, the pitaka cards,
/// the Continue card, a node's row and the search results.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../design/marks.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../design/widgets/empty_state.dart';
import '../design/widgets/list_row.dart';
import '../design/widgets/page_header.dart';
import '../design/widgets/pressable.dart';
import '../design/widgets/progress_line.dart';
import '../design/widgets/surface_card.dart';
import '../router.dart';
import 'pali_display.dart';
import 'tipitaka_labels.dart';
import 'tipitaka_repository.dart';
import 'tipitaka_search.dart';
import 'tipitaka_state.dart';
import 'tipitaka_tree.dart';

/// The node's Sinhala name as drawn (its Pali name when the source gives no
/// Sinhala one).
String tipitakaName(TipitakaNode node) =>
    tipitakaForDisplay(node.sinhala.trim().isEmpty ? node.pali : node.sinhala);

/// The Pali name as drawn.
String tipitakaPaliName(TipitakaNode node) =>
    paliForDisplay(tipitakaForDisplay(node.pali));

/// The Sinhala names of the node's ancestors, root first.
String tipitakaPath(TipitakaTree tree, String key) => tree
    .ancestors(key)
    .map(tipitakaName)
    .join(tipitakaPathSeparator);

/// Where a tap on the node goes: its list when it has children, else the
/// reader.
String tipitakaRouteOf(TipitakaTree tree, String key) =>
    tree.children(key).isEmpty
    ? Routes.tipitakaReader(key)
    : Routes.tipitakaNode(key);

/// A quiet progress mark while the Tripitaka loads.
class TipitakaLoading extends StatelessWidget {
  const TipitakaLoading({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(NamoSpace.xxl),
    child: Center(
      child: SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: NamoPalette.of(context).sage,
        ),
      ),
    ),
  );
}

/// The Tripitaka failed to load: a plain message and a way to try again.
class TipitakaLoadError extends ConsumerWidget {
  const TipitakaLoadError({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => EmptyState(
    icon: Symbols.error_outline_rounded,
    title: 'The Tripitaka could not be opened.',
    actionLabel: 'Try again',
    onAction: () {
      ref.invalidate(tipitakaManifestProvider);
      ref.invalidate(tipitakaTreeProvider);
      ref.invalidate(tipitakaSearchProvider);
    },
  );
}

/// "Tripitaka › … › parent": each part goes to its page. Scrolls sideways
/// when long, starting at its end (the nearest part).
class TipitakaBreadcrumb extends StatelessWidget {
  const TipitakaBreadcrumb({super.key, required this.tree, required this.nodeKey});

  final TipitakaTree tree;
  final String nodeKey;

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    final parts = <(String, String)>[
      ('Tripitaka', Routes.tipitaka),
      for (final a in tree.ancestors(nodeKey))
        (tipitakaName(a), Routes.tipitakaNode(a.key)),
    ];
    return Semantics(
      key: const ValueKey('tipitaka-breadcrumb'),
      container: true,
      explicitChildNodes: true,
      label: 'Path',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        reverse: true,
        child: Row(
          children: [
            for (var i = 0; i < parts.length; i++) ...[
              if (i > 0)
                ExcludeSemantics(
                  child: Text(
                    tipitakaPathSeparator.trim(),
                    style: NamoType.label(p.textSecondary),
                  ),
                ),
              Pressable(
                onTap: () => context.go(parts[i].$2),
                semanticLabel: parts[i].$1,
                excludeChildSemantics: true,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: NamoSizes.touchTarget,
                    minWidth: NamoSizes.touchTarget,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: NamoSpace.sm,
                    ),
                    child: Center(
                      widthFactor: 1,
                      child: Text(
                        parts[i].$1,
                        style: NamoType.label(p.sage),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

const _pitakaMarks = {
  'vp': NamoMark.lotusBud,
  'sp': NamoMark.wheel,
  'ap': NamoMark.leaf,
};

/// One of the three pitakas: a drawn mark, its Sinhala name from the tree,
/// its English label and how many texts it holds.
class TipitakaPitakaCard extends StatelessWidget {
  const TipitakaPitakaCard({super.key, required this.tree, required this.node});

  final TipitakaTree tree;
  final TipitakaNode node;

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    final name = tipitakaName(node);
    final english = tipitakaEnglishLabels[node.key];
    final count = textsLabel(tree.readingCount(node.key));
    return SurfaceCard(
      onTap: () => context.go(Routes.tipitakaNode(node.key)),
      semanticLabel: [name, ?english, count].join(', '),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NamoMarkIcon(_pitakaMarks[node.key] ?? NamoMark.lotus, size: 32),
          const SizedBox(width: NamoSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: NamoType.sectionTitleSinhala(p.text)),
                if (english != null) ...[
                  const SizedBox(height: NamoSpace.xs),
                  Text(english, style: NamoType.label(p.textSecondary)),
                ],
                const SizedBox(height: NamoSpace.xs),
                Text(count, style: NamoType.caption(p.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The most recently read text still in the tree: its name, where it sits
/// and how far in the person is.
class TipitakaContinueCard extends StatelessWidget {
  const TipitakaContinueCard({
    super.key,
    required this.tree,
    required this.place,
  });

  final TipitakaTree tree;
  final TipitakaPlace place;

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    final node = tree.node(place.key)!;
    final name = tipitakaName(node);
    final path = tipitakaPath(tree, node.key);
    return SurfaceCard(
      key: const ValueKey('tipitaka-continue'),
      onTap: () => context.go(Routes.tipitakaReader(node.key)),
      semanticLabel: [
        'Continue reading',
        name,
        if (path.isNotEmpty) path,
      ].join(', '),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Overline('Continue reading', accent: true),
          const SizedBox(height: NamoSpace.sm),
          Text(name, style: NamoType.sectionTitleSinhala(p.text)),
          if (path.isNotEmpty) ...[
            const SizedBox(height: NamoSpace.xs),
            Text(path, style: NamoType.caption(p.textSecondary)),
          ],
          const SizedBox(height: NamoSpace.md),
          ProgressLine(value: place.fraction, rounded: true),
        ],
      ),
    );
  }
}

/// A node as a row: its Sinhala name, its Pali name under it, a caption (its
/// English label, or [caption]), how many texts it holds when it has
/// children, and the progress through it when it is a text already opened.
class TipitakaNodeRow extends ConsumerWidget {
  const TipitakaNodeRow({
    super.key,
    required this.tree,
    required this.node,
    this.caption,
    this.own = false,
  });

  final TipitakaTree tree;
  final TipitakaNode node;

  /// Shown in place of the English label (a search hit's path).
  final String? caption;

  /// The node's own text, at the top of its list: opens the reader.
  final bool own;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = NamoPalette.of(context);
    final name = tipitakaName(node);
    final parent = !own && tree.children(node.key).isNotEmpty;
    final count = parent ? textsLabel(tree.readingCount(node.key)) : null;
    final reading = own || !parent;
    final place = reading
        ? ref.watch(tipitakaPlacesProvider.select((s) => s.of(node.key)))
        : null;
    final shownCaption = own
        ? 'Opening text'
        : caption ?? tipitakaEnglishLabels[node.key];
    final chevron = Icon(
      Symbols.chevron_right_rounded,
      size: NamoSizes.iconSmall,
      weight: 300,
      color: p.textSecondary,
    );
    return ListRow(
      title: name,
      titleFamily: NamoFonts.sinhala,
      subtitle: own ? null : tipitakaPaliName(node),
      caption: shownCaption,
      semanticLabel: [
        name,
        ?count,
        if (own) shownCaption,
        ?caption,
      ].join(', '),
      detail: place == null
          ? null
          : Padding(
              padding: const EdgeInsets.only(top: NamoSpace.sm),
              child: ProgressLine(value: place.fraction, rounded: true),
            ),
      onTap: () => context.go(
        own ? Routes.tipitakaReader(node.key) : tipitakaRouteOf(tree, node.key),
      ),
      trailing: count == null
          ? chevron
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(count, style: NamoType.caption(p.textSecondary)),
                const SizedBox(width: NamoSpace.xs),
                chevron,
              ],
            ),
    );
  }
}

/// The names that match [query], each with its path; or the empty state.
class TipitakaResults extends ConsumerWidget {
  const TipitakaResults({super.key, required this.tree, required this.query});

  final TipitakaTree tree;
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final search = ref.watch(tipitakaSearchProvider);
    final index = search.value;
    if (index == null) {
      return search.hasError && !search.isLoading
          ? const TipitakaLoadError()
          : const TipitakaLoading();
    }
    final hits = index.find(query);
    if (hits.isEmpty) {
      return const EmptyState(
        key: ValueKey('tipitaka-results'),
        icon: Symbols.search_off_rounded,
        title: 'No names match',
      );
    }
    return Column(
      key: const ValueKey('tipitaka-results'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final node in hits)
          TipitakaNodeRow(
            key: ValueKey('tipitaka-result-${node.key}'),
            tree: tree,
            node: node,
            // A pitaka has no path: its English label stands instead.
            caption: switch (tipitakaPath(tree, node.key)) {
              '' => null,
              final path => path,
            },
          ),
      ],
    );
  }
}
