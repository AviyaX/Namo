import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../audio/recording_store.dart';
import '../audio/recording_store_provider.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../design/widgets/buttons.dart';
import '../design/widgets/progress_line.dart';
import 'choosers.dart';
import 'setting_controls.dart';

/// One line on how many recordings are on the device; '' when none are known.
String recordingsSummary(RecordingsSnapshot s) {
  if (s.total == 0) return '';
  if (s.allDownloaded) {
    return 'All ${s.total} recordings downloaded · ${formatSize(s.bytesTotal)}';
  }
  final line =
      '${s.downloaded} of ${s.total} downloaded · '
      '${formatSize(s.bytesDownloaded)} of ${formatSize(s.bytesTotal)}';
  return s.failed > 0 ? '$line · ${s.failed} could not be downloaded' : line;
}

/// The Settings group for recordings: when they download, how much is on the
/// device, and buttons to fetch or remove them. In the browser they only
/// stream, so the group is a single sentence.
class RecordingsGroup extends ConsumerWidget {
  const RecordingsGroup({super.key, this.web = kIsWeb});

  final bool web;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = NamoPalette.of(context);
    if (web) {
      return SettingsGroup(
        icon: Symbols.download_rounded,
        label: 'Recordings',
        children: [
          _Caption(
            'In the browser, recordings play from the internet when you press play.',
            color: p.textSecondary,
          ),
        ],
      );
    }
    final store = ref.watch(recordingStoreProvider);
    return SettingsGroup(
      icon: Symbols.download_rounded,
      label: 'Recordings',
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Caption(
              'Recordings are fetched from the internet once and kept on this device. Texts never need a connection.',
              color: p.textSecondary,
            ),
            const SettingLabel('Download automatically'),
            const AutoDownloadChooser(),
          ],
        ),
        ValueListenableBuilder<RecordingsSnapshot>(
          valueListenable: store.snapshot,
          builder: (context, s, _) {
            if (s.total == 0) return const SizedBox.shrink();
            final removable = s.downloaded + s.active > 0;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: NamoSpace.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    recordingsSummary(s),
                    key: const ValueKey('recordings-summary'),
                    softWrap: true,
                    style: NamoType.body(p.text),
                  ),
                  if (s.anyDownloading) ...[
                    const SizedBox(height: NamoSpace.sm),
                    ProgressLine(
                      value: s.bytesTotal == 0
                          ? 0
                          : s.bytesDownloaded / s.bytesTotal,
                      semanticsLabel: 'Download progress',
                      height: 2,
                    ),
                  ],
                  if (!s.allDownloaded || removable) ...[
                    const SizedBox(height: NamoSpace.sm),
                    Wrap(
                      spacing: NamoSpace.sm,
                      runSpacing: NamoSpace.sm,
                      children: [
                        if (!s.allDownloaded)
                          PrimaryButton(
                            key: const ValueKey('recordings-download-all'),
                            label: 'Download all now',
                            onPressed: store.downloadAll,
                          ),
                        if (removable)
                          QuietButton(
                            key: const ValueKey('recordings-remove'),
                            label: 'Remove downloaded recordings',
                            onPressed: () => _confirmRemove(context, store, s),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Future<void> _confirmRemove(
    BuildContext context,
    RecordingStore store,
    RecordingsSnapshot s,
  ) async {
    final p = NamoPalette.of(context);
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(
          'Remove ${formatSize(s.bytesDownloaded)} of recordings from this '
          'device? They can be downloaded again.',
          style: NamoType.body(p.text),
        ),
        actions: [
          QuietButton(
            key: const ValueKey('recordings-remove-keep'),
            label: 'Keep',
            onPressed: () => Navigator.of(context).pop(false),
          ),
          PrimaryButton(
            key: const ValueKey('recordings-remove-confirm'),
            label: 'Remove',
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
    if (sure == true) unawaited(store.removeAll());
  }
}

/// The explanatory sentence at the top of the group, as in the Audio group.
class _Caption extends StatelessWidget {
  const _Caption(this.text, {required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        NamoSpace.lg,
        NamoSpace.xs,
        NamoSpace.lg,
        0,
      ),
      child: Text(text, softWrap: true, style: NamoType.caption(color)),
    );
  }
}
