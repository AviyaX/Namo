import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/tokens.dart';
import '../design/typography.dart';
import 'reading_language.dart';
import 'settings.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key = const ValueKey('screen-settings')});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: const [
          _SectionTitle('Reading languages'),
          LanguageChooser(),
          _SectionTitle('When two languages show'),
          LayoutChooser(),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Semantics(
        header: true,
        child: Text(text,
            style: namoText(NamoFonts.english,
                size: 14, color: p.textQuiet, weight: 600)),
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
    return Column(
      children: [
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
