import 'package:flutter/material.dart';

import '../design/tokens.dart';
import 'auto_scroll.dart';

/// Previous section, play and next section, under a 2-px progress line.
/// A null callback shows its button disabled.
class ReaderBottomBar extends StatelessWidget {
  const ReaderBottomBar({
    super.key,
    required this.onPrevious,
    required this.onNext,
    this.onPlay,
    this.autoScroll = AutoScrollStatus.stopped,
    this.progress = 0,
    this.audio,
  });

  /// The recording's controls, in a row of their own above the buttons;
  /// null when the reading has no recording.
  final Widget? audio;

  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  /// Starts, pauses or resumes auto-scroll.
  final VoidCallback? onPlay;

  /// Where auto-scroll is; sets the play button's icon and label.
  final AutoScrollStatus autoScroll;

  /// How far through the reading the page is, 0–1.
  final double progress;

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    final fraction = progress.clamp(0.0, 1.0);
    return Material(
      color: p.background,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              container: true,
              label: 'Reading progress',
              value: '${(fraction * 100).round()}%',
              child: ExcludeSemantics(
                child: Container(
                  height: 2,
                  color: p.divider,
                  alignment: AlignmentDirectional.centerStart,
                  child: FractionallySizedBox(
                    widthFactor: fraction,
                    child: ColoredBox(color: p.accent),
                  ),
                ),
              ),
            ),
            ?audio,
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
                    key: const ValueKey('reader-play'),
                    tooltip: switch (autoScroll) {
                      AutoScrollStatus.running => 'Pause auto-scroll',
                      AutoScrollStatus.paused => 'Resume auto-scroll',
                      AutoScrollStatus.stopped ||
                      AutoScrollStatus.finished => 'Start auto-scroll',
                    },
                    icon: Icon(
                      autoScroll == AutoScrollStatus.running
                          ? Icons.pause
                          : Icons.play_arrow,
                    ),
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
