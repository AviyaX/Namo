import 'package:flutter/material.dart';

import '../tokens.dart';
import '../typography.dart';

/// The frame of a bottom sheet: surface, rounded top, the app's one shadow, a
/// grab handle, a title and content that scrolls when it is taller than the
/// sheet. The sheet is never taller than 90 % of the screen.
class SheetFrame extends StatelessWidget {
  const SheetFrame({super.key, required this.title, required this.children})
    : itemCount = 0,
      itemBuilder = null;

  /// A sheet whose rows are built only as they scroll into view, for a long
  /// list.
  const SheetFrame.builder({
    super.key,
    required this.title,
    required this.itemCount,
    required IndexedWidgetBuilder this.itemBuilder,
  }) : children = const [];

  final String title;
  final List<Widget> children;
  final int itemCount;
  final IndexedWidgetBuilder? itemBuilder;

  static const _maxContentWidth = 680.0;
  static const _sidePadding = 20.0;
  static const _maxHeightShare = 0.9;

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    final media = MediaQuery.of(context);
    final padding = EdgeInsets.fromLTRB(
      _sidePadding,
      0,
      _sidePadding,
      media.padding.bottom + NamoSpace.xl,
    );
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: media.size.height * _maxHeightShare,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(NamoRadius.lg),
          ),
          boxShadow: p.floatShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: NamoSpace.sm),
              child: Center(
                child: ExcludeSemantics(
                  child: SizedBox(
                    width: 32,
                    height: 4,
                    child: DecoratedBox(
                      decoration: ShapeDecoration(
                        color: p.border,
                        shape: const StadiumBorder(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                _sidePadding,
                NamoSpace.lg,
                _sidePadding,
                NamoSpace.lg,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _maxContentWidth),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Semantics(
                      header: true,
                      child: Text(
                        title,
                        softWrap: true,
                        style: NamoType.sectionTitle(p.text),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Flexible(child: _content(padding)),
          ],
        ),
      ),
    );
  }

  /// The rows under the title, in one scroll view, each no wider than
  /// [_maxContentWidth].
  Widget _content(EdgeInsets padding) {
    Widget column(Widget child) => Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxContentWidth),
        child: child,
      ),
    );
    final builder = itemBuilder;
    if (builder != null) {
      return ListView.builder(
        padding: padding,
        itemCount: itemCount,
        itemBuilder: (context, i) =>
            column(SizedBox(width: double.infinity, child: builder(context, i))),
      );
    }
    return SingleChildScrollView(
      padding: padding,
      child: column(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}
