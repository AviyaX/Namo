import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/tokens.dart';
import '../design/typography.dart';
import '../design/widgets/segmented_selector.dart';
import 'reading_language.dart';
import 'settings.dart';

const _chooserPadding = EdgeInsets.symmetric(
  horizontal: NamoSpace.lg,
  vertical: NamoSpace.sm,
);

/// Which languages the reader shows: one or two.
class LanguageChooser extends ConsumerWidget {
  const LanguageChooser({super.key});

  static const _order = [
    ReadingLanguage.pali,
    ReadingLanguage.sinhala,
    ReadingLanguage.english,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(settingsProvider.select((s) => s.languages));
    return Padding(
      padding: _chooserPadding,
      child: SegmentedSelector<ReadingLanguage>(
        semanticLabel: 'Reading languages',
        multi: true,
        segments: [for (final l in _order) Segment(l, l.label)],
        selected: {
          for (final l in _order)
            if (selection.has(l)) l,
        },
        onPressed: (l) {
          final outcome = ref.read(settingsProvider.notifier).toggleLanguage(l);
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
    );
  }
}

/// How two languages are ordered; only usable with two languages chosen.
class LayoutChooser extends ConsumerWidget {
  const LayoutChooser({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final enabled = settings.languages.languages.length == 2;
    final p = NamoPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: _chooserPadding,
          child: SegmentedSelector<TwoLanguageLayout>(
            semanticLabel: 'Layout',
            enabled: enabled,
            disabledHint: 'Needs two languages',
            segments: [
              for (final l in TwoLanguageLayout.values) Segment(l, l.label),
            ],
            selected: {settings.layout},
            onPressed: (l) => ref.read(settingsProvider.notifier).setLayout(l),
          ),
        ),
        if (!enabled)
          // Below the selector, so it does not move when this appears. The
          // segments already carry the hint for screen readers; this is the
          // visible copy, so it is not announced a second time.
          ExcludeSemantics(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                NamoSpace.lg,
                NamoSpace.xs,
                NamoSpace.lg,
                NamoSpace.xs,
              ),
              child: Text(
                'Needs two languages',
                style: NamoType.caption(p.textSecondary),
              ),
            ),
          ),
      ],
    );
  }
}

/// Dark, light, or follow the device.
class ThemeChooser extends ConsumerWidget {
  const ThemeChooser({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(settingsProvider.select((s) => s.themeMode));
    return Padding(
      padding: _chooserPadding,
      child: SegmentedSelector<ThemeMode>(
        semanticLabel: 'Theme',
        segments: const [
          Segment(ThemeMode.dark, 'Dark'),
          Segment(ThemeMode.light, 'Light'),
          Segment(ThemeMode.system, 'Same as device'),
        ],
        selected: {mode},
        onPressed: ref.read(settingsProvider.notifier).setThemeMode,
      ),
    );
  }
}
