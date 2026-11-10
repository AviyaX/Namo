import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design/tokens.dart';
import '../design/typography.dart';
import '../design/widgets/list_row.dart';
import '../library/library_gate.dart';
import '../router.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key = const ValueKey('screen-home')});

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: NamoSizes.readingColumn),
            child: ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
                  child: Semantics(
                    header: true,
                    child: Text('Namo',
                        style: namoText(NamoFonts.english,
                            size: 32, color: p.heading, weight: 600)),
                  ),
                ),
                LibraryGate(
                  builder: (context, library) => Column(
                    children: [
                      for (final c in library.categories)
                        ListRow(
                          title: c.title,
                          subtitle: c.subtitle,
                          onTap: () => context.go(Routes.category(c.id)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
