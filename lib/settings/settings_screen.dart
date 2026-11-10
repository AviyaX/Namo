import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../design/tokens.dart';
import '../design/typography.dart';
import '../design/widgets/list_row.dart';
import '../router.dart';
import 'setting_controls.dart';
import 'reading_language.dart';
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
            padding: const EdgeInsets.only(bottom: 16),
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
              for (final (label, mode) in const [
                ('Light', ThemeMode.light),
                ('Dark', ThemeMode.dark),
                ('Same as device', ThemeMode.system),
              ])
                _ChoiceRow(
                  label: label,
                  selected: settings.themeMode == mode,
                  onTap: () => controller.setThemeMode(mode),
                ),
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

/// A flat, full-width choice row: a label and a mark when it is on.
class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.label,
    required this.selected,
    required this.onTap,
    this.hint,
    this.enabled = true,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? hint;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    final color = enabled ? p.text : p.textQuiet;
    return Semantics(
      container: true,
      excludeSemantics: true,
      button: true,
      enabled: enabled,
      selected: selected,
      label: label,
      hint: hint,
      onTap: enabled ? onTap : null,
      child: InkWell(
        onTap: enabled ? onTap : null,
        splashFactory: NoSplash.splashFactory,
        highlightColor: p.surface,
        hoverColor: p.surface,
        child: Container(
          constraints: const BoxConstraints(minHeight: NamoSizes.touchTarget),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: p.divider, width: 1)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(label,
                    style: namoText(NamoFonts.english, size: 18, color: color)),
              ),
              if (selected)
                Icon(Icons.check, size: 22, color: enabled ? p.heading : color),
            ],
          ),
        ),
      ),
    );
  }
}

class LanguageChooser extends ConsumerWidget {
  const LanguageChooser({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(settingsProvider.select((s) => s.languages));
    return Column(
      children: [
        for (final l in ReadingLanguage.values)
          _ChoiceRow(
            label: l.label,
            selected: selection.has(l),
            onTap: () {
              final outcome =
                  ref.read(settingsProvider.notifier).toggleLanguage(l);
              final message = switch (outcome) {
                ToggleOutcome.changed => null,
                ToggleOutcome.refusedThird =>
                  'Two languages at most. Switch one off first.',
                ToggleOutcome.refusedLast => 'One language always stays on.',
              };
              if (message == null) return;
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(content: Text(message)));
            },
          ),
      ],
    );
  }
}

class LayoutChooser extends ConsumerWidget {
  const LayoutChooser({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final enabled = settings.languages.languages.length == 2;
    final p = NamoPalette.of(context);
    return Column(
      children: [
        if (!enabled)
          // Rows already carry the hint for screen readers; this is the
          // visible copy, so it is not announced a second time.
          ExcludeSemantics(
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text('Needs two languages',
                    style: namoText(NamoFonts.english,
                        size: 14, color: p.textQuiet)),
              ),
            ),
          ),
        for (final layout in TwoLanguageLayout.values)
          _ChoiceRow(
            label: layout.label,
            selected: settings.layout == layout,
            enabled: enabled,
            hint: enabled ? null : 'Needs two languages',
            onTap: () => ref.read(settingsProvider.notifier).setLayout(layout),
          ),
      ],
    );
  }
}
