import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../design/tokens.dart';
import '../design/typography.dart';
import '../design/widgets/list_row.dart';
import '../router.dart';
import 'setting_controls.dart';
import 'choosers.dart';
import 'settings.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key = const ValueKey('screen-settings')});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(settingsProvider.notifier);
    final p = NamoPalette.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Center(
        child: ConstrainedBox(
          key: const ValueKey('settings-column'),
          constraints: const BoxConstraints(maxWidth: NamoSizes.readingColumn),
          child: ListView(
            // Clear of the navigation bar floating over the page.
            padding: EdgeInsets.only(
              bottom: 16 + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              const SettingsHeading('Languages'),
              const LanguageChooser(),
              const SettingsHeading('Layout'),
              const LayoutChooser(),
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
              const SettingsHeading('Scroll speed'),
              ScrollSpeedControl(
                sliderKey: const ValueKey('setting-scroll-speed'),
                value: settings.scrollSpeed,
                onChanged: controller.setScrollSpeed,
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                value: settings.autoScrollWithAudio,
                onChanged: controller.setAutoScrollWithAudio,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                title: Text(
                  'Start auto-scroll when a recording starts',
                  softWrap: true,
                  style: namoText(NamoFonts.english, size: 18, color: p.text),
                ),
              ),
              const SettingsHeading('Theme'),
              const ThemeChooser(),
              const SizedBox(height: 8),
              ListRow(
                title: 'Sources',
                onTap: () => context.go(Routes.sources),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
