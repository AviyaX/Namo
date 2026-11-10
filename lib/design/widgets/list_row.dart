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
    this.subtitleFamily,
    this.trailing,
    this.action,
    this.expanded,
    this.detail,
    this.detailLabel,
  });

  /// Shown at the right end of the row, inside the tappable row (a chevron,
  /// say). It is part of the row's one spoken label.
  final Widget? trailing;

  /// A control of its own at the right end (a remove button): it sits beside
  /// the tappable row, not inside it, so screen readers still find it.
  final Widget? action;

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

  /// The family of the subtitle; [NamoFonts.romanPali] draws a Roman Pali
  /// name. Left null, the subtitle is ordinary body text.
  final String? subtitleFamily;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    final titleStyle = titleFamily == NamoFonts.sinhala
        ? NamoType.sectionTitleSinhala(p.text).copyWith(fontSize: 18)
        : NamoType.cardTitle(p.text);
    final row = Pressable(
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
                    Text(
                      subtitle!,
                      style: subtitleFamily == NamoFonts.romanPali
                          ? NamoType.romanName(p.textSecondary)
                          : NamoType.body(p.textSecondary),
                    ),
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
    if (action == null) return row;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: row),
        Padding(
          padding: const EdgeInsetsDirectional.only(end: NamoSpace.sm),
          child: action!,
        ),
      ],
    );
  }
}
