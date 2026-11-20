import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../design/marks.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../design/widgets/buttons.dart';
import '../router.dart';
import 'card_art.dart';
import 'today.dart';

/// The top of Home: the lotus, the "Namo" wordmark with its tagline under
/// it, a search button that opens the Library's search, then the greeting
/// for [now].
class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key, required this.now});

  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const NamoMarkIcon(NamoMark.lotus, size: 40),
            const SizedBox(width: NamoSpace.md),
            Expanded(
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: _Scrim(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text('Namo', style: NamoType.wordmark(p.text)),
                      ),
                      Text(
                        'Buddhist Prayers · Chanting',
                        style: NamoType.caption(p.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Over the picture's leaves: the glow keeps the icon clear.
            _Scrim(
              child: NamoIconButton(
                key: const ValueKey('home-search'),
                icon: Symbols.search_rounded,
                tooltip: 'Search the library',
                onPressed: () => context.go(Routes.librarySearch),
              ),
            ),
          ],
        ),
        const SizedBox(height: NamoSpace.sm),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: _Scrim(
            child: Text(
              greetingFor(now),
              style: NamoType.body(p.textSecondary),
            ),
          ),
        ),
      ],
    );
  }
}

/// A soft glow of the page background behind words, so that they keep their
/// contrast where they reach over the picture's leaves (large text, a narrow
/// screen). Over the picture's faded part it does not show.
class _Scrim extends StatelessWidget {
  const _Scrim({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    return DecoratedBox(
      key: const ValueKey('home-header-scrim'),
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: p.background.withValues(alpha: 0.9),
            blurRadius: 16,
            spreadRadius: 16,
          ),
        ],
      ),
      child: child,
    );
  }
}

/// The picture behind [HomeHeader]: the theme's header picture, covering
/// min(width / 3, [maxHeight]) plus the top inset, pinned to the top right,
/// and fading into the page background over its lowest 40%. When it spans
/// only the column (a wide screen) it fades into the page at both sides too,
/// so it never ends in a hard line. Decoration only; a picture that does not
/// load leaves it empty.
class HomeBackdrop extends StatelessWidget {
  const HomeBackdrop({super.key});

  /// The proportion of the header pictures (1600 x 533).
  static const _aspect = 3.0;

  /// The tallest the picture gets (less the top inset): it has faded fully
  /// into the page before the featured card starts, under the header at
  /// any width.
  static const maxHeight = 136.0;

  /// The part of the width each side fade takes on a wide screen.
  static const _sideFade = 0.12;

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final top = MediaQuery.paddingOf(context).top;
    final ratio = MediaQuery.devicePixelRatioOf(context);
    final screen = MediaQuery.sizeOf(context).width;
    return ExcludeSemantics(
      child: LayoutBuilder(
        builder: (context, box) {
          final width = box.maxWidth;
          final height = math.min(width / _aspect, maxHeight) + top;
          // Narrower than the screen: it spans the column, not edge to edge.
          final inColumn = width < screen - 0.5;
          // Decode only as wide as the picture is shown when it covers, in
          // steps of 128 so that a window resized by a pixel keeps it.
          final cover = math.max(width, height * _aspect) * ratio;
          return SizedBox(
            key: const ValueKey('home-backdrop'),
            width: width,
            height: height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  dark ? headerPictures.dark : headerPictures.light,
                  fit: BoxFit.cover,
                  alignment: Alignment.topRight,
                  cacheWidth: cover.isFinite
                      ? ((cover / 128).ceil() * 128).clamp(1, 1600)
                      : null,
                  errorBuilder: (context, error, stack) =>
                      const SizedBox.shrink(),
                ),
                DecoratedBox(
                  key: const ValueKey('home-backdrop-fade'),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.6, 1.0],
                      colors: [p.background.withValues(alpha: 0), p.background],
                    ),
                  ),
                ),
                if (inColumn)
                  DecoratedBox(
                    key: const ValueKey('home-backdrop-side-fade'),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        stops: const [0, _sideFade, 1 - _sideFade, 1],
                        colors: [
                          p.background,
                          p.background.withValues(alpha: 0),
                          p.background.withValues(alpha: 0),
                          p.background,
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
