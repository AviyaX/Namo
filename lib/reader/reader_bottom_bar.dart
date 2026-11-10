import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../design/tokens.dart';
import '../design/widgets/buttons.dart';
import '../design/widgets/floating_bar.dart';
import '../design/widgets/pressable.dart';
import 'auto_scroll.dart';

/// The size of the round auto-scroll button.
const _playSize = 56.0;

/// Previous section, play and next section, on a bar that floats over the
/// foot of the text: 16 from each side, 12 above the bottom safe area, at
/// most [NamoSizes.readingColumn] wide. A null callback shows its button
/// disabled.
///
/// Placed as the scaffold's bottom bar with the body extended under it, so
/// the body sees this whole height in `MediaQuery.padding.bottom`.
class ReaderBottomBar extends StatelessWidget {
  const ReaderBottomBar({
    super.key,
    required this.onPrevious,
    required this.onNext,
    this.onPlay,
    this.autoScroll = AutoScrollStatus.stopped,
    this.audio,
  });

  /// The recording's controls, above the buttons inside the same bar; null
  /// when the reading has no recording.
  final Widget? audio;

  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  /// Starts, pauses or resumes auto-scroll.
  final VoidCallback? onPlay;

  /// Where auto-scroll is; sets the play button's icon and label.
  final AutoScrollStatus autoScroll;

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    final inset = MediaQuery.paddingOf(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        NamoSpace.lg + inset.left,
        0,
        NamoSpace.lg + inset.right,
        NamoSpace.md + inset.bottom,
      ),
      child: Align(
        alignment: Alignment.bottomCenter,
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: NamoSizes.readingColumn),
          child: FloatingBar(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (audio != null) ...[
                  audio!,
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: NamoSpace.xs),
                    child: SizedBox(
                      height: 1,
                      child: ColoredBox(color: p.border),
                    ),
                  ),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    NamoIconButton(
                      key: const ValueKey('reader-prev'),
                      tooltip: 'Previous section',
                      icon: Symbols.skip_previous_rounded,
                      onPressed: onPrevious,
                    ),
                    const SizedBox(width: NamoSpace.xl),
                    _PlayButton(status: autoScroll, onPressed: onPlay),
                    const SizedBox(width: NamoSpace.xl),
                    NamoIconButton(
                      key: const ValueKey('reader-next'),
                      tooltip: 'Next section',
                      icon: Symbols.skip_next_rounded,
                      onPressed: onNext,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The round sage auto-scroll button; its label follows [status].
class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.status, required this.onPressed});

  final AutoScrollStatus status;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    return Tooltip(
      key: const ValueKey('reader-play'),
      message: switch (status) {
        AutoScrollStatus.running => 'Pause auto-scroll',
        AutoScrollStatus.paused => 'Resume auto-scroll',
        AutoScrollStatus.stopped ||
        AutoScrollStatus.finished => 'Start auto-scroll',
      },
      child: SizedBox.square(
        dimension: _playSize,
        child: DecoratedBox(
          decoration: BoxDecoration(color: p.sage, shape: BoxShape.circle),
          child: Pressable(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(_playSize / 2),
            // One node, named by the tooltip.
            excludeChildSemantics: true,
            child: Icon(
              status == AutoScrollStatus.running
                  ? Symbols.pause_rounded
                  : Symbols.play_arrow_rounded,
              size: NamoSizes.icon,
              weight: 300,
              color: p.onSage,
            ),
          ),
        ),
      ),
    );
  }
}
