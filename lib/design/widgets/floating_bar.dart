import 'package:flutter/material.dart';

import '../tokens.dart';

/// A bar that floats above the content: surface, hairline border, the app's
/// one shadow.
class FloatingBar extends StatelessWidget {
  const FloatingBar({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(NamoSpace.sm),
    this.pill = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  /// A full pill (the app's bottom bar) instead of the rounded card shape.
  final bool pill;

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(pill ? 999 : NamoRadius.lg),
        border: Border.all(color: p.border),
        boxShadow: p.floatShadow,
      ),
      child: child,
    );
  }
}
