import 'package:flutter/material.dart';

import '../tokens.dart';
import 'pressable.dart';

/// A flat card: a soft surface-to-backgroundAlt gradient, a 1 px border, no
/// shadow. With [onTap] the whole
/// card is one [Pressable]; [leadingLine] draws a 2 px line down its leading
/// edge.
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(NamoSpace.lg),
    this.radius = NamoRadius.card,
    this.onTap,
    this.semanticLabel,
    this.leadingLine,
    this.framed = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final Color? leadingLine;

  /// True for a featured or gatha card: the border is the gold [NamoPalette.frame].
  final bool framed;

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    final shape = BorderRadius.circular(radius);
    final card = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [p.surface, p.backgroundAlt],
        ),
        borderRadius: shape,
        border: Border.all(color: framed ? p.frame : p.border),
      ),
      child: ClipRRect(
        borderRadius: shape,
        child: Stack(
          children: [
            Padding(padding: padding, child: child),
            if (leadingLine != null)
              PositionedDirectional(
                start: 0,
                top: 0,
                bottom: 0,
                width: 2,
                child: ColoredBox(
                  key: const ValueKey('surface-card-leading-line'),
                  color: leadingLine!,
                ),
              ),
          ],
        ),
      ),
    );
    if (onTap == null) return card;
    return Pressable(
      onTap: onTap,
      borderRadius: shape,
      semanticLabel: semanticLabel,
      excludeChildSemantics: semanticLabel != null,
      // Keeps the card's full width inside the Pressable's loose layout.
      child: LayoutBuilder(
        builder: (context, c) => SizedBox(
          width: c.hasBoundedWidth ? double.infinity : null,
          child: card,
        ),
      ),
    );
  }
}
