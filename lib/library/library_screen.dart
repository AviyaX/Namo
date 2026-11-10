import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../content/model.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../design/widgets/choice_chips.dart';
import '../design/widgets/empty_state.dart';
import '../design/widgets/list_row.dart';
import '../design/widgets/namo_page.dart';
import '../design/widgets/page_header.dart';
import '../design/widgets/search_field.dart';
import '../design/widgets/segmented_selector.dart';
import '../home/card_art.dart';
import '../router.dart';
import '../settings/settings.dart';
import 'library_gate.dart';
import 'open_categories.dart';
import 'search.dart';

/// The topics as rows, with a search box; a tap on a topic opens the
/// numbered sections of its readings underneath, on the same page.
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

  final _query = TextEditingController();

  /// The topic chosen with the chips; null is "All". Not stored.
  String? _chip;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

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

  /// Stores the request as open, empties the search and the chip, then clears
  /// the request from the address so that asking again later (from Home, say)
  /// is seen as a new request.
  void _settle(Category? category) {
    if (!mounted) return;
    if (category != null) {
      ref.read(openCategoriesProvider.notifier).open(category.id);
    }
    _query.clear();
    setState(() => _chip = null);
    context.replace(Routes.library);
  }

  @override
  Widget build(BuildContext context) {
    final asked = widget.openCategory != null || widget.openReading != null;
    if (!asked) _handled = null;
    final open = ref.watch(openCategoriesProvider);
    final selection = ref.watch(settingsProvider.select((s) => s.languages));
    return NamoPage(
      children: [
        LibraryGate(
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
            final categories = library.categories;
            final n = categories.length;
            final sections = categories.fold(0, (a, c) => a + sectionCount(c));
            // A request from the address shows everything: the search and the
            // chip are emptied right after this frame.
            final query = asked ? '' : _query.text;
            final chip = asked || categories.every((c) => c.id != _chip)
                ? null
                : _chip;
            final searching =
                foldForSearch(query).runes.length >= searchMinLength;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PageHeader(
                  title: 'Library',
                  caption:
                      '$n ${n == 1 ? 'collection' : 'collections'}'
                      ' · ${sectionCountLabel(sections)}',
                ),
                const SizedBox(height: NamoSpace.lg),
                SearchField(
                  key: const ValueKey('library-search'),
                  controller: _query,
                  label: 'Search the library',
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: NamoSpace.lg),
                if (searching)
                  _Results(
                    hits: searchLibrary(library, query, selection),
                    query: query.trim(),
                  )
                else ...[
                  if (n >= 2) ...[
                    ChoiceChips<String?>(
                      key: const ValueKey('library-chips'),
                      options: [
                        const Segment<String?>(null, 'All'),
                        for (final c in categories)
                          Segment<String?>(c.id, c.title),
                      ],
                      selected: chip,
                      onSelected: (v) => setState(() => _chip = v),
                    ),
                    const SizedBox(height: NamoSpace.sm),
                  ],
                  for (final c in categories)
                    if (chip == null || chip == c.id)
                      _CategoryEntry(
                        category: c,
                        open: open.contains(c.id) || c.id == requested?.id,
                        animate: c.id != requested?.id,
                      ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

/// The sections that match the search, or a nothing-found state.
class _Results extends StatelessWidget {
  const _Results({required this.hits, required this.query});

  final List<SearchHit> hits;
  final String query;

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    if (hits.isEmpty) {
      return EmptyState(
        key: const ValueKey('library-results'),
        icon: Symbols.search_off_rounded,
        title: 'No results for “$query”',
        message: 'Try a word from a section title or a verse.',
      );
    }
    return Column(
      key: const ValueKey('library-results'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final h in hits)
          ListRow(
            number: h.section.number,
            title: h.section.heading,
            titleFamily: NamoFonts.sinhala,
            // Spoken as it is drawn: the language is named when it is not
            // one of the chosen ones.
            detailLabel: h.line == null || h.lineLanguageChosen
                ? h.line
                : '${h.lineLanguage!.label}, ${h.line}',
            detail: h.line == null ? null : _HitLine(hit: h),
            onTap: () => context.go(
              Routes.reader(h.reading.id, sectionId: h.section.id),
            ),
            trailing: Icon(
              Symbols.chevron_right_rounded,
              size: NamoSizes.iconSmall,
              weight: 300,
              color: p.textSecondary,
            ),
          ),
      ],
    );
  }
}

/// The verse line that matched, with its language named when that language
/// is not one of the chosen ones.
class _HitLine extends StatelessWidget {
  const _HitLine({required this.hit});

  final SearchHit hit;

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    final language = hit.lineLanguage!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!hit.lineLanguageChosen)
          Text(language.label, style: NamoType.caption(p.textSecondary)),
        Text(
          hit.line!,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: readingStyle(
            language,
            fontScale: 1,
            lineSpacing: 1.4,
            color: p.textSecondary,
          ).copyWith(fontSize: 15),
        ),
      ],
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
        : NamoMotion.quick;
    final severalReadings = category.readings.length > 1;
    return Column(
      children: [
        ListRow(
          leading: TopicThumbnail(categoryId: category.id),
          title: category.title,
          subtitle: category.subtitle,
          caption: sectionCountLabel(sectionCount(category)),
          expanded: open,
          onTap: () =>
              ref.read(openCategoriesProvider.notifier).toggle(category.id),
          trailing: AnimatedRotation(
            turns: open ? 0.5 : 0,
            duration: duration,
            curve: NamoMotion.curve,
            child: Icon(
              Symbols.expand_more_rounded,
              size: NamoSizes.iconSmall,
              weight: 300,
              color: p.textSecondary,
            ),
          ),
        ),
        TweenAnimationBuilder<double>(
          tween: Tween(end: open ? 1.0 : 0.0),
          duration: duration,
          curve: NamoMotion.curve,
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
                          padding: const EdgeInsets.fromLTRB(
                            NamoSpace.lg,
                            NamoSpace.lg,
                            NamoSpace.lg,
                            NamoSpace.xs,
                          ),
                          child: Semantics(
                            header: true,
                            // A reading title may be Sinhala: the same
                            // family as the section rows beneath it.
                            child: Text(
                              r.title,
                              style: NamoType.readingTitle(p.text),
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
                          trailing: Icon(
                            Symbols.chevron_right_rounded,
                            size: NamoSizes.iconSmall,
                            weight: 300,
                            color: p.textSecondary,
                          ),
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
