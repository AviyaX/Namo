import 'package:flutter/material.dart';

import '../audio/audio_controls.dart' show formatTime;
import '../design/tokens.dart';
import '../design/typography.dart';
import '../design/widgets/pressable.dart';
import '../settings/settings.dart';

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
                onChanged: enabled
                    ? (v) => setState(() => _dragging = v)
                    : null,
                onChangeEnd: enabled
                    ? (v) {
                        setState(() => _dragging = null);
                        widget.onSeek!(
                          Duration(microseconds: (v * 1000).round()),
                        );
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
              // Each time shrinks to its half rather than overflow at the
              // largest text sizes.
              children: [
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(formatTime(shown), style: style),
                  ),
                ),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(formatTime(total), style: style),
                  ),
                ),
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
        child: ExcludeSemantics(child: Text(chantFailedMessage, style: style)),
      ),
    );
  }
}

/// A chanting speed as written on the button: '0.75×', '1×', '1.25×'.
String speedLabel(double speed) {
  final digits = speed.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '');
  return '$digits×';
}

/// The chanting speed, written on a button that steps to the next speed.
class ChantSpeedButton extends StatelessWidget {
  const ChantSpeedButton({
    super.key = const ValueKey('chant-speed'),
    required this.speed,
    required this.onPressed,
  });

  final double speed;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    // Pressable is the root so the key finds its one semantics node; it
    // keeps the 48 x 48 minimum itself.
    return Pressable(
      onTap: onPressed,
      semanticLabel: 'Chanting speed ${speedLabel(speed)}',
      hint: 'Tap for ${speedLabel(AppSettings.nextChantSpeed(speed))}',
      excludeChildSemantics: true,
      child: Center(
        widthFactor: 1,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: NamoSpace.sm),
          child: Text(
            speedLabel(speed),
            maxLines: 1,
            softWrap: false,
            style: NamoType.label(onPressed == null ? p.textMuted : p.text),
          ),
        ),
      ),
    );
  }
}
