/// A book's page drawn as a bound book: the cover round it, the paper with
/// its thin gold rule and, for a page turned in Pages mode, the shadow of
/// the binding, the running head (page number and title) and a lifted
/// corner. Sideways, two pages lie open side by side ([BookSpreadFrame]).
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

/// The narrowest page area, wider than tall, in which the book lies open
/// with two pages side by side.
const bookSpreadMinWidth = 600.0;

/// The space above the running head, from the paper's edge.
const _headTop = NamoSpace.sm;

/// The space between the running head and the text below it.
const _headGap = NamoSpace.sm;

/// Which side of an open book a page is: a left-hand page has the binding
/// on its right, a right-hand page on its left. As in print, odd page
/// numbers are right-hand pages.
enum BookSide {
  left,
  right;

  static BookSide ofNumber(int number) => number.isOdd ? right : left;
}

/// The running head's style on [paper]: the books' face, small, in the
/// soft ink.
TextStyle _headStyle(NamoPalette p, BookPaper paper) =>
    NamoType.caption(bookColours(p, paper).inkSoft).copyWith(
      fontFamily: NamoFonts.book,
      fontFamilyFallback: const [NamoFonts.sinhala],
      fontSize: 14,
    );

/// How tall the running head is drawn in [context].
double _headHeight(BuildContext context) {
  final painter = TextPainter(
    text: TextSpan(
      text: 'ම0',
      style: _headStyle(NamoPalette.of(context), BookPaper.cream),
    ),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  final h = painter.height;
  painter.dispose();
  return h;
}

/// Where the text sits inside the paper (inside the rule): [bookPaperPadding]
/// all round; with [pageMarks] room at the top for the running head and a
/// little more on the spine side of [side], clear of the binding's shadow.
/// The text is as wide on either side.
EdgeInsets bookTextInsets(
  BuildContext context, {
  required bool pageMarks,
  BookSide side = BookSide.right,
}) {
  if (!pageMarks) return const EdgeInsets.all(bookPaperPadding);
  const inner = bookPaperPadding + NamoSpace.sm, outer = bookPaperPadding;
  final top = math.max(
    bookPaperPadding,
    _headTop + _headHeight(context) + _headGap,
  );
  return EdgeInsets.fromLTRB(
    side == BookSide.right ? inner : outer,
    top,
    side == BookSide.right ? outer : inner,
    bookPaperPadding,
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

/// What is drawn over one page in Pages mode: which [side] of the book it
/// is, its [number] and the [title] in its running head (the book's on a
/// left-hand page, the chapter's on a right-hand page), and whether its
/// bottom right [corner] is lifted.
class BookPageMarks {
  const BookPageMarks({
    required this.side,
    this.number,
    this.title,
    this.corner = true,
  });

  final BookSide side;
  final int? number;
  final String? title;
  final bool corner;
}

/// [child] on a page of [paper] in a book's cover: the cover (rounded, with
/// the app's shadow) [bookCoverInset] round the paper, the paper ruled in
/// gold, and [child] filling the paper inside the rule (it pads its own
/// text; see [bookTextInsets]).
///
/// With [pageMarks] (a page turned in Pages mode) the binding's shadow runs
/// down the paper's spine edge (its left on a right-hand page, its right on
/// a left-hand page, by [side]), the running head is drawn at the top — the
/// [pageNumber] in the outer corner, [runningTitle] centred, in the soft ink
/// — and the bottom right corner is lifted, over [child]. None of them takes
/// a touch, and the head is not read out (the page count below already is).
/// While [turning] (the page's curl is drawn) the corner and the head are
/// left out: they would sit over the page being lifted and the page beneath
/// as it shows.
class BookFrame extends StatelessWidget {
  const BookFrame({
    super.key,
    required this.paper,
    required this.pageMarks,
    this.pageNumber,
    this.runningTitle,
    this.side = BookSide.right,
    this.turning = false,
    required this.child,
  });

  final BookPaper paper;
  final bool pageMarks;
  final int? pageNumber;
  final String? runningTitle;
  final BookSide side;
  final bool turning;
  final Widget child;

  @override
  Widget build(BuildContext context) => _Cover(
    paper: paper,
    child: _Paper(
      boxKey: const ValueKey('book-paper'),
      paper: paper,
      marks: pageMarks
          ? BookPageMarks(side: side, number: pageNumber, title: runningTitle)
          : null,
      turning: turning,
      child: child,
    ),
  );
}

/// Two pages of [paper] open side by side in one cover, the binding between
/// them: [left] (a left-hand page) and [right], each marked as in
/// [BookFrame]. Only the right page's corner is lifted. While [turning] the
/// right page's marks are left out (it is the page being turned).
class BookSpreadFrame extends StatelessWidget {
  const BookSpreadFrame({
    super.key,
    required this.paper,
    required this.left,
    required this.right,
    required this.leftMarks,
    required this.rightMarks,
    this.turning = false,
  });

  final BookPaper paper;
  final Widget left, right;
  final BookPageMarks leftMarks, rightMarks;
  final bool turning;

  @override
  Widget build(BuildContext context) => _Cover(
    paper: paper,
    child: Row(
      key: const ValueKey('book-spread'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: _Paper(
            boxKey: const ValueKey('book-paper-left'),
            paper: paper,
            marks: leftMarks,
            turning: false,
            child: left,
          ),
        ),
        Expanded(
          child: _Paper(
            boxKey: const ValueKey('book-paper'),
            paper: paper,
            marks: rightMarks,
            turning: turning,
            child: right,
          ),
        ),
      ],
    ),
  );
}

/// The book's cover round [child], [bookCoverInset] wide.
class _Cover extends StatelessWidget {
  const _Cover({required this.paper, required this.child});

  final BookPaper paper;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    return DecoratedBox(
      key: const ValueKey('book-cover'),
      decoration: BoxDecoration(
        color: bookColours(p, paper).cover,
        borderRadius: BorderRadius.circular(NamoRadius.cover),
        boxShadow: p.floatShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(bookCoverInset),
        child: child,
      ),
    );
  }
}

/// One sheet of paper, ruled in gold, with [marks] drawn over [child] (none
/// in Scroll mode).
class _Paper extends StatelessWidget {
  const _Paper({
    required this.boxKey,
    required this.paper,
    required this.marks,
    required this.turning,
    required this.child,
  });

  /// The paper's own box (tests read its colour).
  final Key boxKey;
  final BookPaper paper;
  final BookPageMarks? marks;
  final bool turning;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    final c = bookColours(p, paper);
    final m = marks;
    return DecoratedBox(
      key: boxKey,
      decoration: BoxDecoration(
        color: c.paper,
        border: Border.all(color: c.rule, width: bookRuleWidth),
      ),
      child: Padding(
        padding: const EdgeInsets.all(bookRuleWidth),
        child: m == null
            ? child
            : Stack(
                fit: StackFit.expand,
                children: [
                  child,
                  Positioned(
                    left: m.side == BookSide.right ? 0 : null,
                    right: m.side == BookSide.left ? 0 : null,
                    top: 0,
                    bottom: 0,
                    width: bookSpineWidth,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        key: const ValueKey('book-spine'),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: m.side == BookSide.right
                                ? Alignment.centerLeft
                                : Alignment.centerRight,
                            end: m.side == BookSide.right
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            colors: [c.spine, c.spine.withValues(alpha: 0)],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (!turning && (m.number != null || m.title != null))
                    Positioned(
                      left: bookPaperPadding,
                      right: bookPaperPadding,
                      top: _headTop,
                      child: IgnorePointer(
                        child: ExcludeSemantics(
                          child: _RunningHead(
                            marks: m,
                            style: _headStyle(p, paper),
                          ),
                        ),
                      ),
                    ),
                  if (!turning && m.corner)
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
    );
  }
}

/// A page's running head: its number in the outer corner (left on a
/// left-hand page, right on a right-hand page) and its title centred
/// between, on one line.
class _RunningHead extends StatelessWidget {
  const _RunningHead({required this.marks, required this.style});

  final BookPageMarks marks;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final number = marks.number;
    final numberText = Text(
      number == null ? '' : '$number',
      key: number == null ? null : const ValueKey('book-page-number'),
      maxLines: 1,
      style: style,
    );
    // The number's room on both sides, so the title stays centred.
    const room = 4 * NamoSpace.md;
    return Row(
      key: const ValueKey('book-running-head'),
      children: [
        SizedBox(
          width: room,
          child: marks.side == BookSide.left
              ? Align(alignment: Alignment.centerLeft, child: numberText)
              : null,
        ),
        Expanded(
          child: Text(
            marks.title ?? '',
            key: const ValueKey('book-running-title'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: style,
          ),
        ),
        SizedBox(
          width: room,
          child: marks.side == BookSide.right
              ? Align(alignment: Alignment.centerRight, child: numberText)
              : null,
        ),
      ],
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
