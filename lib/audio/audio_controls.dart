import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../design/tokens.dart';
import '../design/typography.dart';
import '../design/widgets/buttons.dart';
import 'audio_catalogue.dart';
import 'chant_player.dart';

/// A time as `m:ss`; an unknown one as `–:––`.
String formatTime(Duration? d) {
  if (d == null) return '–:––';
  final seconds = d.inSeconds;
  return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}

const _failedMessage = 'The recording could not be played.';

/// Play or pause, restart, and the time, for [recording]. The reader loads
/// the recording into the player.
class AudioControls extends ConsumerWidget {
  const AudioControls({super.key, required this.recording});

  final Recording recording;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(chantPlayerProvider);
    return StreamBuilder<ChantState>(
      stream: player.states,
      initialData: player.state,
      builder: (context, snapshot) =>
          _Controls(recording, player, snapshot.requireData),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls(this.recording, this.player, this.state);

  final Recording recording;
  final ChantPlayer player;
  final ChantState state;

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    final style = NamoType.caption(p.textSecondary);
    if (state.status == ChantStatus.failed) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: NamoSpace.sm,
          vertical: NamoSpace.md,
        ),
        // Announced when it appears: the recording was asked for and is not
        // coming.
        child: Semantics(
          liveRegion: true,
          container: true,
          label: _failedMessage,
          child: ExcludeSemantics(child: Text(_failedMessage, style: style)),
        ),
      );
    }
    final playing = state.status == ChantStatus.playing;
    final ready =
        state.status != ChantStatus.idle && state.status != ChantStatus.loading;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (recording.placeholder)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              NamoSpace.sm,
              NamoSpace.xs,
              NamoSpace.sm,
              0,
            ),
            child: Semantics(
              container: true,
              label: recording.label,
              child: ExcludeSemantics(
                child: Text(recording.label, maxLines: 2, style: style),
              ),
            ),
          ),
        Row(
          children: [
            NamoIconButton(
              key: const ValueKey('audio-play'),
              tooltip: playing ? 'Pause recording' : 'Play recording',
              icon: playing
                  ? Symbols.pause_circle_rounded
                  : Symbols.play_circle_rounded,
              onPressed: ready
                  ? () => playing ? player.pause() : player.play()
                  : null,
            ),
            NamoIconButton(
              key: const ValueKey('audio-restart'),
              tooltip: 'Restart recording',
              icon: Symbols.replay_rounded,
              onPressed: ready ? player.restart : null,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsetsDirectional.only(end: NamoSpace.sm),
                child: Text(
                  '${formatTime(state.position)} / '
                  '${formatTime(state.duration)}',
                  textAlign: TextAlign.end,
                  style: NamoType.label(p.textSecondary),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
