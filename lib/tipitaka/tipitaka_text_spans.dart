import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../design/tokens.dart';
import 'pali_display.dart';
import 'tipitaka_markup.dart';

/// The text of one Tripitaka entry as it is drawn: the markup turned into
/// styles, characters no font draws replaced, and for Pali the letters
/// joined. The stored text is never changed; this works on copies.
String tipitakaDisplayText(String text, {required bool pali}) {
  final shown = tipitakaForDisplay(text);
  return pali ? paliForDisplay(shown) : shown;
}

/// [s] at [weight], for the variable font and the weight together.
TextStyle tipitakaWeight(TextStyle s, int weight) => s.copyWith(
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
                s = tipitakaWeight(s, 700);
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

/// A footnote mark: a small raised ref. With [onTap] it is a button named
/// `Footnote <ref>`; inside a [TipitakaMarkTapArea] it also answers taps
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
        // Its own node, so the text around it is not read as a button. An
        // inline reference in running text, so a link: tap-target size
        // guidelines do not apply to links.
        container: true,
        button: true,
        link: true,
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

/// Marks a footnote mark's box so [TipitakaMarkTapArea] can find it.
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
class TipitakaMarkTapArea extends StatelessWidget {
  const TipitakaMarkTapArea({super.key, required this.child});

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
