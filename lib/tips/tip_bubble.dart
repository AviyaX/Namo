import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../design/tokens.dart';
import '../design/typography.dart';
import '../design/widgets/buttons.dart';
import 'tips.dart';

/// The words of a tip and its "Got it" button, in the floating bar's look.
class TipBubble extends StatefulWidget {
  const TipBubble({
    super.key = const ValueKey('tip-bubble'),
    required this.tip,
    required this.onGotIt,
  });

  final Tip tip;
  final VoidCallback onGotIt;

  @override
  State<TipBubble> createState() => _TipBubbleState();
}

class _TipBubbleState extends State<TipBubble> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tip = widget.tip;
    final p = NamoPalette.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Semantics(
        container: true,
        // "Got it" stays a button of its own, read after the words, which
        // come before the scrim's "Dismiss tip".
        explicitChildNodes: true,
        sortKey: const OrdinalSortKey(0),
        liveRegion: true,
        label: '${tip.title}. ${tip.body}',
        child: Container(
          padding: const EdgeInsets.all(NamoSpace.lg),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(NamoRadius.lg),
            border: Border.all(color: p.border),
            boxShadow: p.floatShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // The label above reads these; they are not read twice. With
              // large text on a small screen the words scroll and the button
              // stays in reach; a thin bar at the side shows there is more.
              Flexible(
                child: ExcludeSemantics(
                  child: RawScrollbar(
                    controller: _scroll,
                    thumbVisibility: true,
                    // No fade with reduced motion.
                    fadeDuration: NamoMotion.of(context, NamoMotion.open),
                    thumbColor: p.textSecondary.withValues(alpha: 0.5),
                    radius: const Radius.circular(NamoRadius.sm),
                    thickness: 3,
                    child: SingleChildScrollView(
                      controller: _scroll,
                      // The words keep clear of the bar.
                      padding: const EdgeInsetsDirectional.only(
                        end: NamoSpace.sm,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tip.title, style: NamoType.label(p.text)),
                          const SizedBox(height: NamoSpace.xs),
                          Text(tip.body, style: NamoType.body(p.text)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: NamoSpace.md),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: PrimaryButton(
                  key: const ValueKey('tip-got-it'),
                  label: 'Got it',
                  onPressed: widget.onGotIt,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
