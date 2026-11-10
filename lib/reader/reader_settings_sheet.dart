import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/tokens.dart';
import '../design/typography.dart';
import '../settings/settings.dart';
import '../settings/setting_controls.dart';
import '../settings/settings_screen.dart';

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
                  const SettingsHeading('Reading languages'),
                  const LanguageChooser(),
                  const SettingsHeading('When two languages show'),
                  const LayoutChooser(),
                  SliderSetting.textSize(
                    sliderKey: const ValueKey('reader-text-size'),
                    value: settings.fontScale,
                    onChanged: controller.setFontScale,
                  ),
                  SliderSetting.lineSpacing(
                    sliderKey: const ValueKey('reader-line-spacing'),
                    value: settings.lineSpacing,
                    onChanged: controller.setLineSpacing,
                  ),
                  const SettingsHeading('Scroll speed'),
                  ScrollSpeedControl(
                    sliderKey: const ValueKey('reader-scroll-speed'),
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
