import 'package:flutter/material.dart';

import '../tokens.dart';

/// A thin line showing how far through something the person is. With
/// [rounded] the track and the filled part have round ends.
class ProgressLine extends StatelessWidget {
  const ProgressLine({
    super.key,
    required this.value,
    this.semanticsLabel = 'Reading progress',
    this.height = 2,
    this.rounded = false,
  });

  /// 0–1; anything outside is clamped.
  final double value;
  final String semanticsLabel;
  final double height;
  final bool rounded;

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    final fraction = value.clamp(0.0, 1.0);
    final radius = BorderRadius.circular(height / 2);
    return Semantics(
      container: true,
      label: semanticsLabel,
      value: '${(fraction * 100).round()}%',
      child: ExcludeSemantics(
        child: rounded
            ? Container(
                height: height,
                decoration: BoxDecoration(color: p.border, borderRadius: radius),
                alignment: AlignmentDirectional.centerStart,
                child: FractionallySizedBox(
                  widthFactor: fraction,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: p.sage, borderRadius: radius),
                    child: const SizedBox.expand(),
                  ),
                ),
              )
            : Container(
                height: height,
                color: p.border,
                alignment: AlignmentDirectional.centerStart,
                child: FractionallySizedBox(
                  widthFactor: fraction,
                  child: ColoredBox(color: p.sage),
                ),
              ),
      ),
    );
  }
}
