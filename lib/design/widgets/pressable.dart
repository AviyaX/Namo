import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tokens.dart';

/// The one tappable primitive: at least 48 × 48, a tint on press and hover,
/// a ring on keyboard focus, Enter and Space to activate. It never changes
/// size or position. A null [onTap] shows nothing and announces "disabled".
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.onTap,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(NamoRadius.sm)),
    this.semanticLabel,
    this.selected,
    this.expanded,
    this.excludeChildSemantics = false,
  });

  final VoidCallback? onTap;
  final Widget child;
  final BorderRadius borderRadius;
  final String? semanticLabel;
  final bool? selected;

  /// For a control that opens and closes something: whether it is open now.
  final bool? expanded;

  /// Replace the child's own semantics with [semanticLabel].
  final bool excludeChildSemantics;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _pressed = false;
  bool _hovered = false;
  bool _focused = false;

  static const _activateKeys = <ShortcutActivator, Intent>{
    SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
    SingleActivator(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
    SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
  };

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    final enabled = widget.onTap != null;
    final tint = !enabled
        ? Colors.transparent
        : _pressed
        ? p.pressed
        : _hovered
        ? p.hovered
        : Colors.transparent;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      selected: widget.selected,
      expanded: widget.expanded,
      excludeSemantics: widget.excludeChildSemantics,
      onTap: widget.onTap,
      child: FocusableActionDetector(
        enabled: enabled,
        shortcuts: _activateKeys,
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onTap?.call();
              return null;
            },
          ),
        },
        onShowFocusHighlight: (v) => setState(() => _focused = v),
        child: MouseRegion(
          cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onTap,
            onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
            onTapUp: (_) => setState(() => _pressed = false),
            onTapCancel: () => setState(() => _pressed = false),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: NamoSizes.touchTarget,
                minHeight: NamoSizes.touchTarget,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  widget.child,
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedContainer(
                        key: const ValueKey('pressable-tint'),
                        duration: NamoMotion.of(context, NamoMotion.press),
                        curve: NamoMotion.curve,
                        decoration: BoxDecoration(
                          color: tint,
                          borderRadius: widget.borderRadius,
                        ),
                      ),
                    ),
                  ),
                  if (enabled && _focused)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          key: const ValueKey('pressable-focus-ring'),
                          decoration: BoxDecoration(
                            borderRadius: widget.borderRadius,
                            border: Border.all(color: p.sage, width: 2),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
