import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/tokens.dart';
import '../design/typography.dart';
import '../settings/settings.dart';
import '../settings/settings_screen.dart';

/// Opens the reader settings over the reader.
Future<void> showReaderSettingsSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const ReaderSettingsSheet(),
    );

/// Languages, layout, text size and line spacing. Each change applies to the
/// reader at once.
class ReaderSettingsSheet extends ConsumerWidget {
  const ReaderSettingsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(settingsProvider.notifier);
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
                  // Task 11 adds the scroll speed control here, and Task 10
                  // adds 'Back to the beginning' below it.
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
