import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../design/tokens.dart';
import '../design/typography.dart';
import '../design/widgets/sheet_frame.dart';
import 'tipitaka_markup.dart';
import 'tipitaka_text_spans.dart';

/// Opens a page's footnotes in one language over the reader. [focus], when
/// given, is the index of the footnote to scroll to and mark.
Future<void> showTipitakaFootnotes(
  BuildContext context, {
  required List<String> footnotes,
  int? focus,
  required bool pali,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  elevation: 0,
  // The frame draws its own surface, corners and shadow.
  shape: const RoundedRectangleBorder(),
  clipBehavior: Clip.none,
  constraints: const BoxConstraints(),
  sheetAnimationStyle: AnimationStyle(
    duration: NamoMotion.of(context, NamoMotion.open),
    reverseDuration: NamoMotion.of(context, NamoMotion.close),
    curve: NamoMotion.curve,
    reverseCurve: NamoMotion.curve,
  ),
  builder: (_) =>
      _FootnoteSheet(footnotes: footnotes, focus: focus, pali: pali),
);

class _FootnoteSheet extends StatefulWidget {
  const _FootnoteSheet({
    required this.footnotes,
    required this.focus,
    required this.pali,
  });

  final List<String> footnotes;
  final int? focus;
  final bool pali;

  @override
  State<_FootnoteSheet> createState() => _FootnoteSheetState();
}

class _FootnoteSheetState extends State<_FootnoteSheet> {
  final _focused = GlobalKey();

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      final context = _focused.currentContext;
      if (context != null && context.mounted) {
        Scrollable.ensureVisible(context, alignment: 0.1);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    // The body style is set in the Sinhala family, which draws both
    // languages.
    final style = NamoType.body(p.text);
    final focus = widget.focus;
    return SheetFrame(
      title: 'Footnotes',
      children: [
        for (var i = 0; i < widget.footnotes.length; i++)
          if (widget.footnotes[i].isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: NamoSpace.sm),
              child: _note(widget.footnotes[i], style, p, marked: i == focus),
            ),
      ],
    );
  }

  Widget _note(String text, TextStyle style, NamoPalette p,
      {required bool marked}) {
    final drawn = Text.rich(
      TextSpan(
        style: style,
        children: tipitakaSpans(
          parseMarkup(text),
          style: style,
          pali: widget.pali,
          palette: p,
          // A mark inside a footnote is only drawn.
          mark: (ref, _) => WidgetSpan(
            alignment: PlaceholderAlignment.top,
            child: TipitakaFootnoteMark(
              ref: ref,
              style: style.copyWith(
                fontSize: style.fontSize! * 0.62,
                height: 1.0,
                color: p.sage,
              ),
              onTap: null,
            ),
          ),
        ),
      ),
      softWrap: true,
    );
    if (!marked) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: NamoSpace.md,
          vertical: NamoSpace.sm,
        ),
        child: drawn,
      );
    }
    return Semantics(
      selected: true,
      child: Container(
        key: _focused,
        child: DecoratedBox(
          key: const ValueKey('tipitaka-footnote-marked'),
          decoration: BoxDecoration(
            color: p.sageTint,
            borderRadius: BorderRadius.circular(NamoRadius.sm),
            border: Border.all(color: p.sage),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: NamoSpace.md,
              vertical: NamoSpace.sm,
            ),
            child: drawn,
          ),
        ),
      ),
    );
  }
}
