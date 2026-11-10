import 'package:flutter/material.dart';

import '../design/tokens.dart';

/// Previous section, play and next section, under a 2-px progress line.
/// A null callback shows its button disabled.
class ReaderBottomBar extends StatelessWidget {
  const ReaderBottomBar({
    super.key,
    required this.onPrevious,
    required this.onNext,
    this.onPlay,
    this.progress = 0,
  });

  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  /// Starts auto-scroll; wired in Task 11.
  final VoidCallback? onPlay;

  /// How far through the reading the page is, 0–1; driven by Task 10.
  final double progress;

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    return Material(
      color: p.background,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ExcludeSemantics(
              child: Container(
                height: 2,
                color: p.divider,
                alignment: AlignmentDirectional.centerStart,
                child: FractionallySizedBox(
                  widthFactor: progress.clamp(0.0, 1.0),
                  child: ColoredBox(color: p.accent),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    key: const ValueKey('reader-prev'),
                    tooltip: 'Previous section',
                    icon: const Icon(Icons.skip_previous),
                    onPressed: onPrevious,
                  ),
                  IconButton(
                    tooltip: 'Play',
                    icon: const Icon(Icons.play_arrow),
                    onPressed: onPlay,
                  ),
                  IconButton(
                    key: const ValueKey('reader-next'),
                    tooltip: 'Next section',
                    icon: const Icon(Icons.skip_next),
                    onPressed: onNext,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
