import 'package:flutter/material.dart';

import '../audio/audio_controls.dart' show formatTime;
import '../design/tokens.dart';
import '../design/typography.dart';

/// The words shown in place of the slider when the recording cannot be
/// opened.
const chantFailedMessage = 'The recording could not be played.';

/// Where the chanting is: a slider with the time passed and the whole
/// length under it. Disabled (a null [onSeek]) until the recording is
/// loaded; a seek is made when the drag ends, not on every movement.
class ChantSlider extends StatefulWidget {
  const ChantSlider({
    super.key = const ValueKey('chant-slider'),
    required this.position,
    required this.duration,
    required this.onSeek,
  });

  final Duration position;

  /// Null until the length is known.
  final Duration? duration;
  final ValueChanged<Duration>? onSeek;

  @override
  State<ChantSlider> createState() => _ChantSliderState();
}

class _ChantSliderState extends State<ChantSlider> {
  /// The value under the thumb while it is held, in milliseconds.
  double? _dragging;

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    final style = NamoType.caption(p.textSecondary);
    final total = widget.duration;
    final max = total == null || total <= Duration.zero
        ? 1.0
        : total.inMilliseconds.toDouble();
    final enabled = widget.onSeek != null && total != null;
    final value = (_dragging ?? widget.position.inMilliseconds.toDouble())
        .clamp(0.0, max);
    final shown = Duration(microseconds: (value * 1000).round());
    final words = '${formatTime(shown)} of ${formatTime(total)}';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: p.sage,
            inactiveTrackColor: p.border,
            thumbColor: p.sage,
            disabledActiveTrackColor: p.border,
            disabledInactiveTrackColor: p.border,
            disabledThumbColor: p.border,
          ),
          // One node: the name and the value belong together.
          child: MergeSemantics(
            child: Semantics(
              label: 'Chanting position',
              child: Slider(
              value: value,
              min: 0,
              max: max,
              semanticFormatterCallback: (_) => words,
              onChanged: enabled ? (v) => setState(() => _dragging = v) : null,
              onChangeEnd: enabled
                  ? (v) {
                      setState(() => _dragging = null);
                      widget.onSeek!(Duration(microseconds: (v * 1000).round()));
                    }
                  : null,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: NamoSpace.md),
          child: ExcludeSemantics(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(formatTime(shown), style: style),
                Text(formatTime(total), style: style),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// [chantFailedMessage] where the slider would be. Announced when it
/// appears: the recording was asked for and is not coming.
class ChantFailed extends StatelessWidget {
  const ChantFailed({super.key});

  @override
  Widget build(BuildContext context) {
    final style = NamoType.caption(NamoPalette.of(context).textSecondary);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: NamoSpace.sm,
        vertical: NamoSpace.md,
      ),
      child: Semantics(
        liveRegion: true,
        container: true,
        label: chantFailedMessage,
        child: ExcludeSemantics(
          child: Text(chantFailedMessage, style: style),
        ),
      ),
    );
  }
}
