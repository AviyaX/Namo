import 'package:flutter/material.dart';

import '../tokens.dart';

/// A bar that floats above the content: surface, hairline border, the app's
/// one shadow.
class FloatingBar extends StatelessWidget {
  const FloatingBar({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(NamoSpace.sm),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(NamoRadius.lg),
        border: Border.all(color: p.border),
        boxShadow: p.floatShadow,
      ),
      child: child,
    );
  }
}
