import 'package:flutter/material.dart';

import '../tokens.dart';
import '../typography.dart';

/// A screen's title, an optional quiet caption under it and an optional
/// widget at the trailing end.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.caption,
    this.trailing,
  });

  final String title;
  final String? caption;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(title, style: NamoType.screenTitle(p.text)),
              ),
              if (caption != null) ...[
                const SizedBox(height: NamoSpace.xs),
                Text(caption!, style: NamoType.caption(p.textSecondary)),
              ],
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// A small label above a block, shown as written.
class Overline extends StatelessWidget {
  const Overline(this.text, {super.key, this.color, this.header = false});

  final String text;
  final Color? color;

  /// True when this labels a group of rows, so screen readers can jump to it.
  final bool header;

  @override
  Widget build(BuildContext context) {
    final label = Text(
      text,
      style: NamoType.overline(color ?? NamoPalette.of(context).textSecondary),
    );
    return header ? Semantics(header: true, child: label) : label;
  }
}
