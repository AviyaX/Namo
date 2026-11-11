import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../content/model.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../design/widgets/buttons.dart';
import '../design/widgets/page_header.dart';
import '../design/widgets/pressable.dart';
import '../design/widgets/progress_line.dart';
import '../reader/position_controller.dart';
import '../router.dart';
import 'card_art.dart';
import 'topic_progress.dart';

/// The widest the "NN% complete" block at the lower right gets.
const _maxProgressWidth = 240.0;

/// One page of the featured carousel: a topic's picture, statue to the
/// right, with the overline, title, Sinhala title, count and a button on
/// the left over a scrim; and, when there is a remembered place to go back
/// to, "NN% complete" over a progress line at the lower right.
///
/// The whole card and the button do the same (see [featuredAction]):
/// continue the remembered reading, begin the one reading, open the topic in
/// the Library, or, for a topic with no readings, nothing.
class FeaturedCard extends ConsumerWidget {
  const FeaturedCard({super.key, required this.category});

  final Category category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (resume, action) = ref.watch(
      positionProvider.select(
        (s) => (topicResume(category, s), featuredAction(category, s)),
      ),
    );
    final wide = MediaQuery.sizeOf(context).width >= NamoSizes.wideBreakpoint;
    final count = topicCountLabel(category);
    final VoidCallback? open = switch (action) {
      FeaturedAction.continueReading => () => context.go(
        Routes.reader(resume!.reading.id, from: ReaderFrom.home),
      ),
      FeaturedAction.begin => () => context.go(
        Routes.reader(category.readings.single.id, from: ReaderFrom.home),
      ),
      FeaturedAction.open => () => context.go(Routes.category(category.id)),
      FeaturedAction.none => null,
    };
    final buttonLabel = switch (action) {
      FeaturedAction.continueReading => 'Continue',
      FeaturedAction.begin => 'Begin',
      FeaturedAction.open => 'Open',
      FeaturedAction.none => null,
    };
    // Which reading is picked up, when the topic has several.
    final resumeCaption = resume != null && category.readings.length > 1
        ? resume.reading.title
        : null;
    final percent = resume == null
        ? null
        : '${(resume.progress.clamp(0.0, 1.0) * 100).round()}% complete';
    const onPicture = NamoPalette.onPicture;

    final words = Padding(
      padding: const EdgeInsets.all(NamoSpace.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Accent styling (upper case, wide spacing) in the picture's text
          // colour: the theme's gold is too dark on the scrim.
          const Overline('Featured collection', accent: true, color: onPicture),
          const SizedBox(height: NamoSpace.sm),
          Text(category.title, style: NamoType.screenTitle(onPicture)),
          const SizedBox(height: NamoSpace.xs),
          Text(category.subtitle, style: NamoType.body(onPicture)),
          const SizedBox(height: NamoSpace.sm),
          Text(count, style: NamoType.caption(onPicture)),
          if (resumeCaption != null) ...[
            const SizedBox(height: NamoSpace.xs),
            Text(resumeCaption, style: NamoType.caption(onPicture)),
          ],
          if (buttonLabel != null) ...[
            const SizedBox(height: NamoSpace.lg),
            // The card itself takes keyboard focus; the button is the same
            // action, so it is not a second stop.
            ExcludeFocus(
              child: PrimaryButton(
                label: buttonLabel,
                icon: action == FeaturedAction.open
                    ? null
                    : Symbols.play_arrow_rounded,
                onPressed: open,
              ),
            ),
          ],
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, box) {
        final width = box.maxWidth;
        final minHeight = wide ? width / 3 : width * 0.5;
        final progressWidth = math.min(
          _maxProgressWidth,
          width / 2 - NamoSpace.xl - NamoSpace.lg,
        );
        return Pressable(
          onTap: open,
          borderRadius: BorderRadius.circular(NamoRadius.lg),
          semanticLabel: [
            category.title,
            category.subtitle,
            count,
            ?resumeCaption,
            ?buttonLabel,
            ?percent,
          ].join(', '),
          excludeChildSemantics: true,
          child: SizedBox(
            width: width,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(NamoRadius.lg),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: TopicPicture(
                      categoryId: category.id,
                      hero: true,
                      alignment: Alignment.centerRight,
                    ),
                  ),
                  PictureWords(
                    minHeight: minHeight,
                    side: TextSide.left,
                    child: words,
                  ),
                  if (resume != null && progressWidth > 0)
                    Positioned(
                      right: NamoSpace.xl,
                      bottom: NamoSpace.xl,
                      width: progressWidth,
                      child: _Progress(
                        label: percent!,
                        value: resume.progress,
                      ),
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

/// "NN% complete" over a rounded progress line, on a backdrop of the
/// picture scrim so it reads over the bright side of any picture.
class _Progress extends StatelessWidget {
  const _Progress({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: const ValueKey('featured-progress'),
      decoration: BoxDecoration(
        color: NamoPalette.pictureScrim.withValues(alpha: pictureFadeAtText),
        borderRadius: BorderRadius.circular(NamoRadius.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.all(NamoSpace.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              label,
              textAlign: TextAlign.end,
              style: NamoType.caption(NamoPalette.onPicture),
            ),
            const SizedBox(height: NamoSpace.xs),
            ProgressLine(value: value, height: 4, rounded: true),
          ],
        ),
      ),
    );
  }
}
