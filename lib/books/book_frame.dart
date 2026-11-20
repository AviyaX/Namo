/// A book's page drawn as a bound book: the cover round it, the paper with
/// its thin gold rule and, for a page turned in Pages mode, the shadow of
/// the binding, the page number and a lifted corner.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design/tokens.dart';
import '../design/typography.dart';
import '../settings/settings.dart';

/// How far the cover shows round the paper.
const bookCoverInset = NamoSpace.sm;

/// The gold rule round the paper's edge.
const bookRuleWidth = 1.0;

/// The space between the paper's edge (inside the rule) and its text.
const bookPaperPadding = NamoSpace.lg;

/// How far the binding's shadow reaches across a page from its spine edge.
const bookSpineWidth = 18.0;

/// The size of a page's lifted corner.
const bookCornerSize = 26.0;

/// The space below the page number, to the paper's edge.
const _numberFoot = NamoSpace.sm;

/// The space between the text and the page number below it.
const _numberGap = NamoSpace.xs;

/// The page number's style on [paper].
TextStyle _numberStyle(NamoPalette p, BookPaper paper) =>
    NamoType.caption(bookColours(p, paper).inkSoft);

/// Where the text sits inside the paper (inside the rule): [bookPaperPadding]
/// all round, and with [pageMarks] a little more on the spine side, clear
/// of the binding's shadow, and room at the foot for the page number.
EdgeInsets bookTextInsets(BuildContext context, {required bool pageMarks}) {
  if (!pageMarks) return const EdgeInsets.all(bookPaperPadding);
  final number = TextPainter(
    text: TextSpan(
      text: '0',
      style: _numberStyle(NamoPalette.of(context), BookPaper.cream),
    ),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
  )..layout();
  final foot = _numberFoot + number.height + _numberGap;
  number.dispose();
  return EdgeInsets.fromLTRB(
    bookPaperPadding + NamoSpace.sm,
    bookPaperPadding,
    bookPaperPadding,
    math.max(bookPaperPadding, foot),
  );
}

/// The width of a book's text in Scroll mode on a screen [screen] wide:
/// the reading column, less the cover, the rule and the paper's padding.
double bookScrollTextWidth(double screen) =>
    math.min(
      screen - 2 * NamoSizes.pageMargin(screen),
      NamoSizes.readingColumn,
    ) -
    2 * (bookCoverInset + bookRuleWidth + bookPaperPadding);

/// [child] on a page of [paper] in a book's cover: the cover (rounded, with
/// the app's shadow) [bookCoverInset] round the paper, the paper ruled in
/// gold, and [child] filling the paper inside the rule (it pads its own
/// text; see [bookTextInsets]).
///
/// With [pageMarks] (a page turned in Pages mode) the binding's shadow runs
/// down the paper's left edge, [pageNumber] is centred at the foot in the
/// soft ink, and the bottom right corner is lifted, over [child]. None of
/// them takes a touch, and the number is not read out (the page count
/// below already is). While [turning] (the page's curl is drawn) the corner
/// and the number are left out: they would sit over the corner being lifted
/// and over the page beneath as it shows.
class BookFrame extends StatelessWidget {
  const BookFrame({
    super.key,
    required this.paper,
    required this.pageMarks,
    this.pageNumber,
    this.turning = false,
    required this.child,
  });

  final BookPaper paper;
  final bool pageMarks;
  final int? pageNumber;
  final bool turning;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    final c = bookColours(p, paper);
    final number = turning ? null : pageNumber;
    return DecoratedBox(
      key: const ValueKey('book-cover'),
      decoration: BoxDecoration(
        color: c.cover,
        borderRadius: BorderRadius.circular(NamoRadius.cover),
        boxShadow: p.floatShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(bookCoverInset),
        child: DecoratedBox(
          key: const ValueKey('book-paper'),
          decoration: BoxDecoration(
            color: c.paper,
            border: Border.all(color: c.rule, width: bookRuleWidth),
          ),
          child: Padding(
            padding: const EdgeInsets.all(bookRuleWidth),
            child: !pageMarks
                ? child
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      child,
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        width: bookSpineWidth,
                        child: IgnorePointer(
                          child: DecoratedBox(
                            key: const ValueKey('book-spine'),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [c.spine, c.spine.withValues(alpha: 0)],
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (number != null)
                        Positioned(
                          left: bookCornerSize,
                          right: bookCornerSize,
                          bottom: _numberFoot,
                          child: IgnorePointer(
                            child: ExcludeSemantics(
                              child: Center(
                                key: const ValueKey('book-page-number'),
                                heightFactor: 1,
                                child: Text(
                                  '$number',
                                  maxLines: 1,
                                  style: _numberStyle(p, paper),
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (!turning)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          width: bookCornerSize,
                          height: bookCornerSize,
                          child: IgnorePointer(
                            child: CustomPaint(
                              key: const ValueKey('book-corner'),
                              painter: _CornerPainter(
                                paper: c.paper,
                                fold: c.fold,
                                shadow: p.curlShadow,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// A dog-eared corner: the page's corner folded over along the diagonal,
/// its underside ([fold]) lying on the page with a small shadow under its
/// edge, and the page beneath ([paper]) showing where the corner was.
class _CornerPainter extends CustomPainter {
  const _CornerPainter({
    required this.paper,
    required this.fold,
    required this.shadow,
  });

  final Color paper;
  final Color fold;
  final Color shadow;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    // Where the corner was: the page beneath, a shade darker by the fold.
    final beneath = Path()
      ..moveTo(w, 0)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas
      ..drawPath(beneath, Paint()..color = paper)
      ..drawPath(
        beneath,
        Paint()..color = shadow.withValues(alpha: shadow.a * 0.25),
      );
    // The corner folded over onto the page.
    final flap = Path()
      ..moveTo(0, 0)
      ..lineTo(w, 0)
      ..lineTo(0, h)
      ..close();
    canvas
      ..drawShadow(flap, shadow, 2, false)
      ..drawPath(flap, Paint()..color = fold);
  }

  @override
  bool shouldRepaint(_CornerPainter old) =>
      old.paper != paper || old.fold != fold || old.shadow != shadow;
}
