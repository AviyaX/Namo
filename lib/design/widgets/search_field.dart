import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../tokens.dart';
import '../typography.dart';
import 'buttons.dart';

/// A one-line search box: a quiet fill, a magnifier, the label as hint and
/// accessibility label, a clear button while there is text, and a sage ring
/// while it has focus. It never takes focus by itself; give it a
/// [focusNode] to focus it from outside.
class SearchField extends StatefulWidget {
  const SearchField({
    super.key,
    required this.controller,
    required this.label,
    this.onChanged,
    this.focusNode,
  });

  final TextEditingController controller;
  final String label;
  final ValueChanged<String>? onChanged;

  /// The field's focus node; when null the field makes (and disposes) its
  /// own. A given node is left for its owner to dispose.
  final FocusNode? focusNode;

  @override
  State<SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<SearchField> {
  FocusNode? _ownFocus;

  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode());

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    _focus.addListener(_changed);
  }

  @override
  void didUpdateWidget(SearchField old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
    }
    if (old.focusNode != widget.focusNode) {
      // The field's own node, once made, is kept until it is disposed: the
      // text field may still hold it in this frame.
      (old.focusNode ?? _ownFocus)?.removeListener(_changed);
      _focus.addListener(_changed);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    widget.focusNode?.removeListener(_changed);
    _ownFocus?.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _clear() {
    widget.controller.clear();
    widget.onChanged?.call('');
  }

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    final hasText = widget.controller.text.isNotEmpty;
    const radius = BorderRadius.all(Radius.circular(NamoRadius.sm));
    return Stack(
      children: [
        Container(
          constraints: const BoxConstraints(minHeight: NamoSizes.touchTarget),
          padding: const EdgeInsetsDirectional.only(start: NamoSpace.lg),
          decoration: BoxDecoration(
            color: p.backgroundAlt,
            borderRadius: radius,
          ),
          child: Row(
            children: [
              Icon(
                Symbols.search_rounded,
                size: NamoSizes.iconSmall,
                weight: 300,
                fill: 0,
                color: p.textSecondary,
              ),
              const SizedBox(width: NamoSpace.md),
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: NamoSizes.touchTarget,
                  ),
                  child: TextField(
                    controller: widget.controller,
                    focusNode: _focus,
                    onChanged: widget.onChanged,
                    style: NamoType.body(p.text),
                    cursorColor: p.sage,
                    textInputAction: TextInputAction.search,
                    textAlignVertical: TextAlignVertical.center,
                    decoration: InputDecoration(
                      isCollapsed: true,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: NamoSpace.md,
                      ),
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      hintText: widget.label,
                      hintStyle: NamoType.body(p.textSecondary),
                    ),
                  ),
                ),
              ),
              if (hasText)
                NamoIconButton(
                  icon: Symbols.close_rounded,
                  tooltip: 'Clear search',
                  size: NamoSizes.iconSmall,
                  color: p.textSecondary,
                  onPressed: _clear,
                )
              else
                const SizedBox(width: NamoSpace.lg),
            ],
          ),
        ),
        if (_focus.hasFocus)
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                key: const ValueKey('search-focus-ring'),
                decoration: BoxDecoration(
                  borderRadius: radius,
                  border: Border.all(color: p.sage, width: 2),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
