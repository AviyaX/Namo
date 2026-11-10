import 'package:flutter/material.dart';

import '../tokens.dart';
import '../typography.dart';
import 'pressable.dart';

const _buttonRadius = BorderRadius.all(Radius.circular(NamoRadius.sm));

/// A round icon button: a [Pressable] circle with a tooltip. [filled] is for
/// an active or saved state.
class NamoIconButton extends StatelessWidget {
  const NamoIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
    this.filled = false,
    this.size = NamoSizes.icon,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final Color? color;
  final bool filled;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    return Tooltip(
      message: tooltip,
      child: Pressable(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(NamoSizes.touchTarget / 2),
        // One node, named by the tooltip: without this the focus node
        // inside is a second, unlabelled tap target.
        excludeChildSemantics: true,
        child: Icon(
          icon,
          size: size,
          weight: 300,
          fill: filled ? 1 : 0,
          color: onPressed == null ? p.textMuted : (color ?? p.text),
        ),
      ),
    );
  }
}

/// Shared shape of the three text buttons.
class _ButtonBody extends StatelessWidget {
  const _ButtonBody({
    required this.label,
    required this.onPressed,
    required this.icon,
    required this.labelColor,
    required this.fill,
    required this.outline,
    this.trailingIcon = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool trailingIcon;
  final Color labelColor;
  final Color? fill;
  final Color? outline;

  @override
  Widget build(BuildContext context) {
    final glyph = icon == null
        ? null
        : Icon(icon, size: NamoSizes.iconSmall, weight: 300, color: labelColor);
    return Pressable(
      onTap: onPressed,
      borderRadius: _buttonRadius,
      semanticLabel: label,
      excludeChildSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: NamoSizes.touchTarget),
        padding: const EdgeInsets.symmetric(
            horizontal: NamoSpace.lg, vertical: NamoSpace.sm),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: _buttonRadius,
          border: outline == null ? null : Border.all(color: outline!),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (glyph != null && !trailingIcon) ...[
              glyph,
              const SizedBox(width: NamoSpace.sm),
            ],
            Flexible(
              child: Text(label,
                  textAlign: TextAlign.center,
                  style: NamoType.label(labelColor)),
            ),
            if (glyph != null && trailingIcon) ...[
              const SizedBox(width: NamoSpace.sm),
              glyph,
            ],
          ],
        ),
      ),
    );
  }
}

/// The main action: sage fill.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    final enabled = onPressed != null;
    return _ButtonBody(
      label: label,
      icon: icon,
      onPressed: onPressed,
      labelColor: enabled ? p.onSage : p.textMuted,
      fill: enabled ? p.sage : p.border,
      outline: null,
    );
  }
}

/// A secondary action: no fill, a thin outline.
class QuietButton extends StatelessWidget {
  const QuietButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    return _ButtonBody(
      label: label,
      icon: icon,
      onPressed: onPressed,
      labelColor: onPressed != null ? p.text : p.textMuted,
      fill: null,
      outline: p.textMuted,
    );
  }
}

/// A light action: sage words, no fill or outline, an optional trailing icon.
class TextAction extends StatelessWidget {
  const TextAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    return _ButtonBody(
      label: label,
      icon: icon,
      trailingIcon: true,
      onPressed: onPressed,
      labelColor: onPressed != null ? p.sage : p.textMuted,
      fill: null,
      outline: null,
    );
  }
}
