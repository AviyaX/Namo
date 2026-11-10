import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../content/model.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../design/widgets/buttons.dart';
import '../design/widgets/pressable.dart';
import '../design/widgets/surface_card.dart';
import '../router.dart';

/// The width of one section card.
const _cardWidth = 148.0;

/// The sections of a topic's first reading, in a row that scrolls sideways,
/// under the title `In <topic>` and a "See all" that opens the topic in the
/// Library. Each card opens the reader at its section. Builds nothing when
/// the topic has no sections.
class SectionStrip extends StatelessWidget {
  const SectionStrip({super.key, required this.category});

  final Category category;

  @override
  Widget build(BuildContext context) {
    final reading = category.readings.firstOrNull;
    if (reading == null || reading.sections.isEmpty) {
      return const SizedBox.shrink();
    }
    final p = NamoPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  'In ${category.title}',
                  style: NamoType.sectionTitle(p.text),
                ),
              ),
            ),
            const SizedBox(width: NamoSpace.sm),
            TextAction(
              label: 'See all',
              onPressed: () => context.go(Routes.category(category.id)),
            ),
          ],
        ),
        const SizedBox(height: NamoSpace.md),
        EqualHeightRow(
          children: [
            for (final s in reading.sections)
              _SectionCard(
                key: ValueKey('section-card-${s.id}'),
                section: s,
                onTap: () => context.go(
                  Routes.reader(
                    reading.id,
                    sectionId: s.id,
                    from: ReaderFrom.home,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// A row of cards that scrolls sideways, 12 apart, every card as tall as the
/// tallest (no fixed height, so large text cannot overflow). A card that
/// takes keyboard focus is scrolled into view by the focus traversal.
class EqualHeightRow extends StatelessWidget {
  const EqualHeightRow({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, c) in children.indexed) ...[
            if (i > 0) const SizedBox(width: NamoSpace.md),
            c,
          ],
        ],
      ),
    ),
  );
}

/// A flat card over which a [Pressable] is laid, so the card fills the
/// height the row gives it (a tappable [SurfaceCard] keeps to the height of
/// what it holds). Screen readers hear one button, [semanticLabel].
class TappableCard extends StatelessWidget {
  const TappableCard({
    super.key,
    required this.onTap,
    required this.semanticLabel,
    required this.child,
    this.radius = NamoRadius.md,
  });

  final VoidCallback onTap;
  final String semanticLabel;
  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.passthrough,
    children: [
      ExcludeSemantics(child: child),
      Positioned.fill(
        child: Pressable(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          semanticLabel: semanticLabel,
          excludeChildSemantics: true,
          child: const SizedBox.expand(),
        ),
      ),
    ],
  );
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({super.key, required this.section, required this.onTap});

  final Section section;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    return SizedBox(
      width: _cardWidth,
      child: TappableCard(
        onTap: onTap,
        semanticLabel: '${section.number}, ${section.heading}',
        child: SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${section.number}', style: NamoType.cardTitle(p.gold)),
              const SizedBox(height: NamoSpace.xs),
              Text(
                section.heading,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: NamoType.body(p.text),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
