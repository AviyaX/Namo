import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../tokens.dart';
import '../typography.dart';
import 'pressable.dart';
import 'segmented_selector.dart';

/// A wrapping row of pills, one of which is chosen. The chosen pill has a
/// tint, sage words and a tick; the others a thin outline. It holds no state.
class ChoiceChips<T> extends StatelessWidget {
  const ChoiceChips({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<Segment<T>> options;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    const radius = BorderRadius.all(Radius.circular(NamoRadius.sm));
    return Wrap(
      spacing: NamoSpace.sm,
      runSpacing: NamoSpace.sm,
      children: [
        for (final o in options)
          Pressable(
            onTap: () => onSelected(o.value),
            borderRadius: radius,
            semanticLabel: o.label,
            selected: o.value == selected,
            excludeChildSemantics: true,
            child: Container(
              constraints: const BoxConstraints(
                minHeight: NamoSizes.touchTarget,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: NamoSpace.lg,
                vertical: NamoSpace.sm,
              ),
              decoration: BoxDecoration(
                color: o.value == selected
                    ? p.sageTint
                    : p.sageTint.withAlpha(0),
                borderRadius: radius,
                border: o.value == selected
                    ? Border.all(color: p.sageTint.withAlpha(0))
                    : Border.all(color: p.textMuted),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (o.value == selected) ...[
                    Icon(
                      Symbols.check_rounded,
                      size: NamoSizes.iconSmall,
                      weight: 300,
                      color: p.sage,
                    ),
                    const SizedBox(width: NamoSpace.xs),
                  ],
                  Flexible(
                    child: Text(
                      o.label,
                      style: NamoType.label(
                        o.value == selected ? p.sage : p.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
