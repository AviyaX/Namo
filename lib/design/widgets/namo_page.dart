import 'package:flutter/material.dart';

import '../tokens.dart';

/// The frame of a screen: no app bar, one scroll view, content in a centred
/// column. The bottom padding clears the system inset; the app shell adds its
/// floating bar to it.
///
/// A [backdrop] is painted behind the content, from the very top of the
/// scroll view (behind the status bar), and scrolls away with it. It spans
/// the column; when the column fills the screen (a phone) it runs on through
/// the margins to the screen's edges.
class NamoPage extends StatelessWidget {
  const NamoPage({
    super.key,
    this.columnKey,
    this.maxWidth = NamoSizes.readingColumn,
    required this.children,
    this.controller,
    this.backdrop,
  });

  final Key? columnKey;
  final double maxWidth;
  final List<Widget> children;
  final ScrollController? controller;
  final Widget? backdrop;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final margin = NamoSizes.pageMargin(width);
    final inset = MediaQuery.paddingOf(context);
    final padding = EdgeInsets.fromLTRB(
      margin + inset.left,
      inset.top + NamoSpace.xl,
      margin + inset.right,
      inset.bottom + NamoSpace.xl,
    );
    final column = Center(
      child: ConstrainedBox(
        key: columnKey,
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
    final backdrop = this.backdrop;
    return Scaffold(
      body: backdrop == null
          ? SingleChildScrollView(
              controller: controller,
              padding: padding,
              child: column,
            )
          : SingleChildScrollView(
              controller: controller,
              child: Stack(
                children: [
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: LayoutBuilder(
                      builder: (context, box) {
                        final room = box.maxWidth - padding.horizontal;
                        return room > maxWidth
                            ? Padding(
                                padding: EdgeInsets.only(
                                  left: padding.left,
                                  right: padding.right,
                                ),
                                child: Center(
                                  child: SizedBox(
                                    width: maxWidth,
                                    child: backdrop,
                                  ),
                                ),
                              )
                            : backdrop;
                      },
                    ),
                  ),
                  Padding(padding: padding, child: column),
                ],
              ),
            ),
    );
  }
}
