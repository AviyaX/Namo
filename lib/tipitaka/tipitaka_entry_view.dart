import 'package:flutter/material.dart';

import '../design/tokens.dart';
import '../design/typography.dart';
import '../settings/reading_language.dart';
import 'tipitaka_book.dart';
import 'tipitaka_footnote_sheet.dart';
import 'tipitaka_markup.dart';
import 'tipitaka_text_spans.dart';

bool _hasMark(MarkupToken tk) => switch (tk) {
  FootnoteRefToken() => true,
  SpanToken() => tk.children.any(_hasMark),
  _ => false,
};

/// One entry of a reading, drawn by its type. A footnote mark opens the
/// page's footnotes for the entry's language; with none on the page it is
/// drawn but is not a button.
class TipitakaEntryView extends StatelessWidget {
  const TipitakaEntryView({
    super.key,
    required this.entry,
    required this.pali,
    this.footnotes = const [],
    this.onFootnote,
    this.fontScale = 1.0,
    this.lineSpacing = 1.6,
    this.color,
  });

  final TipitakaEntry entry;

  /// Pali gains joiners for display; Sinhala is drawn as stored.
  final bool pali;

  /// The footnotes of the entry's page in its language.
  final List<String> footnotes;

  /// Called with a mark's ref. When null the footnotes sheet opens with the
  /// matching footnote marked.
  final ValueChanged<String>? onFootnote;

  final double fontScale;
  final double lineSpacing;

  /// The text colour; the palette's text colour when null.
  final Color? color;

  /// Heading sizes against the body size, by level (clamped to three).
  static const _headingScale = [1.12, 1.25, 1.4];

  TextStyle _style(NamoPalette p) {
    final base = readingStyle(
      pali ? ReadingLanguage.pali : ReadingLanguage.sinhala,
      fontScale: fontScale,
      lineSpacing: lineSpacing,
      color: color ?? p.text,
    );
    if (entry.type != EntryType.heading) return base;
    final step = ((entry.level ?? 1) - 1).clamp(0, _headingScale.length - 1);
    return tipitakaWeight(
      base.copyWith(fontSize: base.fontSize! * _headingScale[step]),
      600,
    );
  }

  void _open(BuildContext context, String ref) {
    final handler = onFootnote;
    if (handler != null) {
      handler(ref);
      return;
    }
    showTipitakaFootnotes(
      context,
      footnotes: footnotes,
      focus: matchFootnote(ref, footnotes),
      pali: pali,
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    final style = _style(p);
    final tokens = parseMarkup(entry.text);

    // A rule at the top level divides the entry into blocks.
    final blocks = <List<MarkupToken>>[[]];
    for (final tk in tokens) {
      if (tk is RuleToken) {
        blocks.add([]);
      } else {
        blocks.last.add(tk);
      }
    }

    final align = switch (entry.type) {
      EntryType.centered => TextAlign.center,
      _ => TextAlign.start,
    };
    final indent = entry.type == EntryType.paragraph;
    final fontSize = style.fontSize!;

    InlineSpan mark(String ref, int index) => WidgetSpan(
      alignment: PlaceholderAlignment.top,
      child: TipitakaFootnoteMark(
        key: ValueKey(
          index == 0
              ? 'tipitaka-footnote-mark-$ref'
              : 'tipitaka-footnote-mark-$ref-$index',
        ),
        ref: ref,
        style: tipitakaWeight(
          style.copyWith(
            fontSize: fontSize * 0.62,
            height: 1.0,
            color: p.sage,
            decoration: TextDecoration.none,
          ),
          600,
        ),
        onTap: footnotes.isEmpty ? null : () => _open(context, ref),
      ),
    );

    final children = <Widget>[];
    var first = true;
    for (var b = 0; b < blocks.length; b++) {
      if (b > 0) {
        children.add(
          Padding(
            key: b == 1 ? const ValueKey('tipitaka-rule') : null,
            padding: const EdgeInsets.symmetric(vertical: NamoSpace.sm),
            child: SizedBox(height: 1, child: ColoredBox(color: p.border)),
          ),
        );
      }
      if (blocks[b].isEmpty) continue;
      final spans = tipitakaSpans(
        blocks[b],
        style: style,
        pali: pali,
        palette: p,
        mark: mark,
      );
      children.add(
        Text.rich(
          TextSpan(
            style: style,
            children: [
              if (indent && first)
                WidgetSpan(
                  alignment: PlaceholderAlignment.bottom,
                  child: SizedBox(width: fontSize * 1.5, height: 1),
                ),
              ...spans,
            ],
          ),
          textAlign: align,
          softWrap: true,
        ),
      );
      first = false;
    }

    final body = children.length == 1
        ? children.single
        : Column(
            crossAxisAlignment: entry.type == EntryType.centered
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: children,
          );
    final inset = switch (entry.type) {
      EntryType.gatha => const EdgeInsetsDirectional.only(start: NamoSpace.xl),
      _ => EdgeInsetsDirectional.zero,
    };
    final drawn = SizedBox(
      width: double.infinity,
      child: Padding(padding: inset, child: body),
    );
    final tappable = footnotes.isNotEmpty && tokens.any(_hasMark)
        ? TipitakaMarkTapArea(child: drawn)
        : drawn;
    return entry.type == EntryType.heading
        ? Semantics(header: true, child: tappable)
        : tappable;
  }
}
