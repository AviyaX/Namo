import 'package:flutter/material.dart';

import '../tokens.dart';
import '../typography.dart';

/// A flat, tappable row: optional number, a title, an optional quiet subtitle.
class ListRow extends StatelessWidget {
  const ListRow({
    super.key,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.number,
    this.titleFamily = NamoFonts.english,
  });

  final String title;
  final String? subtitle;
  final int? number;
  final String titleFamily;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    return Semantics(
      button: true,
      container: true,
      excludeSemantics: true,
      label: [if (number != null) '$number', title, if (subtitle != null) subtitle]
          .join(', '),
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        splashFactory: NoSplash.splashFactory,
        highlightColor: p.surface,
        hoverColor: p.surface,
        child: Container(
          constraints: const BoxConstraints(minHeight: NamoSizes.touchTarget),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: p.divider, width: 1)),
          ),
          child: Row(
            children: [
              if (number != null)
                SizedBox(
                  width: 36,
                  child: Text(
                    '$number',
                    style: namoText(NamoFonts.english, size: 16, color: p.accent),
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: namoText(titleFamily, size: 18, color: p.text)),
                    if (subtitle != null)
                      Text(subtitle!,
                          style: namoText(NamoFonts.sinhala,
                              size: 14, color: p.textQuiet)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
