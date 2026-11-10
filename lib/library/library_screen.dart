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
  /// The request that was last handed to [_settle], so that frames built
  /// while it is pending do not queue it again.
  String? _handled;

  /// The category the address asks for, if it names one that exists.
  Category? _requested(Library library) {
    if (widget.openCategory != null) {
      return library.category(widget.openCategory!);
    }
    if (widget.openReading != null) {
      return library.categoryOf(widget.openReading!);
    }
    return null;
  }

  /// Stores the request as open, then clears it from the address so that
  /// asking again later (from Home, say) is seen as a new request.
  void _settle(Category? category) {
    if (!mounted) return;
    if (category != null) {
      ref.read(openCategoriesProvider.notifier).open(category.id);
    }
    context.replace(Routes.library);
  }

  @override
  Widget build(BuildContext context) {
    final asked = widget.openCategory != null || widget.openReading != null;
    if (!asked) _handled = null;
    final open = ref.watch(openCategoriesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Library')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: NamoSizes.readingColumn),
          child: LibraryGate(
            builder: (context, library) {
              // The requested category counts as open in this very frame
              // (without animation); the provider catches up after it.
              final requested = asked ? _requested(library) : null;
              if (asked) {
                final key = '${widget.openCategory}|${widget.openReading}';
                if (_handled != key) {
                  _handled = key;
                  WidgetsBinding.instance.addPostFrameCallback(
                    (_) => _settle(requested),
                  );
                }
              }
              return ListView(
                children: [
                  for (final c in library.categories)
                    _CategoryEntry(
                      category: c,
                      open: open.contains(c.id) || c.id == requested?.id,
                      animate: c.id != requested?.id,
                    ),
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
  const _CategoryEntry({
    required this.category,
    required this.open,
    required this.animate,
  });

  final Category category;
  final bool open;

  /// False for the frame that shows a request from the address.
  final bool animate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = NamoPalette.of(context);
    final duration = !animate || MediaQuery.disableAnimationsOf(context)
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
                            // A reading title may be Sinhala: the same
                            // family as the section rows beneath it.
                            child: Text(
                              r.title,
                              style: namoText(
                                NamoFonts.sinhala,
                                size: 14,
                                color: p.heading,
                                weight: 600,
                              ),
                            ),
                          ),
                        ),
                      for (final s in r.sections)
                        ListRow(
                          number: s.number,
                          title: s.heading,
                          titleFamily: NamoFonts.sinhala,
                          onTap: () =>
                              context.go(Routes.reader(r.id, sectionId: s.id)),
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
