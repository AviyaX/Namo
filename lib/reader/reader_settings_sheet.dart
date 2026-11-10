import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/tokens.dart';
import '../design/typography.dart';
import '../settings/settings.dart';
import '../settings/settings_screen.dart';
import 'auto_scroll.dart';

/// Opens the reader settings over the reader.
Future<void> showReaderSettingsSheet(
  BuildContext context, {
  required VoidCallback onBackToBeginning,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => ReaderSettingsSheet(onBackToBeginning: onBackToBeginning),
);

/// Languages, layout, text size, line spacing and scroll speed. Each change
/// applies to the reader at once.
class ReaderSettingsSheet extends ConsumerWidget {
  const ReaderSettingsSheet({super.key, required this.onBackToBeginning});

  /// Called after the sheet closes for 'Back to the beginning'.
  final VoidCallback onBackToBeginning;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(settingsProvider.notifier);
    final p = NamoPalette.of(context);
    // The sheet has its own messenger so the choosers' messages show on top
    // of it rather than on the reader underneath. A Scaffold needs a set
    // height; the content scrolls within it.
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.6,
      child: ScaffoldMessenger(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _SheetTitle('Reading languages'),
                  const LanguageChooser(),
                  const _SheetTitle('When two languages show'),
                  const LayoutChooser(),
                  _SliderRow(
                    sliderKey: const ValueKey('reader-text-size'),
                    label: 'Text size',
                    value: settings.fontScale,
                    range: AppSettings.fontScaleRange,
                    divisions: 15,
                    describe: (v) => '${(v * 100).round()}%',
                    onChanged: controller.setFontScale,
                  ),
                  _SliderRow(
                    sliderKey: const ValueKey('reader-line-spacing'),
                    label: 'Line spacing',
                    value: settings.lineSpacing,
                    range: AppSettings.lineSpacingRange,
                    divisions: 9,
                    describe: (v) => v.toStringAsFixed(1),
                    onChanged: controller.setLineSpacing,
                  ),
                  const _SheetTitle('Scroll speed'),
                  _ScrollSpeedControl(
                    value: settings.scrollSpeed,
                    onChanged: controller.setScrollSpeed,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 16, 8, 0),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton.icon(
                        icon: const Icon(Icons.vertical_align_top),
                        label: Text(
                          'Back to the beginning',
                          softWrap: true,
                          style: namoText(
                            NamoFonts.english,
                            size: 16,
                            color: p.heading,
                            weight: 500,
                          ),
                        ),
                        style: TextButton.styleFrom(foregroundColor: p.heading),
                        onPressed: () {
                          Navigator.of(context).pop();
                          onBackToBeginning();
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetTitle extends StatelessWidget {
  const _SheetTitle(this.text);

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
class _ScrollSpeedControl extends StatelessWidget {
  const _ScrollSpeedControl({required this.value, required this.onChanged});

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
          if (custom)
            Padding(
              padding: const EdgeInsets.only(top: 8),
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
          MergeSemantics(
            child: Semantics(
              label: 'Scroll speed',
              child: Slider(
                key: const ValueKey('reader-scroll-speed'),
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
class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.sliderKey,
    required this.label,
    required this.value,
    required this.range,
    required this.divisions,
    required this.describe,
    required this.onChanged,
  });

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
