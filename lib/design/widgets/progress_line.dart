import 'package:flutter/material.dart';

import '../tokens.dart';

/// A thin line showing how far through something the person is.
class ProgressLine extends StatelessWidget {
  const ProgressLine({
    super.key,
    required this.value,
    this.semanticsLabel = 'Reading progress',
    this.height = 2,
  });

  /// 0–1; anything outside is clamped.
  final double value;
  final String semanticsLabel;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    final fraction = value.clamp(0.0, 1.0);
    return Semantics(
      container: true,
      label: semanticsLabel,
      value: '${(fraction * 100).round()}%',
      child: ExcludeSemantics(
        child: Container(
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
