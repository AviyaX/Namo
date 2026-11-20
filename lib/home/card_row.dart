import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../design/tokens.dart';
import '../design/typography.dart';
import '../design/widgets/buttons.dart';
import '../design/widgets/pressable.dart';

/// The title of a block on Home (a header for screen readers), with a
/// "See all" at the right when [onSeeAll] is given; under the title when
/// both do not fit on one line (large text on a narrow phone).
class HomeBlockTitle extends StatelessWidget {
  const HomeBlockTitle(this.title, {super.key, this.onSeeAll});

  final String title;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    final heading = Semantics(
      header: true,
      child: Text(title, style: NamoType.sectionTitle(p.text)),
    );
    if (onSeeAll == null) return heading;
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: NamoSpace.sm,
      children: [
        heading,
        TextAction(
          label: 'See all',
          icon: Symbols.chevron_right_rounded,
          onPressed: onSeeAll,
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
/// height the row gives it (a tappable SurfaceCard keeps to the height of
/// what it holds). Screen readers hear one button, [semanticLabel].
class TappableCard extends StatelessWidget {
  const TappableCard({
    super.key,
    required this.onTap,
    required this.semanticLabel,
    required this.child,
    this.radius = NamoRadius.card,
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
