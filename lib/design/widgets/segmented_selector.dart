import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../tokens.dart';
import '../typography.dart';
import 'pressable.dart';

/// One choice in a [SegmentedSelector].
class Segment<T> {
  const Segment(this.value, this.label);

  final T value;
  final String label;
}

/// A few choices side by side in one track. With [multi] false a thumb slides
/// to the chosen one; with [multi] true each chosen one carries a tick and a
/// tint. When a label cannot fit its segment at the current text size the
/// segments stack in a column. It holds no state: [onPressed] is called for
/// every tap on an enabled segment, chosen or not.
class SegmentedSelector<T> extends StatelessWidget {
  const SegmentedSelector({
    super.key,
    required this.segments,
    required this.selected,
    required this.onPressed,
    required this.semanticLabel,
    this.multi = false,
    this.enabled = true,
    this.disabledHint,
  });

  final List<Segment<T>> segments;
  final Set<T> selected;
  final ValueChanged<T> onPressed;
  final bool multi;
  final bool enabled;
  final String semanticLabel;

  /// Announced on each segment while [enabled] is false.
  final String? disabledHint;

  static const _pad = NamoSpace.xs;
  static const _labelPad = NamoSpace.sm;
  static const _tickSpace = 24.0; // 20 icon + 4 gap

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    final style = NamoType.label(p.text);

    // Height of the tallest label when wrapped to [width], or null when a
    // label does not fit in two lines without breaking a word.
    double? labelHeight(double width) {
      var tallest = 0.0;
      final w = width > 0 ? width : 0.0;
      for (final s in segments) {
        final tp = TextPainter(
          text: TextSpan(text: s.label, style: style),
          textDirection: direction,
          textScaler: scaler,
        )..layout(maxWidth: w);
        final fits =
            tp.computeLineMetrics().length <= 2 && tp.minIntrinsicWidth <= w;
        final h = tp.height;
        tp.dispose();
        if (!fits) return null;
        if (h > tallest) tallest = h;
      }
      return tallest;
    }

    return SizedBox(
      width: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final inner = constraints.maxWidth - 2 * _pad;
          final n = segments.length;
          final reserve = 2 * _labelPad + (multi ? _tickSpace : 0);
          final rowH = labelHeight(inner / n - reserve);
          final stacked = rowH == null;
          final segW = stacked ? inner : inner / n;
          final textH = stacked
              ? (labelHeight(inner - reserve) ?? _twoLines(style, scaler))
              : rowH;
          final wanted = textH + 2 * NamoSpace.sm;
          final segH =
              wanted < NamoSizes.touchTarget ? NamoSizes.touchTarget : wanted;
          final trackH = stacked ? segH * n : segH;
          final chosen = multi
              ? -1
              : segments.indexWhere((s) => selected.contains(s.value));

          Widget segment(int i) {
            final s = segments[i];
            final on = selected.contains(s.value);
            final color = !enabled
                ? p.textMuted
                : multi
                    ? (on ? p.sage : p.textSecondary)
                    : (on ? p.text : p.textSecondary);
            return SizedBox(
              key: ValueKey('segment-$i'),
              width: segW,
              height: segH,
              child: Pressable(
                onTap: enabled ? () => onPressed(s.value) : null,
                borderRadius: BorderRadius.circular(NamoRadius.sm),
                semanticLabel: s.label,
                checked: on,
                inMutuallyExclusiveGroup: !multi,
                hint: enabled ? null : disabledHint,
                excludeChildSemantics: true,
                child: SizedBox.expand(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: multi && on ? p.sageTint : p.sageTint.withAlpha(0),
                      borderRadius: BorderRadius.circular(NamoRadius.sm),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: _labelPad,
                      ),
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (multi && on) ...[
                              Icon(
                                Symbols.check_rounded,
                                size: NamoSizes.iconSmall,
                                weight: 300,
                                color: enabled ? p.sage : p.textMuted,
                              ),
                              const SizedBox(width: NamoSpace.xs),
                            ],
                            Flexible(
                              child: Text(
                                s.label,
                                textAlign: TextAlign.center,
                                style: style.copyWith(color: color),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }

          return Semantics(
            container: true,
            label: semanticLabel,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: p.backgroundAlt,
                borderRadius: BorderRadius.circular(NamoRadius.sm),
              ),
              child: Padding(
                padding: const EdgeInsets.all(_pad),
                child: SizedBox(
                  height: trackH,
                  child: Stack(
                    children: [
                      if (chosen >= 0)
                        AnimatedPositioned(
                          key: const ValueKey('selector-thumb'),
                          duration: NamoMotion.of(context, NamoMotion.quick),
                          curve: NamoMotion.curve,
                          left: stacked ? 0 : chosen * segW,
                          top: stacked ? chosen * segH : 0,
                          width: segW,
                          height: segH,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: p.surface,
                              borderRadius:
                                  BorderRadius.circular(NamoRadius.sm),
                              border: Border.all(color: p.border),
                            ),
                          ),
                        ),
                      if (stacked)
                        Column(children: [
                          for (var i = 0; i < n; i++) segment(i),
                        ])
                      else
                        Row(children: [
                          for (var i = 0; i < n; i++) segment(i),
                        ]),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  static double _twoLines(TextStyle style, TextScaler scaler) =>
      scaler.scale(style.fontSize!) * (style.height ?? 1) * 2;
}
