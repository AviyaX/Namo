import 'package:flutter/material.dart';

import '../design/tokens.dart';
import '../design/typography.dart';
import '../design/widgets/buttons.dart';
import 'tips.dart';

/// The words of a tip and its "Got it" button, in the floating bar's look.
class TipBubble extends StatelessWidget {
  const TipBubble({
    super.key = const ValueKey('tip-bubble'),
    required this.tip,
    required this.onGotIt,
  });

  final Tip tip;
  final VoidCallback onGotIt;

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Semantics(
        container: true,
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
              // The label above reads these; they are not read twice.
              ExcludeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tip.title, style: NamoType.label(p.text)),
                    const SizedBox(height: NamoSpace.xs),
                    Text(tip.body, style: NamoType.body(p.text)),
                  ],
                ),
              ),
              const SizedBox(height: NamoSpace.md),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: PrimaryButton(
                  key: const ValueKey('tip-got-it'),
                  label: 'Got it',
                  onPressed: onGotIt,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
