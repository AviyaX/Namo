import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../content/model.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../design/widgets/namo_page.dart';
import '../library/library_gate.dart';
import '../reader/position_controller.dart';
import '../router.dart';
import '../settings/settings.dart';
import 'card_art.dart';
import 'continue_card.dart';
import 'featured_card.dart';
import 'gatha_card.dart';
import 'section_strip.dart';
import 'today.dart';

/// The size of a picture card under Collections (it grows taller when its
/// words need more room).
const _collectionWidth = 200.0, _collectionHeight = 148.0;

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key = const ValueKey('screen-home')});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// The greeting and the day's verse are worked out from the clock, so
  /// work them out again when the app comes back after a while away.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= NamoSizes.wideBreakpoint;
    final now = ref.watch(clockProvider)();
    return NamoPage(
      columnKey: const ValueKey('home-column'),
      maxWidth: wide ? NamoSizes.homeColumn : NamoSizes.readingColumn,
      children: [
        Semantics(
          header: true,
          child: Text('Namo', style: NamoType.wordmark(p.text)),
        ),
        const SizedBox(height: NamoSpace.xs),
        Text(greetingFor(now), style: NamoType.body(p.textSecondary)),
        LibraryGate(
          builder: (context, library) =>
              _Blocks(library: library, now: now, wide: wide),
        ),
      ],
    );
  }
}

/// Everything under the header, [_gap] apart.
class _Blocks extends ConsumerWidget {
  const _Blocks({required this.library, required this.now, required this.wide});

  final Library library;
  final DateTime now;
  final bool wide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gap = MediaQuery.sizeOf(context).width < 360
        ? NamoSpace.xl
        : NamoSpace.xxl;
    final selection = ref.watch(settingsProvider.select((s) => s.languages));
    final fontScale = ref.watch(settingsProvider.select((s) => s.fontScale));
    final lineSpacing =
        ref.watch(settingsProvider.select((s) => s.lineSpacing));
    final showContinue = ref.watch(
      positionProvider.select((s) => hasContinue(s, library)),
    );
    final first = library.categories.firstOrNull;
    final pick = gathaForDay(library, now);

    final continueCard = showContinue ? ContinueCard(library: library) : null;
    final gathaCard = pick == null
        ? null
        : GathaCard(
            pick: pick,
            selection: selection,
            fontScale: fontScale,
            lineSpacing: lineSpacing,
          );
    final featured = first == null ? null : FeaturedCard(category: first);

    final blocks = <Widget>[
      if (wide) ...[
        ?featured,
        if (continueCard != null && gathaCard != null)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: continueCard),
              const SizedBox(width: NamoSpace.xl),
              Expanded(child: gathaCard),
            ],
          )
        else
          ?(continueCard ?? gathaCard),
      ] else ...[
        ?continueCard,
        ?featured,
        ?gathaCard,
      ],
      if (first != null &&
          first.readings.isNotEmpty &&
          first.readings.first.sections.isNotEmpty)
        SectionStrip(category: first),
      if (library.categories.length >= 2)
        _Collections(categories: library.categories.skip(1).toList()),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final b in blocks) ...[SizedBox(height: gap), b],
      ],
    );
  }
}

/// Every topic after the first, as picture cards in a row that scrolls
/// sideways; each opens the topic in the Library.
class _Collections extends StatelessWidget {
  const _Collections({required this.categories});

  final List<Category> categories;

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text('Collections', style: NamoType.sectionTitle(p.text)),
        ),
        const SizedBox(height: NamoSpace.md),
        EqualHeightRow(
          children: [
            for (final c in categories)
              _CollectionCard(key: ValueKey('collection-${c.id}'), category: c),
          ],
        ),
      ],
    );
  }
}

class _CollectionCard extends StatelessWidget {
  const _CollectionCard({super.key, required this.category});

  final Category category;

  @override
  Widget build(BuildContext context) {
    final count = topicCountLabel(category);
    const onPicture = NamoPalette.onPicture;
    return SizedBox(
      width: _collectionWidth,
      child: TappableCard(
        radius: NamoRadius.md,
        onTap: () => context.go(Routes.category(category.id)),
        semanticLabel: '${category.title}, ${category.subtitle}, $count',
        child: ClipRRect(
          borderRadius: BorderRadius.circular(NamoRadius.md),
          child: Stack(
            fit: StackFit.passthrough,
            children: [
              Positioned.fill(child: TopicPicture(categoryId: category.id)),
              PictureWords(
                minHeight: _collectionHeight,
                child: Padding(
                  padding: const EdgeInsets.all(NamoSpace.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(category.title, style: NamoType.cardTitle(onPicture)),
                      const SizedBox(height: NamoSpace.xs),
                      Text(count, style: NamoType.caption(onPicture)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
