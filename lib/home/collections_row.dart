import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../content/model.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../design/widgets/progress_line.dart';
import '../reader/position_controller.dart';
import '../router.dart';
import 'card_art.dart';
import 'card_row.dart';
import 'topic_progress.dart';

/// The width of a card in the sideways row on a phone, and the least height
/// of every card (it grows taller when its words need more room).
const _cardWidth = 220.0, _cardHeight = 148.0;

/// Home's "Collections": every topic as a picture card, each opening the
/// topic in the Library, under a title with a "See all" that opens the
/// Library. On a phone the cards are in a row that scrolls sideways; on a
/// wide screen they share the row.
class CollectionsRow extends StatelessWidget {
  const CollectionsRow({super.key, required this.categories});

  final List<Category> categories;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= NamoSizes.wideBreakpoint;
    final cards = [
      for (final c in categories)
        _CollectionCard(key: ValueKey('collection-${c.id}'), category: c),
    ];
    return Column(
      key: const ValueKey('home-collections'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HomeBlockTitle(
          'Collections',
          onSeeAll: () => context.go(Routes.library),
        ),
        const SizedBox(height: NamoSpace.md),
        if (wide)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, card) in cards.indexed) ...[
                  if (i > 0) const SizedBox(width: NamoSpace.md),
                  Expanded(child: card),
                ],
              ],
            ),
          )
        else
          EqualHeightRow(
            children: [
              for (final card in cards)
                SizedBox(width: _cardWidth, child: card),
            ],
          ),
      ],
    );
  }
}

/// A topic's picture with its title, Sinhala title and count (with a book
/// icon) over the scrim; and, for a topic of one reading with a remembered
/// place, a progress line and its percent.
class _CollectionCard extends ConsumerWidget {
  const _CollectionCard({super.key, required this.category});

  final Category category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(
      positionProvider.select(
        (s) =>
            category.readings.length == 1 &&
                featuredAction(category, s) == FeaturedAction.continueReading
            ? topicResume(category, s)!.progress.clamp(0.0, 1.0)
            : null,
      ),
    );
    final percent = progress == null ? null : (progress * 100).round();
    final count = topicCountLabel(category);
    const onPicture = NamoPalette.onPicture;
    return TappableCard(
      radius: NamoRadius.card,
      onTap: () => context.go(Routes.category(category.id)),
      semanticLabel: [
        category.title,
        category.subtitle,
        count,
        if (percent != null) '$percent percent',
      ].join(', '),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(NamoRadius.card),
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            Positioned.fill(child: TopicPicture(categoryId: category.id)),
            PictureWords(
              minHeight: _cardHeight,
              child: Padding(
                padding: const EdgeInsets.all(NamoSpace.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(category.title, style: NamoType.cardTitle(onPicture)),
                    const SizedBox(height: NamoSpace.xs),
                    Text(category.subtitle, style: NamoType.label(onPicture)),
                    const SizedBox(height: NamoSpace.xs),
                    Row(
                      children: [
                        const Icon(
                          Symbols.menu_book_rounded,
                          size: NamoSizes.iconSmall,
                          weight: 300,
                          color: onPicture,
                        ),
                        const SizedBox(width: NamoSpace.sm),
                        Flexible(
                          child: Text(
                            count,
                            style: NamoType.caption(onPicture),
                          ),
                        ),
                      ],
                    ),
                    if (progress != null) ...[
                      const SizedBox(height: NamoSpace.sm),
                      Row(
                        children: [
                          Expanded(
                            child: ProgressLine(
                              value: progress,
                              height: 4,
                              rounded: true,
                            ),
                          ),
                          const SizedBox(width: NamoSpace.sm),
                          Text(
                            '$percent%',
                            style: NamoType.caption(onPicture),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
