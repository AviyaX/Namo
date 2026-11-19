import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../design/tokens.dart';
import '../design/typography.dart';
import '../design/widgets/pressable.dart';

/// IntendAble's site, opened by the "Powered by IntendAble" line.
final intendableUri = Uri.parse('https://www.intendable.us/');

/// Opens a web address outside the app; false when nothing could open it.
/// Tests replace it.
final linkOpenerProvider = Provider<Future<bool> Function(Uri)>(
  (ref) => (uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  },
);

/// The quiet maker's line at the foot of Settings: "Powered by IntendAble",
/// a link to IntendAble's site.
class PoweredBy extends ConsumerWidget {
  const PoweredBy({super.key = const ValueKey('powered-by')});

  static const _label = 'Powered by IntendAble';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = NamoPalette.of(context);
    Future<void> open() async {
      final opened = await ref.read(linkOpenerProvider)(intendableUri);
      if (opened || !context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Could not open www.intendable.us.')),
        );
    }

    return Center(
      child: Semantics(
        container: true,
        link: true,
        linkUrl: intendableUri,
        label: _label,
        onTap: open,
        excludeSemantics: true,
        child: Pressable(
          onTap: open,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: NamoSpace.lg,
              vertical: NamoSpace.sm,
            ),
            child: Text.rich(
              TextSpan(
                text: 'Powered by ',
                children: [
                  TextSpan(
                    text: 'IntendAble',
                    style: NamoType.caption(p.text).copyWith(
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                      decorationColor: p.textSecondary,
                    ),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
              style: NamoType.caption(p.textSecondary),
            ),
          ),
        ),
      ),
    );
  }
}
