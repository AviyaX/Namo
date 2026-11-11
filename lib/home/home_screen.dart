import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../content/model.dart';
import '../design/tokens.dart';
import '../design/widgets/namo_page.dart';
import '../flows/flows.dart' show flowsProvider, isFlowId;
import '../library/library_gate.dart';
import '../reader/position_controller.dart';
import '../settings/settings.dart';
import 'collections_row.dart';
import 'continue_card.dart';
import 'featured_carousel.dart';
import 'flows_row.dart';
import 'gatha_card.dart';
import 'home_header.dart';
import 'quick_access.dart';
import 'today.dart';

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
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= NamoSizes.wideBreakpoint;
    final now = ref.watch(clockProvider)();
    return NamoPage(
      columnKey: const ValueKey('home-column'),
      maxWidth: wide ? NamoSizes.homeColumn : NamoSizes.readingColumn,
      backdrop: const HomeBackdrop(),
      children: [
        HomeHeader(now: now),
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
    final flows = ref.watch(flowsProvider);
    // The carousel picks up a Library reading; the card is only for a flow.
    final showContinue = ref.watch(
      positionProvider.select(
        (s) =>
            isFlowId(s.lastReadingId ?? '') && hasContinue(s, library, flows),
      ),
    );
    final first = library.categories.firstOrNull;
    final pick = gathaForDay(library, now);

    final continueCard = showContinue ? ContinueCard(library: library) : null;
    final gathaCard = pick == null
        ? null
        : GathaCard(
            pick: pick,
            selection: selection,
            topicTitle: library.categoryOf(pick.reading.id)?.title ?? '',
            fontScale: fontScale,
            lineSpacing: lineSpacing,
          );
    final featured = first == null ? null : FeaturedCarousel(library: library);
    // Only with a flow, so Home without flows keeps its gaps as they were.
    final flowsRow = flows.flows.isEmpty ? null : FlowsRow(library: library);

    final quickAccess = first == null || quickAccessCards(first).isEmpty
        ? null
        : QuickAccess(category: first);
    final collections = library.categories.isEmpty
        ? null
        : CollectionsRow(categories: library.categories);

    final blocks = <Widget>[
      ?featured,
      if (wide && continueCard != null && gathaCard != null)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: continueCard),
            const SizedBox(width: NamoSpace.xl),
            Expanded(child: gathaCard),
          ],
        )
      else ...[
        ?continueCard,
        ?gathaCard,
      ],
      ?quickAccess,
      ?flowsRow,
      ?collections,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final b in blocks) ...[SizedBox(height: gap), b],
      ],
    );
  }
}
