import 'package:flutter/material.dart';

import '../design/tokens.dart';
import '../design/typography.dart';
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
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              for (final (i, (name, speed)) in _presets.indexed) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(
                  child: _SpeedChoice(
                    label: name,
                    selected: value == speed,
                    onTap: () => onChanged(speed),
                  ),
                ),
              ],
            ],
          ),
          MergeSemantics(
            child: Semantics(
              label: 'Scroll speed',
              child: Slider(
                key: sliderKey,
                value: value.clamp(range.min, range.max),
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
              padding: const EdgeInsets.only(bottom: 8),
              child: ExcludeSemantics(
                child: Text(
                  'Custom',
                  softWrap: true,
                  style: namoText(
                    NamoFonts.english,
                    size: 14,
                    color: p.textQuiet,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One preset speed: a hairline-bordered button, outlined in the heading
/// colour when it is on.
class _SpeedChoice extends StatelessWidget {
  const _SpeedChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    final radius = BorderRadius.circular(8);
    return Semantics(
      container: true,
      excludeSemantics: true,
      button: true,
      selected: selected,
      label: label,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        splashFactory: NoSplash.splashFactory,
        highlightColor: p.surface,
        hoverColor: p.surface,
        focusColor: p.focus,
        child: Container(
          constraints: const BoxConstraints(minHeight: NamoSizes.touchTarget),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: selected ? p.heading : p.divider,
              width: 1,
            ),
          ),
          child: Text(
            label,
            softWrap: true,
            textAlign: TextAlign.center,
            style: namoText(
              NamoFonts.english,
              size: 16,
              color: selected ? p.heading : p.text,
              weight: selected ? 600 : 400,
            ),
          ),
        ),
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
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
                    style: namoText(
                      NamoFonts.english,
                      size: 14,
                      color: p.textQuiet,
                      weight: 600,
                    ),
                  ),
                ),
                ExcludeSemantics(
                  child: Text(
                    describe(value),
                    style: namoText(
                      NamoFonts.english,
                      size: 14,
                      color: p.textQuiet,
                    ),
                  ),
                ),
              ],
            ),
            Slider(
              key: sliderKey,
              value: value.clamp(range.min, range.max),
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
