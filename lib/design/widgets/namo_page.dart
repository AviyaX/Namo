import 'package:flutter/material.dart';

import '../tokens.dart';

/// The frame of a screen: no app bar, one scroll view, content in a centred
/// column. The bottom padding clears the system inset; the app shell adds its
/// floating bar to it.
class NamoPage extends StatelessWidget {
  const NamoPage({
    super.key,
    this.columnKey,
    this.maxWidth = NamoSizes.readingColumn,
    required this.children,
    this.controller,
  });

  final Key? columnKey;
  final double maxWidth;
  final List<Widget> children;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final margin = NamoSizes.pageMargin(MediaQuery.sizeOf(context).width);
    final inset = MediaQuery.paddingOf(context);
    return Scaffold(
      body: SingleChildScrollView(
        controller: controller,
        padding: EdgeInsets.fromLTRB(
          margin,
          inset.top + NamoSpace.xl,
          margin,
          inset.bottom + NamoSpace.xl,
        ),
        child: Center(
          child: ConstrainedBox(
            key: columnKey,
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}
