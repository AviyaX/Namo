import 'package:flutter/material.dart';

import '../design/tokens.dart';
import '../design/typography.dart';
import '../design/widgets/segmented_selector.dart';
import '../reader/auto_scroll.dart';
import 'settings.dart';

/// The controls the Settings screen and the reader's settings sheet share.

/// A small quiet heading over a group of controls.
class SettingsHeading extends StatelessWidget {
  const SettingsHeading(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Semantics(
        header: true,
        child: Text(
          text,
          softWrap: true,
          style: namoText(
            NamoFonts.english,
            size: 14,
            color: p.textQuiet,
            weight: 600,
          ),
        ),
      ),
    );
  }
}

/// A row label, with an optional quiet hint under it.
class SettingLabel extends StatelessWidget {
  const SettingLabel(this.text, {super.key, this.hint});

  final String text;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        NamoSpace.lg,
        0,
        NamoSpace.lg,
        NamoSpace.xs,
      ),
      child: Semantics(
        header: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(text, softWrap: true, style: NamoType.label(p.text)),
            if (hint != null)
              Text(
                hint!,
                softWrap: true,
                style: NamoType.caption(p.textSecondary),
              ),
          ],
        ),
      ),
    );
  }
}

/// A slider on the app's colours: sage track and thumb on a border track.
class _NamoSlider extends StatelessWidget {
  const _NamoSlider({
    required this.sliderKey,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.semanticFormatterCallback,
    required this.onChanged,
  });

  final Key sliderKey;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String Function(double) semanticFormatterCallback;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        activeTrackColor: p.sage,
        inactiveTrackColor: p.border,
        thumbColor: p.sage,
      ),
      child: Slider(
        key: sliderKey,
        value: value.clamp(min, max),
        min: min,
        max: max,
        divisions: divisions,
        semanticFormatterCallback: semanticFormatterCallback,
        onChanged: onChanged,
      ),
    );
  }
}

/// Three preset speeds and a slider for any speed between; a slider value
/// that is not a preset shows 'Custom'.
class ScrollSpeedControl extends StatelessWidget {
  const ScrollSpeedControl({
    super.key,
    required this.sliderKey,
    required this.value,
    required this.onChanged,
  });

  final Key sliderKey;
  final double value;
  final ValueChanged<double> onChanged;

  static const _presets = [
    ('Slow', AutoScrollEngine.slow),
    ('Normal', AutoScrollEngine.normal),
    ('Fast', AutoScrollEngine.fast),
  ];

  static String? _presetName(double v) {
    for (final (name, speed) in _presets) {
      if (v == speed) return name;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    final range = AppSettings.scrollSpeedRange;
    final custom = _presetName(value) == null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        NamoSpace.lg,
        NamoSpace.xs,
        NamoSpace.lg,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedSelector<double>(
            semanticLabel: 'Speed presets',
            segments: [
              for (final (name, speed) in _presets) Segment(speed, name),
            ],
            selected: {
              for (final (_, speed) in _presets)
                if (value == speed) speed,
            },
            onPressed: onChanged,
          ),
          MergeSemantics(
            child: Semantics(
              label: 'Scroll speed',
              child: _NamoSlider(
                sliderKey: sliderKey,
                value: value,
                min: range.min,
                max: range.max,
                divisions: (range.max - range.min).round(),
                semanticFormatterCallback: (v) =>
                    _presetName(v) ?? 'Custom, ${v.round()}',
                onChanged: onChanged,
              ),
            ),
          ),
          // Under the slider, so the slider does not move when it appears.
          if (custom)
            Padding(
              padding: const EdgeInsets.only(bottom: NamoSpace.sm),
              child: ExcludeSemantics(
                child: Text(
                  'Custom',
                  softWrap: true,
                  style: NamoType.caption(p.textSecondary),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A labelled slider; the label and the slider are one control for screen
/// readers.
class SliderSetting extends StatelessWidget {
  const SliderSetting({
    super.key,
    required this.sliderKey,
    required this.label,
    required this.value,
    required this.range,
    required this.divisions,
    required this.describe,
    required this.onChanged,
  });

  /// The text-size slider, as on both screens that show it.
  const SliderSetting.textSize({
    super.key,
    required this.sliderKey,
    required this.value,
    required this.onChanged,
  }) : label = 'Text size',
       range = AppSettings.fontScaleRange,
       divisions = 15,
       describe = _percent;

  /// The line-spacing slider, as on both screens that show it.
  const SliderSetting.lineSpacing({
    super.key,
    required this.sliderKey,
    required this.value,
    required this.onChanged,
  }) : label = 'Line spacing',
       range = AppSettings.lineSpacingRange,
       divisions = 9,
       describe = _oneDecimal;

  static String _percent(double v) => '${(v * 100).round()}%';
  static String _oneDecimal(double v) => v.toStringAsFixed(1);

  final Key sliderKey;
  final String label;
  final double value;
  final ({double min, double max}) range;
  final int divisions;
  final String Function(double) describe;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(NamoSpace.lg, 0, NamoSpace.lg, 0),
      child: MergeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    softWrap: true,
                    style: NamoType.label(p.text),
                  ),
                ),
                ExcludeSemantics(
                  child: Text(
                    describe(value),
                    style: NamoType.caption(p.textSecondary),
                  ),
                ),
              ],
            ),
            _NamoSlider(
              sliderKey: sliderKey,
              value: value,
              min: range.min,
              max: range.max,
              divisions: divisions,
              semanticFormatterCallback: describe,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}
