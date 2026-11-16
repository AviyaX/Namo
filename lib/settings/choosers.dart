import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/tokens.dart';
import '../design/typography.dart';
import '../design/widgets/segmented_selector.dart';
import 'auto_download.dart';
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
/// [pirith] shows the two choices a pirith has: 'Meaning below' (the flowing
/// default) and 'Side by side'.
class LayoutChooser extends ConsumerWidget {
  const LayoutChooser({super.key, this.pirith = false});

  final bool pirith;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final enabled = settings.languages.languages.length == 2;
    final p = NamoPalette.of(context);
    final effective = settings.effectiveLayout;
    final segments = pirith
        ? const [
            Segment(TwoLanguageLayout.verse, 'Meaning below'),
            Segment(TwoLanguageLayout.sideBySide, 'Side by side'),
          ]
        : [for (final l in TwoLanguageLayout.values) Segment(l, l.label)];
    final selected = pirith
        ? (effective == TwoLanguageLayout.sideBySide
              ? TwoLanguageLayout.sideBySide
              : TwoLanguageLayout.verse)
        : effective;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: _chooserPadding,
          child: SegmentedSelector<TwoLanguageLayout>(
            semanticLabel: 'Layout',
            enabled: enabled,
            disabledHint: 'Needs two languages',
            segments: segments,
            selected: {selected},
            onPressed: (l) {
              final controller = ref.read(settingsProvider.notifier);
              if (pirith &&
                  l == TwoLanguageLayout.verse &&
                  settings.layout != TwoLanguageLayout.sideBySide) {
                return;
              }
              final outcome = controller.setLayout(l);
              if (outcome == LayoutOutcome.refusedPair) {
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    const SnackBar(
                      content: Text('Side by side needs Pali and Sinhala.'),
                    ),
                  );
              }
            },
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

/// When recordings download by themselves: on Wi-Fi, on any connection, never.
class AutoDownloadChooser extends ConsumerWidget {
  const AutoDownloadChooser({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(settingsProvider.select((s) => s.autoDownload));
    return Padding(
      padding: _chooserPadding,
      child: SegmentedSelector<AutoDownload>(
        semanticLabel: 'Download automatically',
        segments: [for (final a in AutoDownload.values) Segment(a, a.label)],
        selected: {value},
        onPressed: ref.read(settingsProvider.notifier).setAutoDownload,
      ),
    );
  }
}
