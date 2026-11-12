import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../design/tokens.dart';
import '../design/typography.dart';
import '../design/widgets/pressable.dart';
import '../router.dart';
import 'tipitaka_book.dart';
import 'tipitaka_entry_view.dart';
import 'tipitaka_state.dart';
import 'tipitaka_tree.dart';

/// Draws the rows of a reading for one view: row i is entry i, with the
/// notes on missing Sinhala and, in both languages, its Sinhala beside or
/// under it.
class TipitakaReadingRows {
  TipitakaReadingRows({
    required this.reading,
    required this.view,
    required this.wide,
    required this.fontScale,
    required this.lineSpacing,
    required this.palette,
  });

  final TipitakaReading reading;
  final TipitakaView view;
  final bool wide;
  final double fontScale;
  final double lineSpacing;
  final NamoPalette palette;

  Widget _entry(TipitakaEntry e, {required bool pali}) => TipitakaEntryView(
    entry: e,
    pali: pali,
    footnotes: reading.book.footnotes(e.page, pali: pali),
    fontScale: fontScale,
    lineSpacing: lineSpacing,
  );

  Widget _note(String text) => Padding(
    padding: const EdgeInsets.only(bottom: NamoSpace.sm),
    child: Text(
      text,
      softWrap: true,
      style: NamoType.caption(palette.textSecondary),
    ),
  );

  Widget build(int i) {
    final pali = reading.pali[i];
    final sinhala = reading.sinhala[i];
    final children = <Widget>[
      if (i == 0 && !reading.hasSinhala)
        Padding(
          padding: const EdgeInsets.only(bottom: NamoSpace.md),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: palette.backgroundAlt,
              borderRadius: BorderRadius.circular(NamoRadius.sm),
            ),
            child: Padding(
              padding: const EdgeInsets.all(NamoSpace.md),
              child: Text(
                'The source has no Sinhala translation for this text',
                softWrap: true,
                style: NamoType.caption(palette.textSecondary),
              ),
            ),
          ),
        ),
    ];
    switch (view) {
      case TipitakaView.pali:
        children.add(_entry(pali, pali: true));
      case TipitakaView.sinhala:
        if (sinhala != null) {
          children.add(_entry(sinhala, pali: false));
        } else {
          // Once per run of entries without Sinhala.
          if (i == 0 || reading.sinhala[i - 1] != null) {
            children.add(_note('No Sinhala in the source for this passage'));
          }
          children.add(_entry(pali, pali: true));
        }
      case TipitakaView.both when wide:
        children.add(
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _entry(pali, pali: true)),
              const SizedBox(width: NamoSpace.xl),
              Expanded(
                child: sinhala == null
                    ? const SizedBox.shrink()
                    : _entry(sinhala, pali: false),
              ),
            ],
          ),
        );
      case TipitakaView.both:
        children.add(_entry(pali, pali: true));
        if (sinhala != null) {
          children.add(const SizedBox(height: NamoSpace.xs));
          children.add(_entry(sinhala, pali: false));
        }
    }
    final heading = pali.type == EntryType.heading;
    return Padding(
      padding: EdgeInsets.only(
        top: heading ? NamoSpace.lg : NamoSpace.sm,
        bottom: NamoSpace.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

/// Previous and next readings in tree order, each with its Sinhala name.
class TipitakaNeighbours extends StatelessWidget {
  const TipitakaNeighbours({
    super.key,
    required this.tree,
    required this.previous,
    required this.next,
    required this.maxWidth,
  });

  final TipitakaTree tree;
  final String? previous, next;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    Widget side(String? key, String label, {required bool end}) {
      if (key == null) return const SizedBox.shrink();
      final node = tree.node(key);
      final name = node == null
          ? ''
          : (node.sinhala.trim().isEmpty ? node.pali : node.sinhala);
      return _NeighbourButton(
        label: label,
        name: name,
        end: end,
        onTap: () => context.go(Routes.tipitakaReader(key)),
      );
    }

    return Padding(
      padding: EdgeInsets.only(top: NamoSpace.xl, bottom: bottom + NamoSpace.xl),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: side(previous, 'Previous', end: false)),
              const SizedBox(width: NamoSpace.md),
              Expanded(child: side(next, 'Next', end: true)),
            ],
          ),
        ),
      ),
    );
  }
}

class _NeighbourButton extends StatelessWidget {
  const _NeighbourButton({
    required this.label,
    required this.name,
    required this.end,
    required this.onTap,
  });

  final String label, name;
  final bool end;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    final align = end ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final textAlign = end ? TextAlign.end : TextAlign.start;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: p.border),
        borderRadius: BorderRadius.circular(NamoRadius.sm),
      ),
      child: Pressable(
        onTap: onTap,
        semanticLabel: '$label, $name',
        excludeChildSemantics: true,
        child: Padding(
          padding: const EdgeInsets.all(NamoSpace.md),
          child: Column(
            crossAxisAlignment: align,
            children: [
              Row(
                mainAxisAlignment:
                    end ? MainAxisAlignment.end : MainAxisAlignment.start,
                children: [
                  if (!end) ...[
                    Icon(Symbols.arrow_back_rounded,
                        size: NamoSizes.iconSmall, color: p.sage),
                    const SizedBox(width: NamoSpace.xs),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      textAlign: textAlign,
                      style: NamoType.label(p.sage),
                    ),
                  ),
                  if (end) ...[
                    const SizedBox(width: NamoSpace.xs),
                    Icon(Symbols.arrow_forward_rounded,
                        size: NamoSizes.iconSmall, color: p.sage),
                  ],
                ],
              ),
              if (name.isNotEmpty) ...[
                const SizedBox(height: NamoSpace.xs),
                Text(
                  name,
                  textAlign: textAlign,
                  softWrap: true,
                  style: NamoType.readingTitle(p.text),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
