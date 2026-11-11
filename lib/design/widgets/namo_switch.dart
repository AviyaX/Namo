import 'package:flutter/material.dart';

import '../tokens.dart';

/// A Material switch on the app's colours: a sage track when on, a border
/// track with a muted outline when off. The thumb sits at the end when on,
/// at the start when off, so state is not shown by colour alone.
class NamoSwitch extends StatelessWidget {
  const NamoSwitch({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    return Switch(
      value: value,
      onChanged: onChanged,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      thumbColor: WidgetStatePropertyAll(value ? p.onSage : p.textSecondary),
      trackColor: WidgetStatePropertyAll(value ? p.sage : p.border),
      trackOutlineColor: WidgetStatePropertyAll(value ? p.sage : p.textMuted),
    );
  }
}
