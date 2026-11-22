import 'package:flutter/material.dart';

import '../design/tokens.dart';
import '../design/typography.dart';
import '../design/widgets/pressable.dart';
import '../design/widgets/surface_card.dart';
import 'bana_catalogue.dart';

/// One chip of a filter row: pill, sage when chosen. The [label] is what is
/// shown; [semanticLabel] what a screen reader hears (default: the label).
class BanaChip extends StatelessWidget {
  const BanaChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.semanticLabel,
  });

  final String label;
  final String? semanticLabel;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    const radius = BorderRadius.all(Radius.circular(NamoRadius.pill));
    return Pressable(
      onTap: onTap,
      borderRadius: radius,
      semanticLabel: semanticLabel ?? label,
      selected: selected,
      excludeChildSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minHeight: NamoSizes.touchTarget),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(
          horizontal: NamoSpace.lg,
          vertical: NamoSpace.sm,
        ),
        decoration: BoxDecoration(
          color: selected ? p.sage : p.sage.withAlpha(0),
          borderRadius: radius,
          border: Border.all(color: selected ? p.sage : p.border),
        ),
        child: Text(
          label,
          style: NamoType.label(selected ? p.onSage : p.textSecondary),
        ),
      ),
    );
  }
}

/// A series: kicker, title, the speaker and where to carry on from.
class SeriesCard extends StatelessWidget {
  const SeriesCard({
    super.key,
    required this.series,
    required this.speakerName,
    required this.lastPart,
    required this.onTap,
  });

  final BanaSeries series;
  final String speakerName;

  /// The part number last opened, or null if none was.
  final int? lastPart;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    final kicker = 'SERIES · ${series.parts.length} PARTS';
    final carryOn = lastPart == null
        ? 'Start: part 1'
        : 'Continue: part $lastPart';
    return SurfaceCard(
      onTap: onTap,
      semanticLabel: '$kicker, ${series.title}, $speakerName, $carryOn',
      leadingLine: p.gold,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(kicker, style: NamoType.overline(p.gold)),
          const SizedBox(height: NamoSpace.xs),
          Text(series.title, style: NamoType.cardTitle(p.text)),
          const SizedBox(height: NamoSpace.xs),
          Text(speakerName, style: NamoType.caption(p.textSecondary)),
          const SizedBox(height: NamoSpace.sm),
          Text(carryOn, style: NamoType.label(p.sage)),
        ],
      ),
    );
  }
}

/// One bana: thumbnail, title, speaker and length. Offline, or when the
/// picture does not come, the thumbnail is a plain box with the length.
class BanaTile extends StatelessWidget {
  const BanaTile({
    super.key,
    required this.bana,
    required this.speakerName,
    required this.onTap,
  });

  final Bana bana;
  final String speakerName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    const radius = BorderRadius.all(Radius.circular(NamoRadius.sm));
    final plain = Container(
      alignment: Alignment.center,
      color: p.backgroundAlt,
      child: Text(bana.lengthLabel, style: NamoType.caption(p.textSecondary)),
    );
    return Pressable(
      onTap: onTap,
      borderRadius: radius,
      semanticLabel: '${bana.title}, $speakerName, ${bana.lengthLabel}',
      excludeChildSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: NamoSpace.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: radius,
              child: SizedBox(
                width: NamoSizes.banaThumbWidth,
                height: 68,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    plain,
                    Image.network(
                      bana.thumbnailUri.toString(),
                      fit: BoxFit.cover,
                      excludeFromSemantics: true,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: NamoSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(bana.title, style: NamoType.body(p.text)),
                  const SizedBox(height: NamoSpace.xs),
                  Text(
                    '$speakerName · ${bana.lengthLabel}',
                    style: NamoType.caption(p.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
