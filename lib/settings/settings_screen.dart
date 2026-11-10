import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../audio/audio_catalogue.dart';
import '../content/content_repository.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../design/widgets/list_row.dart';
import '../design/widgets/namo_page.dart';
import '../design/widgets/namo_switch.dart';
import '../design/widgets/page_header.dart';
import '../design/widgets/pressable.dart';
import '../router.dart';
import 'choosers.dart';
import 'setting_controls.dart';
import 'settings.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key = const ValueKey('screen-settings')});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(settingsProvider.notifier);
    final p = NamoPalette.of(context);
    // The same lookup the reader uses: does any reading have a recording?
    final library = ref.watch(libraryProvider).value;
    final catalogue = ref.watch(audioCatalogueProvider);
    final anyRecording =
        library != null &&
        library.categories.any(
          (c) => c.readings.any((r) => catalogue.recordingFor(r.id) != null),
        );
    return NamoPage(
      columnKey: const ValueKey('settings-column'),
      children: [
        const PageHeader(title: 'Settings'),
        const SizedBox(height: NamoSpace.xl),
        const SettingsGroup(
          icon: Symbols.palette_rounded,
          label: 'Appearance',
          children: [
            // A label and its control are one row: no line between them.
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [SettingLabel('Theme'), ThemeChooser()],
            ),
          ],
        ),
        const SizedBox(height: NamoSpace.lg),
        SettingsGroup(
          icon: Symbols.menu_book_rounded,
          label: 'Reading',
          children: [
            SliderSetting.textSize(
              sliderKey: const ValueKey('setting-text-size'),
              value: settings.fontScale,
              onChanged: controller.setFontScale,
            ),
            SliderSetting.lineSpacing(
              sliderKey: const ValueKey('setting-line-spacing'),
              value: settings.lineSpacing,
              onChanged: controller.setLineSpacing,
            ),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SettingLabel('When two languages show'),
                LayoutChooser(),
              ],
            ),
          ],
        ),
        const SizedBox(height: NamoSpace.lg),
        SettingsGroup(
          icon: Symbols.translate_rounded,
          label: 'Languages',
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const LanguageChooser(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    NamoSpace.lg,
                    NamoSpace.xs,
                    NamoSpace.lg,
                    0,
                  ),
                  child: Text(
                    'Choose one or two.',
                    softWrap: true,
                    style: NamoType.caption(p.textSecondary),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: NamoSpace.lg),
        SettingsGroup(
          icon: Symbols.graphic_eq_rounded,
          label: 'Audio',
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SwitchRow(
                  label: 'Start auto-scroll when a recording starts',
                  value: settings.autoScrollWithAudio,
                  onChanged: controller.setAutoScrollWithAudio,
                ),
                if (!anyRecording)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      NamoSpace.lg,
                      NamoSpace.xs,
                      NamoSpace.lg,
                      0,
                    ),
                    child: Text(
                      'No recordings are included yet.',
                      softWrap: true,
                      style: NamoType.caption(p.textSecondary),
                    ),
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: NamoSpace.lg),
        SettingsGroup(
          icon: Symbols.swipe_vertical_rounded,
          label: 'Auto-scroll',
          children: [
            ScrollSpeedControl(
              sliderKey: const ValueKey('setting-scroll-speed'),
              value: settings.scrollSpeed,
              onChanged: controller.setScrollSpeed,
              topPadding: 0,
            ),
          ],
        ),
        const SizedBox(height: NamoSpace.lg),
        SettingsGroup(
          icon: Symbols.info_rounded,
          label: 'About Namo',
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: NamoSpace.lg),
              child: Text(
                'Free. No ads. Works offline.',
                softWrap: true,
                style: NamoType.body(p.textSecondary),
              ),
            ),
            ListRow(
              title: 'Sources',
              onTap: () => context.go(Routes.sources),
              trailing: Icon(
                Symbols.chevron_right_rounded,
                size: NamoSizes.iconSmall,
                weight: 300,
                fill: 0,
                color: p.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// A 48-high row: the label and a switch, one toggle for screen readers.
class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: label,
      toggled: value,
      onTap: () => onChanged(!value),
      child: Pressable(
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: NamoSpace.lg),
          child: Row(
            children: [
              Expanded(
                child: Text(label, softWrap: true, style: NamoType.label(p.text)),
              ),
              const SizedBox(width: NamoSpace.md),
              // The row takes the taps; the switch only shows the state.
              IgnorePointer(
                child: NamoSwitch(value: value, onChanged: (_) {}),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
