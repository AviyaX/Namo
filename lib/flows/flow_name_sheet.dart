import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/tokens.dart';
import '../design/typography.dart';
import '../design/widgets/buttons.dart';
import '../design/widgets/sheet_frame.dart';
import 'flows.dart' show flowNameMax;

/// Opens [builder]'s sheet (a [FlowSheetScaffold]) over the whole app, the
/// way the reader settings open.
Future<T?> showFlowSheet<T>(BuildContext context, WidgetBuilder builder) =>
    showModalBottomSheet<T>(
      context: context,
      // Over the tab bar too, as the reader's sheet is.
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      // The frame draws its own surface, corners and shadow.
      shape: const RoundedRectangleBorder(),
      clipBehavior: Clip.none,
      constraints: const BoxConstraints(),
      sheetAnimationStyle: AnimationStyle(
        duration: NamoMotion.of(context, NamoMotion.open),
        reverseDuration: NamoMotion.of(context, NamoMotion.close),
        curve: NamoMotion.curve,
        reverseCurve: NamoMotion.curve,
      ),
      builder: builder,
    );

/// The space a flow sheet's route gives, with [frame] at the bottom. It has
/// its own messenger so a message shows on top of the sheet; it moves up
/// above the on-screen keyboard; a tap on the empty part above closes the
/// sheet as the barrier would.
class FlowSheetScaffold extends StatelessWidget {
  const FlowSheetScaffold({super.key, required this.frame});

  final SheetFrame frame;

  @override
  Widget build(BuildContext context) => ScaffoldMessenger(
    child: Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // The barrier already offers dismissal to screen readers.
          Positioned.fill(
            child: ExcludeSemantics(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => Navigator.of(context).pop(),
              ),
            ),
          ),
          Align(alignment: Alignment.bottomCenter, child: frame),
        ],
      ),
    ),
  );
}

/// The one-line "Name" box of a flow: at most [flowNameMax] characters, so
/// a long paste is cut to fit. Being one line, it drops a pasted line break
/// (Flutter's own rule for a one-line field).
class FlowNameField extends StatefulWidget {
  const FlowNameField({
    super.key,
    required this.controller,
    this.autofocus = false,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;

  @override
  State<FlowNameField> createState() => _FlowNameFieldState();
}

class _FlowNameFieldState extends State<FlowNameField> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_changed);
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    const radius = BorderRadius.all(Radius.circular(NamoRadius.sm));
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: color, width: width),
    );
    return TextField(
      key: const ValueKey('flow-name-field'),
      controller: widget.controller,
      focusNode: _focus,
      autofocus: widget.autofocus,
      onSubmitted: widget.onSubmitted,
      maxLength: flowNameMax,
      maxLengthEnforcement: MaxLengthEnforcement.enforced,
      inputFormatters: [LengthLimitingTextInputFormatter(flowNameMax)],
      maxLines: 1,
      keyboardType: TextInputType.text,
      textInputAction: TextInputAction.done,
      textCapitalization: TextCapitalization.sentences,
      style: NamoType.body(p.text),
      cursorColor: p.sage,
      decoration: InputDecoration(
        labelText: 'Name',
        floatingLabelBehavior: FloatingLabelBehavior.always,
        labelStyle: NamoType.label(p.textSecondary),
        floatingLabelStyle: NamoType.label(
          _focus.hasFocus ? p.sage : p.textSecondary,
        ),
        counterStyle: NamoType.caption(p.textSecondary),
        filled: true,
        fillColor: p.backgroundAlt,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: NamoSpace.lg,
          vertical: NamoSpace.md,
        ),
        border: border(p.backgroundAlt, 1),
        enabledBorder: border(p.backgroundAlt, 1),
        focusedBorder: border(p.sage, 2),
      ),
    );
  }
}

/// Asks for a flow's name under [title], starting from [initial]. Returns
/// the text as typed when [action] is pressed (or Done on the keyboard), or
/// null when the sheet is dismissed. The caller applies the name rule.
Future<String?> showFlowNameSheet(
  BuildContext context, {
  required String title,
  required String initial,
  required String action,
}) => showFlowSheet<String>(
  context,
  (_) => _FlowNameSheet(title: title, initial: initial, action: action),
);

class _FlowNameSheet extends StatefulWidget {
  const _FlowNameSheet({
    required this.title,
    required this.initial,
    required this.action,
  });

  final String title, initial, action;

  @override
  State<_FlowNameSheet> createState() => _FlowNameSheetState();
}

class _FlowNameSheetState extends State<_FlowNameSheet> {
  late final _name = TextEditingController(text: widget.initial)
    ..selection = TextSelection(
      baseOffset: 0,
      extentOffset: widget.initial.length,
    );

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _confirm() => Navigator.of(context).pop(_name.text);

  @override
  Widget build(BuildContext context) => FlowSheetScaffold(
    frame: SheetFrame(
      title: widget.title,
      children: [
        FlowNameField(
          controller: _name,
          autofocus: true,
          onSubmitted: (_) => _confirm(),
        ),
        const SizedBox(height: NamoSpace.lg),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: PrimaryButton(
            key: const ValueKey('flow-name-confirm'),
            label: widget.action,
            onPressed: _confirm,
          ),
        ),
      ],
    ),
  );
}
