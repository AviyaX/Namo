import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../design/tokens.dart';
import '../design/typography.dart';
import '../design/widgets/pressable.dart';
import '../router.dart';
import '../settings/reading_language.dart';
import 'pali_display.dart';
import 'tipitaka_book.dart';
import 'tipitaka_footnote_sheet.dart';
import 'tipitaka_markup.dart';
import 'tipitaka_state.dart';
import 'tipitaka_tree.dart';

/// The text of one Tripitaka entry as it is drawn: the markup turned into
/// styles, characters no font draws replaced, and for Pali the letters
/// joined. The stored text is never changed; this works on copies.
String tipitakaDisplayText(String text, {required bool pali}) {
  final shown = tipitakaForDisplay(text);
  return pali ? paliForDisplay(shown) : shown;
}

TextStyle _weight(TextStyle s, int weight) => s.copyWith(
  fontWeight: FontWeight.values[(weight ~/ 100 - 1).clamp(0, 8)],
  fontVariations: [FontVariation.weight(weight.toDouble())],
);

/// Builds the spans of [tokens] on [style]. [mark] draws a footnote mark
/// (its ref and how many marks came before it in the same text).
List<InlineSpan> tipitakaSpans(
  List<MarkupToken> tokens, {
  required TextStyle style,
  required bool pali,
  required NamoPalette palette,
  required InlineSpan Function(String ref, int index) mark,
}) {
  var marks = 0;
  List<InlineSpan> build(List<MarkupToken> tokens, TextStyle style,
      Set<TextDecoration> decorations) {
    return [
      for (final tk in tokens)
        switch (tk) {
          TextToken() => TextSpan(
            text: tipitakaDisplayText(tk.text, pali: pali),
            style: style,
          ),
          BreakToken() || RuleToken() => TextSpan(text: '\n', style: style),
          FootnoteRefToken() => mark(tk.ref, marks++),
          SpanToken() => () {
            final inner = {...decorations};
            var s = style;
            switch (tk.kind) {
              case MarkupKind.bold:
                s = _weight(s, 700);
              case MarkupKind.underline:
                inner.add(TextDecoration.underline);
              case MarkupKind.strike:
                inner.add(TextDecoration.lineThrough);
              case MarkupKind.highlight:
                s = s.copyWith(backgroundColor: palette.sageMark);
              case MarkupKind.editorial:
                s = s.copyWith(color: palette.textSecondary);
            }
            if (inner.isNotEmpty) {
              s = s.copyWith(
                decoration: inner.length == 1
                    ? inner.first
                    : TextDecoration.combine(inner.toList()),
              );
            }
            return TextSpan(style: s, children: build(tk.children, s, inner));
          }(),
        },
    ];
  }

  return build(tokens, style, const {});
}

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
    return _weight(
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
        style: _weight(
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
        ? _MarkTapArea(child: drawn)
        : drawn;
    return entry.type == EntryType.heading
        ? Semantics(header: true, child: tappable)
        : tappable;
  }
}

/// A footnote mark: a small raised ref. With [onTap] it is a button named
/// `Footnote <ref>`; inside a [TipitakaEntryView] it also answers taps
/// within 44 px around it without making its line taller. Without [onTap]
/// it is only drawn.
class TipitakaFootnoteMark extends StatelessWidget {
  const TipitakaFootnoteMark({
    super.key,
    required this.ref,
    required this.style,
    required this.onTap,
  });

  final String ref;
  final TextStyle style;
  final VoidCallback? onTap;

  static const target = 44.0;

  @override
  Widget build(BuildContext context) {
    final drawn = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Text(ref, style: style),
    );
    final tap = onTap;
    if (tap == null) return drawn;
    return _MarkTarget(
      onTap: tap,
      child: Semantics(
        // Its own node, so the text around it is not read as a button.
        container: true,
        button: true,
        label: 'Footnote $ref',
        excludeSemantics: true,
        onTap: tap,
        child: FocusableActionDetector(
          mouseCursor: SystemMouseCursors.click,
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                tap();
                return null;
              },
            ),
          },
          child: drawn,
        ),
      ),
    );
  }
}

/// Marks a footnote mark's box so [_MarkTapArea] can find it.
class _MarkTarget extends SingleChildRenderObjectWidget {
  const _MarkTarget({required this.onTap, required super.child});

  final VoidCallback onTap;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMarkTarget(onTap);

  @override
  void updateRenderObject(BuildContext context, _RenderMarkTarget render) {
    render.onTap = onTap;
  }
}

class _RenderMarkTarget extends RenderProxyBox {
  _RenderMarkTarget(this.onTap);

  VoidCallback onTap;
}

/// Pointer taps over an entry go to the nearest footnote mark whose 44 px
/// square holds them. (A text paragraph hands a tap on its letters to the
/// letters, so the mark itself cannot take a tap beside it.)
class _MarkTapArea extends StatelessWidget {
  const _MarkTapArea({required this.child});

  final Widget child;

  static void _collect(RenderObject node, List<_RenderMarkTarget> out) {
    if (node is _RenderMarkTarget) out.add(node);
    node.visitChildren((c) => _collect(c, out));
  }

  void _tap(BuildContext context, Offset global) {
    final root = context.findRenderObject();
    if (root == null) return;
    final marks = <_RenderMarkTarget>[];
    _collect(root, marks);
    _RenderMarkTarget? best;
    var bestDistance = double.infinity;
    for (final m in marks) {
      if (!m.attached || !m.hasSize) continue;
      final rect = MatrixUtils.transformRect(
        m.getTransformTo(null),
        Offset.zero & m.size,
      );
      final area = Rect.fromCenter(
        center: rect.center,
        width: math.max(rect.width, TipitakaFootnoteMark.target),
        height: math.max(rect.height, TipitakaFootnoteMark.target),
      );
      if (!area.contains(global)) continue;
      final d = (rect.center - global).distanceSquared;
      if (d < bestDistance) {
        bestDistance = d;
        best = m;
      }
    }
    best?.onTap();
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.translucent,
    // Pointer taps only; screen readers use each mark's own action.
    excludeFromSemantics: true,
    onTapUp: (d) => _tap(context, d.globalPosition),
    child: child,
  );
}

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
