import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../design/tokens.dart';
import '../design/widgets/buttons.dart';
import '../design/widgets/not_found.dart';
import '../design/widgets/page_header.dart';
import '../router.dart';
import 'tipitaka_labels.dart';
import 'tipitaka_repository.dart';
import 'tipitaka_tree.dart';
import 'tipitaka_widgets.dart';

/// A node's children as rows, under its name and the path to it. A node
/// with text of its own has a first row that opens that text.
///
/// Back goes to the parent's page (the tab's first page from a pitaka), the
/// same after a reload or a link. A key that is not in the tree shows the
/// not-found page; a text with no children opens in the reader instead.
class TipitakaListScreen extends ConsumerStatefulWidget {
  const TipitakaListScreen({super.key, required this.nodeKey});

  final String nodeKey;

  @override
  ConsumerState<TipitakaListScreen> createState() => _TipitakaListScreenState();
}

class _TipitakaListScreenState extends ConsumerState<TipitakaListScreen> {
  bool _redirecting = false;

  String _parentRoute(TipitakaTree? tree) {
    final parent = tree?.node(widget.nodeKey)?.parent;
    return parent == null ? Routes.tipitaka : Routes.tipitakaNode(parent);
  }

  void _back() {
    if (ref.read(tipitakaTreeProvider).hasError) {
      ref.invalidate(tipitakaManifestProvider);
      ref.invalidate(tipitakaTreeProvider);
    }
    context.go(_parentRoute(ref.read(tipitakaTreeProvider).value));
  }

  @override
  Widget build(BuildContext context) {
    final loaded = ref.watch(tipitakaTreeProvider);
    final tree = loaded.value;
    final key = widget.nodeKey;

    final Widget page;
    if (tree != null) {
      final node = tree.node(key);
      if (node == null) return const NotFoundScreen();
      if (tree.isLeaf(key)) {
        if (!_redirecting) {
          _redirecting = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) context.go(Routes.tipitakaReader(key));
          });
        }
        page = _frame(const TipitakaLoading());
      } else {
        page = _list(context, tree, node);
      }
    } else if (loaded.hasError && !loaded.isLoading) {
      page = _frame(const TipitakaLoadError());
    } else {
      page = _frame(const TipitakaLoading());
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(body: page),
    );
  }

  Widget _backButton() => Align(
    alignment: AlignmentDirectional.centerStart,
    child: NamoIconButton(
      icon: Symbols.arrow_back_rounded,
      tooltip: 'Back',
      onPressed: _back,
    ),
  );

  /// Back over [body] (loading and failure).
  Widget _frame(Widget body) => _Scroll(
    slivers: [
      SliverToBoxAdapter(child: _backButton()),
      SliverToBoxAdapter(child: body),
    ],
  );

  Widget _list(BuildContext context, TipitakaTree tree, TipitakaNode node) {
    final children = tree.children(node.key);
    // A node with children is a reading only when it has text of its own.
    final own = tree.isReading(node.key);
    final count = children.length + (own ? 1 : 0);
    return _Scroll(
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _backButton(),
              const SizedBox(height: NamoSpace.xs),
              TipitakaBreadcrumb(tree: tree, nodeKey: node.key),
              const SizedBox(height: NamoSpace.sm),
              PageHeader(
                title: tipitakaName(node),
                caption: tipitakaEnglishLabels[node.key],
              ),
              const SizedBox(height: NamoSpace.lg),
            ],
          ),
        ),
        SliverList.builder(
          itemCount: count,
          itemBuilder: (context, i) {
            if (own && i == 0) {
              return TipitakaNodeRow(
                key: ValueKey('tipitaka-row-own-${node.key}'),
                tree: tree,
                node: node,
                own: true,
              );
            }
            final child = children[own ? i - 1 : i];
            return TipitakaNodeRow(
              key: ValueKey('tipitaka-row-${child.key}'),
              tree: tree,
              node: child,
            );
          },
        ),
      ],
    );
  }
}

/// The page's one scroll view: the content in a centred column, as
/// [NamoPage] lays it out, clear of the system insets and the tab bar.
class _Scroll extends StatelessWidget {
  const _Scroll({required this.slivers});

  final List<Widget> slivers;

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.paddingOf(context);
    return LayoutBuilder(
      builder: (context, box) {
        final width = box.maxWidth;
        final margin = NamoSizes.pageMargin(MediaQuery.sizeOf(context).width);
        final centred = (width - NamoSizes.readingColumn) / 2;
        final left = math.max(margin + inset.left, centred);
        final right = math.max(margin + inset.right, centred);
        return CustomScrollView(
          slivers: [
            for (var i = 0; i < slivers.length; i++)
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  left,
                  i == 0 ? inset.top + NamoSpace.md : 0,
                  right,
                  i == slivers.length - 1 ? inset.bottom + NamoSpace.xl : 0,
                ),
                sliver: slivers[i],
              ),
          ],
        );
      },
    );
  }
}
