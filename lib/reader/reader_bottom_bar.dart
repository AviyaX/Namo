import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../audio/chant_player.dart';
import '../audio/recording_store.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
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
    this.chantSpeed = 1.0,
    this.onChantSpeed,
    this.recording,
    this.onDownload,
    this.coverage,
  });

  /// How much of the reading the chant plays ("Chant plays 2 of 5
  /// sections"); null when it plays every section. Shown in the slider's
  /// place until the chant is first asked for.
  final String? coverage;

  /// Where the chanting's recording is; null when the store knows nothing
  /// of it. Until it is downloaded, its row takes the slider's place.
  final RecordingStatus? recording;

  /// Asks for the recording now.
  final VoidCallback? onDownload;

  /// Where the chanting of a timed recording is; null for a reading
  /// without one, whose bar is then unchanged. When set, the bar shows the
  /// position slider and the five chanting controls.
  final ChantState? chantState;

  /// Plays or pauses the chanting.
  final VoidCallback? onChantPlay;

  /// Starts the chanting again from the beginning; shown enabled only once a
  /// recording is loaded.
  final VoidCallback? onChantRestart;

  /// Moves the chanting to a place, when the person lets go of the slider.
  final ValueChanged<Duration>? onChantSeek;

  /// How fast the chanting plays, and the step to the next speed.
  final double chantSpeed;
  final VoidCallback? onChantSpeed;

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

  /// Restart, slider and speed; then previous, Scroll, Chant, next.
  List<Widget> _chantRows(NamoPalette p, ChantState state) {
    final loaded =
        state.status != ChantStatus.idle &&
        state.status != ChantStatus.loading &&
        state.status != ChantStatus.failed;
    final running = autoScroll == AutoScrollStatus.running;
    final status = recording;
    final missing =
        status != null && status.availability != Availability.downloaded;
    return [
      Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          NamoIconButton(
            key: const ValueKey('chant-restart'),
            tooltip: 'Restart chanting',
            icon: Symbols.replay_rounded,
            onPressed: loaded ? onChantRestart : null,
          ),
          Expanded(
            child: coverage != null && state.status == ChantStatus.idle
                ? Semantics(
                    liveRegion: true,
                    child: Text(
                      coverage!,
                      key: const ValueKey('chant-coverage'),
                      style: NamoType.caption(p.textSecondary),
                    ),
                  )
                : missing
                ? RecordingRow(status: status, onDownload: onDownload)
                : _ChantPosition(state: state, onSeek: onChantSeek),
          ),
          ChantSpeedButton(speed: chantSpeed, onPressed: onChantSpeed),
        ],
      ),
      _divider(p),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Centred on the round buttons, which are taller.
          SizedBox(
            height: _playSize,
            child: Center(
              child: NamoIconButton(
                key: const ValueKey('reader-prev'),
                tooltip: previousTooltip,
                icon: Symbols.skip_previous_rounded,
                onPressed: onPrevious,
              ),
            ),
          ),
          Flexible(
            child: _LabelledRound(
              key: const ValueKey('reader-autoscroll'),
              label: 'Scroll',
              button: Tooltip(
                message: switch (autoScroll) {
                  AutoScrollStatus.running => 'Pause auto-scroll',
                  AutoScrollStatus.paused => 'Resume auto-scroll',
                  AutoScrollStatus.stopped ||
                  AutoScrollStatus.finished => 'Start auto-scroll',
                },
                child: SizedBox.square(
                  dimension: _playSize,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: running ? p.sage : p.surface,
                      border: Border.all(color: p.sage, width: 1.5),
                    ),
                    child: Pressable(
                      onTap: onPlay,
                      borderRadius: BorderRadius.circular(_playSize / 2),
                      excludeChildSemantics: true,
                      child: Icon(
                        Symbols.swipe_vertical_rounded,
                        size: NamoSizes.icon,
                        weight: 300,
                        color: running ? p.onSage : p.sage,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Flexible(
            child: _LabelledRound(
              label: 'Chant',
              button: _ChantPlayButton(
                state: state,
                onPressed: onChantPlay,
                busy:
                    missing &&
                    status.availability == Availability.downloading,
              ),
            ),
          ),
          SizedBox(
            height: _playSize,
            child: Center(
              child: NamoIconButton(
                key: const ValueKey('reader-next'),
                tooltip: nextTooltip,
                icon: Symbols.skip_next_rounded,
                onPressed: onNext,
              ),
            ),
          ),
        ],
      ),
    ];
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
                if (chantState != null)
                  ..._chantRows(p, chantState!)
                else ...[
                  if (audio != null) ...[audio!, _divider(p)],
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A round button with its name written under it.
class _LabelledRound extends StatelessWidget {
  const _LabelledRound({super.key, required this.button, required this.label});

  final Widget button;
  final String label;

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        button,
        const SizedBox(height: NamoSpace.xs),
        // The button's own tooltip names it for screen readers.
        // The name shrinks to the room the Row gives it rather than push
        // the other buttons off the bar at the largest text sizes.
        FittedBox(
          fit: BoxFit.scaleDown,
          child: ExcludeSemantics(
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              style: NamoType.caption(p.textSecondary),
            ),
          ),
        ),
      ],
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
/// recording is loading or [busy] downloading.
class _ChantPlayButton extends StatelessWidget {
  const _ChantPlayButton({
    required this.state,
    required this.onPressed,
    this.busy = false,
  });

  final ChantState state;
  final VoidCallback? onPressed;

  /// The recording is downloading: a spinner that does nothing.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    final playing = state.status == ChantStatus.playing;
    final loading = busy || state.status == ChantStatus.loading;
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
                    playing
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
