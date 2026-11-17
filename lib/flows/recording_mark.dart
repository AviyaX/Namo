import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../design/tokens.dart';

/// A small mark beside a section that has a recording, so a person can see
/// which sections of a flow will chant.
class RecordingMark extends StatelessWidget {
  const RecordingMark({super.key});

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    return Semantics(
      label: 'Has a recording',
      child: Icon(
        Symbols.graphic_eq_rounded,
        size: NamoSizes.iconSmall,
        weight: 300,
        color: p.sage,
      ),
    );
  }
}
