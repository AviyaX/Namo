import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../content/model.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../design/widgets/buttons.dart';
import '../design/widgets/page_header.dart';
import '../design/widgets/pressable.dart';
import '../reader/position_controller.dart';
import '../router.dart';
import 'card_art.dart';

/// The tallest the featured card is on a phone (unless its words need more).
const _maxPhoneHeight = 420.0;

/// The first topic on Home: its picture with the overline, title, subtitle,
/// section count and a button over it. The whole card and the button do the
/// same: a topic with one reading opens it in the reader (at the remembered
/// place when there is one); a topic with several opens the Library with it
/// open; a topic with none does nothing.
class FeaturedCard extends ConsumerWidget {
  const FeaturedCard({super.key, required this.category});

  final Category category;

  VoidCallback? _opener(BuildContext context) {
    final readings = category.readings;
    if (readings.isEmpty) return null;
    return () => context.go(
      readings.length == 1
          ? Routes.reader(readings.single.id, from: ReaderFrom.home)
          : Routes.category(category.id),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remembered = ref.watch(
      positionProvider.select(
        (s) => category.readings.any((r) => s.byReading.containsKey(r.id)),
      ),
    );
    final wide = MediaQuery.sizeOf(context).width >= NamoSizes.wideBreakpoint;
    final count = topicCountLabel(category);
    final open = _opener(context);
    final overline = featuredOverlines[category.id];
    const onPicture = NamoPalette.onPicture;

    final words = Padding(
      padding: const EdgeInsets.all(NamoSpace.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (overline != null) ...[
            Overline(overline, color: onPicture),
            const SizedBox(height: NamoSpace.sm),
          ],
          Text(
            category.title,
            style: NamoType.screenTitle(onPicture),
          ),
          const SizedBox(height: NamoSpace.xs),
          Text(
            category.subtitle,
            style: NamoType.body(onPicture),
          ),
          const SizedBox(height: NamoSpace.sm),
          Text(count, style: NamoType.caption(onPicture)),
          const SizedBox(height: NamoSpace.lg),
          // The card itself takes keyboard focus; the button is the same
          // action, so it is not a second stop.
          ExcludeFocus(
            child: PrimaryButton(
              label: remembered ? 'Continue' : 'Begin',
              onPressed: open,
            ),
          ),
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, box) {
        final width = box.maxWidth;
        final minHeight = wide ? width / 3 : math.min(width, _maxPhoneHeight);
        return Pressable(
          onTap: open,
          borderRadius: BorderRadius.circular(NamoRadius.lg),
          semanticLabel: '${category.title}, ${category.subtitle}, $count',
          excludeChildSemantics: true,
          child: SizedBox(
            width: width,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(NamoRadius.lg),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: TopicPicture(categoryId: category.id, wide: wide),
                  ),
                  PictureWords(
                    minHeight: minHeight,
                    side: wide ? TextSide.left : TextSide.bottom,
                    child: words,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
