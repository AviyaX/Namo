import 'package:flutter/material.dart';

import '../tokens.dart';
import '../typography.dart';
import 'pressable.dart';

/// An editorial row: optional leading widget and number, a title, quiet
/// subtitle and caption, an optional trailing widget. It has no divider of its
/// own.
class ListRow extends StatelessWidget {
  const ListRow({
    super.key,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.caption,
    this.number,
    this.leading,
    this.titleFamily = NamoFonts.english,
    this.trailing,
    this.expanded,
    this.detail,
    this.detailLabel,
  });

  /// Shown at the right end of the row.
  final Widget? trailing;

  /// Shown before the number and title.
  final Widget? leading;

  /// For a row that opens and closes something: whether it is open now.
  /// Left null for an ordinary row.
  final bool? expanded;

  /// Shown under the title, subtitle and caption (a search hit's verse line,
  /// say). [detailLabel] is its text for screen readers.
  final Widget? detail;
  final String? detailLabel;

  final String title;
  final String? subtitle;
  final String? caption;
  final int? number;
  final String titleFamily;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    final titleStyle = titleFamily == NamoFonts.sinhala
        ? NamoType.sectionTitleSinhala(p.text).copyWith(fontSize: 18)
        : NamoType.cardTitle(p.text);
    return Pressable(
      onTap: onTap,
      expanded: expanded,
      excludeChildSemantics: true,
      semanticLabel: [
        if (number != null) '$number',
        title,
        if (subtitle != null) subtitle,
        ?detailLabel,
      ].join(', '),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: NamoSpace.lg, vertical: NamoSpace.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: NamoSpace.md),
            ],
            if (number != null)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: NamoSpace.md),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: NamoSpace.xl),
                  child: Text('$number', style: NamoType.cardTitle(p.gold)),
                ),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: titleStyle),
                  if (subtitle != null)
                    Text(subtitle!, style: NamoType.body(p.textSecondary)),
                  if (caption != null)
                    Text(caption!, style: NamoType.caption(p.textSecondary)),
                  ?detail,
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: NamoSpace.md),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}
