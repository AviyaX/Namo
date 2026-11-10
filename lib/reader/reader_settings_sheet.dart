import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../design/tokens.dart';
import '../design/widgets/buttons.dart';
import '../design/widgets/sheet_frame.dart';
import '../settings/settings.dart';
import '../settings/setting_controls.dart';
import '../settings/choosers.dart';

/// Opens the reader settings over the reader.
Future<void> showReaderSettingsSheet(
  BuildContext context, {
  required VoidCallback onBackToBeginning,
  bool showLayout = true,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  elevation: 0,
  // The frame draws its own surface, corners and shadow.
  shape: const RoundedRectangleBorder(),
  clipBehavior: Clip.none,
  constraints: const BoxConstraints(),
  sheetAnimationStyle: AnimationStyle(
    duration: NamoMotion.of(context, NamoMotion.open),
    reverseDuration: NamoMotion.of(context, NamoMotion.close),
    curve: NamoMotion.curve,
    reverseCurve: NamoMotion.curve,
  ),
  builder: (_) => ReaderSettingsSheet(
    onBackToBeginning: onBackToBeginning,
    showLayout: showLayout,
  ),
);

/// Languages, layout, text size, line spacing and scroll speed. Each change
/// applies to the reader at once.
class ReaderSettingsSheet extends ConsumerWidget {
  const ReaderSettingsSheet({
    super.key,
    required this.onBackToBeginning,
    this.showLayout = true,
  });

  /// False in a pirith, which is always phrase by phrase.
  final bool showLayout;

  /// Called after the sheet closes for 'Back to the beginning'.
  final VoidCallback onBackToBeginning;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(settingsProvider.notifier);
    const gap = SizedBox(height: NamoSpace.xl);
    // The sheet has its own messenger so the choosers' messages show on top
    // of it rather than on the reader underneath. Its Scaffold fills the
    // space the route gives, with the frame at the bottom; a tap on the empty
    // part above closes the sheet as the barrier would.
    return ScaffoldMessenger(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            // The barrier already offers dismissal to screen readers.
            Positioned.fill(
              child: ExcludeSemantics(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: SheetFrame(
                title: 'Reading settings',
                children: [
                  const SettingLabel('Languages'),
                  const LanguageChooser(),
                  gap,
                  if (showLayout) ...[
                    const SettingLabel('When two languages show'),
                    const LayoutChooser(),
                    gap,
                  ],
                  SliderSetting.textSize(
                    sliderKey: const ValueKey('reader-text-size'),
                    value: settings.fontScale,
                    onChanged: controller.setFontScale,
                  ),
                  gap,
                  SliderSetting.lineSpacing(
                    sliderKey: const ValueKey('reader-line-spacing'),
                    value: settings.lineSpacing,
                    onChanged: controller.setLineSpacing,
                  ),
                  gap,
                  const SettingLabel('Scroll speed'),
                  ScrollSpeedControl(
                    sliderKey: const ValueKey('reader-scroll-speed'),
                    value: settings.scrollSpeed,
                    onChanged: controller.setScrollSpeed,
                  ),
                  gap,
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: QuietButton(
                      label: 'Back to the beginning',
                      icon: Symbols.vertical_align_top_rounded,
                      onPressed: () {
                        Navigator.of(context).pop();
                        onBackToBeginning();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
