import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../audio/chant_player.dart';
import '../design/tokens.dart';
import '../design/widgets/buttons.dart';
import '../design/widgets/floating_bar.dart';
import '../design/widgets/pressable.dart';
import 'auto_scroll.dart';
import 'chant_bar.dart';

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
    this.previousTooltip = 'Previous section',
    this.nextTooltip = 'Next section',
    this.chantState,
    this.onChantPlay,
    this.onChantRestart,
    this.onChantSeek,
  });

  /// Where the chanting of a timed recording is; null for a reading
  /// without one, whose bar is then unchanged. When set, the bar shows the
  /// position slider and the five chanting controls.
  final ChantState? chantState;

  /// Plays or pauses the chanting.
  final VoidCallback? onChantPlay;

  /// Starts the chanting again from the beginning.
  final VoidCallback? onChantRestart;

  /// Moves the chanting to a place, when the person lets go of the slider.
  final ValueChanged<Duration>? onChantSeek;

  /// What the two outer buttons are called (a pirith's go to the previous
  /// and next pirith).
  final String previousTooltip, nextTooltip;

  /// The recording's controls, above the buttons inside the same bar; null
  /// when the reading has no recording.
  final Widget? audio;

  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  /// Starts, pauses or resumes auto-scroll.
  final VoidCallback? onPlay;

  /// Where auto-scroll is; sets the play button's icon and label.
  final AutoScrollStatus autoScroll;

  static Widget _divider(NamoPalette p) => Padding(
    padding: const EdgeInsets.symmetric(vertical: NamoSpace.xs),
    child: SizedBox(height: 1, child: ColoredBox(color: p.border)),
  );

  /// Previous, auto-scroll, chanting, restart, next.
  Widget _chantRow(ChantState state) {
    final loaded =
        state.status != ChantStatus.idle &&
        state.status != ChantStatus.loading &&
        state.status != ChantStatus.failed;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        NamoIconButton(
          key: const ValueKey('reader-prev'),
          tooltip: previousTooltip,
          icon: Symbols.skip_previous_rounded,
          onPressed: onPrevious,
        ),
        NamoIconButton(
          key: const ValueKey('reader-autoscroll'),
          tooltip: switch (autoScroll) {
            AutoScrollStatus.running => 'Pause auto-scroll',
            AutoScrollStatus.paused => 'Resume auto-scroll',
            AutoScrollStatus.stopped ||
            AutoScrollStatus.finished => 'Start auto-scroll',
          },
          icon: Symbols.swipe_vertical_rounded,
          // Filled while the page is scrolling by itself.
          filled: autoScroll == AutoScrollStatus.running,
          onPressed: onPlay,
        ),
        _ChantPlayButton(state: state, onPressed: onChantPlay),
        NamoIconButton(
          key: const ValueKey('chant-restart'),
          tooltip: 'Restart chanting',
          icon: Symbols.replay_rounded,
          onPressed: loaded ? onChantRestart : null,
        ),
        NamoIconButton(
          key: const ValueKey('reader-next'),
          tooltip: nextTooltip,
          icon: Symbols.skip_next_rounded,
          onPressed: onNext,
        ),
      ],
    );
  }

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
                if (chantState != null) ...[
                  _ChantPosition(state: chantState!, onSeek: onChantSeek),
                  _divider(p),
                ] else if (audio != null) ...[
                  audio!,
                  _divider(p),
                ],
                if (chantState != null)
                  _chantRow(chantState!)
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      NamoIconButton(
                        key: const ValueKey('reader-prev'),
                        tooltip: previousTooltip,
                        icon: Symbols.skip_previous_rounded,
                        onPressed: onPrevious,
                      ),
                      const SizedBox(width: NamoSpace.xl),
                      _PlayButton(status: autoScroll, onPressed: onPlay),
                      const SizedBox(width: NamoSpace.xl),
                      NamoIconButton(
                        key: const ValueKey('reader-next'),
                        tooltip: nextTooltip,
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

/// The slider, or the failure in its place.
class _ChantPosition extends StatelessWidget {
  const _ChantPosition({required this.state, required this.onSeek});

  final ChantState state;
  final ValueChanged<Duration>? onSeek;

  @override
  Widget build(BuildContext context) {
    if (state.status == ChantStatus.failed) return const ChantFailed();
    final loaded =
        state.status != ChantStatus.idle && state.status != ChantStatus.loading;
    return ChantSlider(
      position: state.position,
      duration: state.duration,
      onSeek: loaded ? onSeek : null,
    );
  }
}

/// The round sage chanting button: play or pause, a spinner while the
/// recording is loading.
class _ChantPlayButton extends StatelessWidget {
  const _ChantPlayButton({required this.state, required this.onPressed});

  final ChantState state;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    final playing = state.status == ChantStatus.playing;
    final loading = state.status == ChantStatus.loading;
    return Tooltip(
      key: const ValueKey('chant-play'),
      message: playing ? 'Pause chanting' : 'Play chanting',
      child: SizedBox.square(
        dimension: _playSize,
        child: DecoratedBox(
          decoration: BoxDecoration(color: p.sage, shape: BoxShape.circle),
          child: Pressable(
            onTap: loading ? null : onPressed,
            borderRadius: BorderRadius.circular(_playSize / 2),
            excludeChildSemantics: true,
            child: loading
                ? Center(
                    child: SizedBox.square(
                      dimension: NamoSizes.icon,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: p.onSage,
                        // A still ring when the person has asked for no
                        // animation.
                        value:
                            NamoMotion.of(context, NamoMotion.quick) ==
                                Duration.zero
                            ? 1
                            : null,
                      ),
                    ),
                  )
                : Icon(
                    playing ? Symbols.pause_rounded : Symbols.play_arrow_rounded,
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
