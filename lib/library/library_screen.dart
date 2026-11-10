import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../content/model.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../design/widgets/list_row.dart';
import '../router.dart';
import 'library_gate.dart';
import 'open_categories.dart';

/// The categories as cards; a tap opens the numbered sections of the
/// category's reading underneath, on the same page.
///
/// [openCategory] or [openReading] (from the address) opens that category
/// once; an id that matches nothing is ignored.
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({
    super.key = const ValueKey('screen-library'),
    this.openCategory,
    this.openReading,
  });

  final String? openCategory;
  final String? openReading;

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  /// Opens what the address asks for, then clears it from the address so
  /// that asking again later (from Home, say) is seen as a new request.
  void _applyAddress(Library library) {
    final category = widget.openCategory != null
        ? library.category(widget.openCategory!)
        : widget.openReading != null
            ? library.categoryOf(widget.openReading!)
            : null;
    if (category != null) {
      ref.read(openCategoriesProvider.notifier).open(category.id);
    }
    context.replace(Routes.library);
  }

  @override
  Widget build(BuildContext context) {
    final asked = widget.openCategory != null || widget.openReading != null;
    final open = ref.watch(openCategoriesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Library')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: NamoSizes.readingColumn),
          child: LibraryGate(
            builder: (context, library) {
              if (asked) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _applyAddress(library);
                });
              }
              return ListView(
                children: [
                  for (final c in library.categories)
                    _CategoryEntry(category: c, open: open.contains(c.id)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CategoryEntry extends ConsumerWidget {
  const _CategoryEntry({required this.category, required this.open});

  final Category category;
  final bool open;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = NamoPalette.of(context);
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 200);
    final severalReadings = category.readings.length > 1;
    return Column(
      children: [
        ListRow(
          title: category.title,
          subtitle: category.subtitle,
          expanded: open,
          onTap: () =>
              ref.read(openCategoriesProvider.notifier).toggle(category.id),
          trailing: AnimatedRotation(
            turns: open ? 0.5 : 0,
            duration: duration,
            curve: Curves.easeInOut,
            child: Icon(Symbols.expand_more_rounded, color: p.textQuiet),
          ),
        ),
        TweenAnimationBuilder<double>(
          tween: Tween(end: open ? 1.0 : 0.0),
          duration: duration,
          curve: Curves.easeInOut,
          builder: (context, factor, _) {
            if (factor == 0) return const SizedBox.shrink();
            return ClipRect(
              child: Align(
                alignment: Alignment.topCenter,
                heightFactor: factor,
                child: Column(
                  key: ValueKey('open-${category.id}'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final r in category.readings) ...[
                      if (severalReadings)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                          child: Semantics(
                            header: true,
                            child: Text(
                              r.title,
                              style: namoText(NamoFonts.english,
                                  size: 14, color: p.heading, weight: 600),
                            ),
                          ),
                        ),
                      for (final s in r.sections)
                        ListRow(
                          number: s.number,
                          title: s.heading,
                          titleFamily: NamoFonts.sinhala,
                          onTap: () => context
                              .go(Routes.reader(r.id, sectionId: s.id)),
                        ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
