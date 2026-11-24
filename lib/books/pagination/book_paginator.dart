/// Cutting one source page of a book (a chapter) into screen-sized pages.
///
/// A screen page is a list of slices drawn top to bottom: the title, a
/// whole block, some lines of a paragraph, list item or footnote, some
/// lines of a verse, some rows of a table, or a picture. They are measured
/// with the same styles, leads and table widths `book_blocks.dart` draws
/// them with, so what is measured is what is drawn.
///
/// The rules: never break mid-line; a paragraph (or item) of 4 or more
/// lines keeps at least 2 lines on each side of a break; a heading or
/// subhead never ends a page; a verse stays whole when it fits a page (a
/// verse line taller than a page is broken as a paragraph is); a
/// table or picture that does not fit the rest of the page moves to the
/// next; a table taller than a page breaks between rows with its header
/// row repeated; a picture taller than a page is scaled to fit it.
library;

import 'dart:math' as math;
import 'dart:ui' show Size;

import 'package:flutter/foundation.dart';

import '../../design/tokens.dart';
import '../book_blocks.dart';
import '../book_model.dart';
import '../book_places.dart';
import 'measure.dart';

/// The room for a screen page's text.
@immutable
class PageBox {
  const PageBox({required this.width, required this.height});
  final double width, height;

  @override
  bool operator ==(Object other) =>
      other is PageBox && other.width == width && other.height == height;

  @override
  int get hashCode => Object.hash(width, height);
}

/// One piece of a screen page.
@immutable
sealed class PageSlice {
  const PageSlice({
    required this.spot,
    required this.top,
    required this.height,
  });

  /// The block it is part of; -1 for the title.
  int get block;

  /// Its first character.
  final BookSpot spot;

  /// Its distance from the top of the page.
  final double top;

  /// How tall it is drawn.
  final double height;
}

/// The page's title.
class TitleSlice extends PageSlice {
  const TitleSlice({required super.top, required super.height})
    : super(spot: BookSpot.title);

  @override
  int get block => -1;
}

/// A whole block, drawn by `BookBlockView` (tables shrunk to the width).
class BlockSlice extends PageSlice {
  const BlockSlice(
    this.block, {
    required super.spot,
    required super.top,
    required super.height,
  });

  @override
  final int block;
}

/// Some lines of a paragraph ([item] 0), a list item or a footnote (the
/// [item]th), of a verse line taller than a page (the [item]th, set in as
/// a verse is), or of a heading or subhead taller than a page ([item] 0):
/// the text `charStart` to `charEnd`, drawn at the same width in the
/// block's own style: prose for a paragraph or list item, caption for a
/// footnote, and the heading's or subhead's style (as `BookBlockView` draws
/// them) for a slice of a heading or subhead block. A list item or footnote
/// keeps its lead; its label is drawn when [charStart] is 0. The footnotes'
/// rule is drawn over the first footnote's first slice.
///
/// A hard line break (`\n`) that falls at a cut belongs to neither slice:
/// the cut is the break, and drawn at the end of a slice it would add an
/// empty line. Joining a block's slices with a `\n` at such cuts gives back
/// its text exactly.
class LinesSlice extends PageSlice {
  const LinesSlice(
    this.block,
    this.item,
    this.charStart,
    this.charEnd, {
    required super.spot,
    required super.top,
    required super.height,
  });

  @override
  final int block;
  final int item, charStart, charEnd;
}

/// The lines [fromLine] to [toLine] of a verse too tall for one page.
class GathaSlice extends PageSlice {
  const GathaSlice(
    this.block,
    this.fromLine,
    this.toLine, {
    required super.spot,
    required super.top,
    required super.height,
  });

  @override
  final int block;
  final int fromLine, toLine;
}

/// The rows [fromRow] to [toRow] of a table, after its header row when
/// [repeatHeader]; drawn by `BookTableView` shrunk to the width, then at
/// [scale] (below 1 only when one row is taller than the room on a page).
class TableSlice extends PageSlice {
  const TableSlice(
    this.block,
    this.fromRow,
    this.toRow,
    this.repeatHeader, {
    this.scale = 1,
    required super.spot,
    required super.top,
    required super.height,
  });

  @override
  final int block;
  final int fromRow, toRow;
  final bool repeatHeader;
  final double scale;
}

/// A bundled picture at [scale] times the full width (below 1 only when it
/// is taller than a page), centred.
class ImageSlice extends PageSlice {
  const ImageSlice(
    this.block,
    this.scale, {
    required super.spot,
    required super.top,
    required super.height,
  });

  @override
  final int block;
  final double scale;
}

/// One screen page.
@immutable
class ScreenPage {
  const ScreenPage(this.slices);
  final List<PageSlice> slices;

  /// The spot of its first slice.
  BookSpot get start => slices.first.spot;
}

/// The space above [slice] on a page of [blocks], after [previous] (null
/// when it is the first on the page): as in the scroll column,
/// [NamoSpace.lg] after the title and [bookBlockGap] between blocks; none
/// between the slices of one block.
double gapBefore(
  List<BookBlock> blocks,
  PageSlice? previous,
  PageSlice slice,
) => _gapBefore(blocks, previous, slice.block);

double _gapBefore(List<BookBlock> blocks, PageSlice? previous, int block) =>
    switch (previous) {
      null => 0,
      TitleSlice() => NamoSpace.lg,
      _ when previous.block == block => 0,
      _ => bookBlockGap(blocks[previous.block], blocks[block]),
    };

/// Cuts [page] into screen pages of [box], one at a time, so a caller can
/// show the first before the rest are cut. [imageSize] gives a bundled
/// picture's size in pixels; without it (or for a null answer) a picture
/// is taken as 4:3.
Iterable<ScreenPage> paginate(
  BookPage page,
  BookTextStyles styles,
  PageBox box, {
  Size? Function(String asset)? imageSize,
}) sync* {
  final cutter = _Cutter(
    page,
    box,
    BookMeasurer(styles, box.width, fitTables: true, imageSize: imageSize),
  );
  do {
    yield cutter.nextPage();
  } while (!cutter.done);
}

/// The index of the last of [pages] starting at or before [spot]; 0 when
/// none does.
int pageIndexOf(List<ScreenPage> pages, BookSpot spot) {
  var found = 0;
  for (var i = 0; i < pages.length; i++) {
    if (pages[i].start.compareTo(spot) > 0) break;
    found = i;
  }
  return found;
}

/// The space over the title in the scroll column: the paper's padding, so
/// the title sits as far below the paper's top as the text sits in from its
/// sides, as in Pages mode.
const scrollTopPadding = NamoSpace.lg;

/// The spot of the first line at or below [offset] in [page]'s scroll
/// column [width] wide (laid out as the scroll view draws it: the title,
/// [NamoSpace.lg], the blocks [bookBlockGap] apart, tables at their
/// natural width); the last line's spot when [offset] is past the end.
BookSpot spotAtOffset(
  BookPage page,
  BookTextStyles styles,
  double width,
  double offset, {
  Size? Function(String asset)? imageSize,
}) {
  final m = BookMeasurer(styles, width, fitTables: false, imageSize: imageSize);
  var y = scrollTopPadding;
  if (y >= offset) return BookSpot.title;
  var last = BookSpot.title;
  y += m.titleHeight(page.title) + NamoSpace.lg;
  for (var b = 0; b < page.blocks.length; b++) {
    if (b > 0) y += bookBlockGap(page.blocks[b - 1], page.blocks[b]);
    final metrics = m.measure(page.blocks[b]);
    for (final (dy, char) in metrics.lineTops) {
      last = BookSpot(b, char);
      if (y + dy >= offset) return last;
    }
    y += metrics.height;
  }
  return last;
}

/// The scroll offset that brings the line holding [spot] to the top of
/// [page]'s scroll column [width] wide (laid out as for [spotAtOffset], of
/// which it is the inverse: the spot at the offset found is that line's).
/// 0 for the title; the last line's offset for a spot past the end.
double offsetOfSpot(
  BookPage page,
  BookTextStyles styles,
  double width,
  BookSpot spot, {
  Size? Function(String asset)? imageSize,
}) {
  if (spot.block < 0 || page.blocks.isEmpty) return 0;
  final m = BookMeasurer(styles, width, fitTables: false, imageSize: imageSize);
  var y = scrollTopPadding + m.titleHeight(page.title) + NamoSpace.lg;
  var line = y;
  for (var b = 0; b < page.blocks.length; b++) {
    if (b > 0) y += bookBlockGap(page.blocks[b - 1], page.blocks[b]);
    final metrics = m.measure(page.blocks[b]);
    for (final (dy, char) in metrics.lineTops) {
      if (b == spot.block && char > spot.char) return line;
      line = y + dy;
    }
    if (b == spot.block) return line;
    y += metrics.height;
  }
  return line;
}

/// Cuts pages one after another from a cursor: the block, the part of it
/// (item, verse line or table row) and the line within that part.
class _Cutter {
  _Cutter(this.page, this.box, this.m);

  final BookPage page;
  final PageBox box;
  final BookMeasurer m;
  final _metrics = <int, BlockMetrics>{};

  bool _titleDone = false;
  int _block = 0, _part = 0, _line = 0;

  List<PageSlice> _slices = [];
  double _bottom = 0;

  bool get done => _titleDone && _block >= page.blocks.length;

  BlockMetrics _measure(int b) => _metrics[b] ??= m.measure(page.blocks[b]);

  ScreenPage nextPage() {
    _slices = [];
    _bottom = 0;
    if (!_titleDone) {
      _titleDone = true;
      _slices.add(TitleSlice(top: 0, height: m.titleHeight(page.title)));
      _bottom = _slices.first.height;
    }
    while (_block < page.blocks.length && _place()) {}
    _keepHeadingsWithNext();
    return ScreenPage(List.unmodifiable(_slices));
  }

  bool get _empty => _slices.isEmpty;

  /// The page so far holds only the title, headings or subheads: what
  /// follows must start here, or they would end the page alone.
  bool get _onlyHeadings =>
      !_empty &&
      _slices.every(
        (s) =>
            s is TitleSlice ||
            s is BlockSlice &&
                (page.blocks[s.block] is BookHeading ||
                    page.blocks[s.block] is BookSubhead),
      );

  double _gap(int block) =>
      _gapBefore(page.blocks, _slices.lastOrNull, block);

  /// The height left for a slice of [block].
  double _room(int block) => box.height - _bottom - _gap(block);

  void _add(int block, PageSlice Function(double top) make) {
    final slice = make(_bottom + _gap(block));
    _slices.add(slice);
    _bottom = slice.top + slice.height;
  }

  /// Done with this block: on to the next.
  bool _nextBlock() {
    _block++;
    _part = 0;
    _line = 0;
    return true;
  }

  /// Places what fits of the block at the cursor. True when the block is
  /// done; false when the page is full.
  bool _place() {
    final b = _block;
    final metrics = _measure(b);
    final room = _room(b);
    switch (metrics) {
      case WholeMetrics(:final height):
        if (height > room && !_empty) return false;
        _add(
          b,
          (top) =>
              BlockSlice(b, spot: BookSpot(b, 0), top: top, height: height),
        );
        return _nextBlock();
      case HeadingMetrics(:final height):
        // Whole, at the top of the next page if need be; only one taller
        // than a page is broken by lines.
        if (_line == 0 && height <= room) {
          _add(
            b,
            (top) =>
                BlockSlice(b, spot: BookSpot(b, 0), top: top, height: height),
          );
          return _nextBlock();
        }
        if (_line == 0 && height <= box.height) return false;
        return _placeLines(b, metrics.lines);
      case ParaMetrics(:final lines):
        return _placeLines(b, lines);
      case ItemsMetrics():
        return _placeItems(b, metrics, room);
      case GathaMetrics():
        return _placeGatha(b, metrics, room);
      case TableMetrics():
        return _placeTable(b, metrics, room);
      case ImageMetrics(:final height):
        var scale = 1.0;
        if (_onlyHeadings && height > room && room > 0) {
          // Moved on, the headings above would end this page alone.
          scale = room / height;
        } else if (height > box.height) {
          if (!_empty) return false;
          scale = box.height / height;
        } else if (height > room && !_empty) {
          return false;
        }
        _add(
          b,
          (top) => ImageSlice(
            b,
            scale,
            spot: BookSpot(b, 0),
            top: top,
            height: height * scale,
          ),
        );
        return _nextBlock();
    }
  }

  /// Places what fits of a paragraph's (or a heading's) lines.
  bool _placeLines(int b, TextLines lines) {
    final stop = _flow(
      b,
      lines.count,
      _line,
      lines.height,
      (from, to, top, height) => from == 0 && to == lines.count
          ? BlockSlice(b, spot: BookSpot(b, 0), top: top, height: height)
          : LinesSlice(
              b,
              0,
              lines.start(from),
              lines.end(to),
              spot: BookSpot(b, lines.start(from)),
              top: top,
              height: height,
            ),
    );
    if (stop == lines.count) return _nextBlock();
    _line = stop;
    return false;
  }

  /// Places lines from [from] of a run of [count] lines (a paragraph or an
  /// item) as one slice made by [make], as many as fit, keeping 2 lines on
  /// each side of a break when the run has 4 or more, and a shorter run
  /// whole. Returns the line it stopped before: [count] when all are
  /// placed, [from] when none could be.
  int _flow(
    int block,
    int count,
    int from,
    double Function(int from, int to) heightOf,
    PageSlice Function(int from, int to, double top, double height) make,
  ) {
    final room = _room(block);
    var fit = 0;
    while (from + fit < count && heightOf(from, from + fit + 1) <= room) {
      fit++;
    }
    final rest = count - from;
    var cut = fit;
    if (fit < rest) {
      if (count >= 4) {
        cut = math.min(fit, rest - 2);
        if (cut < 2) cut = 0;
      } else if (from == 0) {
        cut = 0;
      }
      // An empty page takes what fits, at least a line, so cutting goes on.
      if (cut == 0 && _empty) cut = math.max(fit, 1);
    }
    if (cut > 0) {
      final to = from + cut;
      _add(block, (top) => make(from, to, top, heightOf(from, to)));
    }
    return from + cut;
  }

  bool _placeItems(int b, ItemsMetrics metrics, double room) {
    if (_part == 0 && _line == 0 && metrics.height <= room) {
      _add(
        b,
        (top) => BlockSlice(
          b,
          spot: BookSpot(b, 0),
          top: top,
          height: metrics.height,
        ),
      );
      return _nextBlock();
    }
    while (_part < metrics.items.length) {
      final i = _part, lines = metrics.items[i];
      final stop = _flow(
        b,
        lines.count,
        _line,
        (from, to) => metrics.itemHeight(i, from, to),
        (from, to, top, height) => LinesSlice(
          b,
          i,
          lines.start(from),
          lines.end(to),
          spot: BookSpot(b, metrics.itemChars[i] + lines.start(from)),
          top: top,
          height: height,
        ),
      );
      if (stop < lines.count) {
        _line = stop;
        return false;
      }
      _part++;
      _line = 0;
    }
    return _nextBlock();
  }

  bool _placeGatha(int b, GathaMetrics metrics, double room) {
    final count = metrics.lineHeights.length;
    if (_part == 0 && _line == 0) {
      if (metrics.height <= room) {
        _add(
          b,
          (top) => BlockSlice(
            b,
            spot: BookSpot(b, 0),
            top: top,
            height: metrics.height,
          ),
        );
        return _nextBlock();
      }
      // Fits a page: moves to the next whole, unless only headings are
      // above it here (then it starts under them, broken).
      if (metrics.height <= box.height && !_onlyHeadings) return false;
    }
    // Taller than a page: broken between its lines, 2 or more at the foot
    // of a page. A verse line taller than a page is itself broken between
    // the lines it wraps to, as a paragraph is.
    while (_part < count) {
      final from = _part;
      if (_line > 0 || metrics.lineHeights[from] > box.height) {
        final wrapped = metrics.wrapped[from];
        final stop = _flow(
          b,
          wrapped.count,
          _line,
          wrapped.height,
          (a, z, top, height) => LinesSlice(
            b,
            from,
            wrapped.start(a),
            wrapped.end(z),
            spot: BookSpot(b, metrics.lineChars[from] + wrapped.start(a)),
            top: top,
            height: height,
          ),
        );
        if (stop < wrapped.count) {
          _line = stop;
          return false;
        }
        _part++;
        _line = 0;
        continue;
      }
      final left = _room(b);
      var fit = 0;
      while (from + fit < count &&
          metrics.lines(from, from + fit + 1) <= left) {
        fit++;
      }
      if (fit < count - from && fit < 2 && !_empty) return false;
      if (fit == 0) fit = 1;
      final to = from + fit;
      _add(
        b,
        (top) => GathaSlice(
          b,
          from,
          to,
          spot: BookSpot(b, metrics.lineChars[from]),
          top: top,
          height: metrics.lines(from, to),
        ),
      );
      _part = to;
      // Only a verse line taller than a page goes on under these.
      if (to < count && metrics.lineHeights[to] <= box.height) return false;
    }
    return _nextBlock();
  }

  bool _placeTable(int b, TableMetrics metrics, double room) {
    final rows = metrics.rows;
    if (_part == 0) {
      if (metrics.height <= room) {
        _addRows(b, metrics, 0, rows, false);
        return _nextBlock();
      }
      // Fits a page: moves to the next whole, unless only headings are
      // above it here (then it starts under them, broken).
      if (metrics.height <= box.height && !_onlyHeadings) return false;
    }
    // Taller than a page: broken between rows, the header row repeated on
    // each later page, and never a header alone at the foot of a page.
    final from = _part;
    final repeat = metrics.header && from > 0;
    final over = repeat ? metrics.rowHeights[0] : 0.0;
    var fit = 0;
    while (from + fit < rows &&
        over + metrics.rowsHeight(from, from + fit + 1) <= room) {
      fit++;
    }
    final least = metrics.header && from == 0 ? math.min(2, rows) : 1;
    if (fit < least && fit < rows - from) {
      if (!_empty) return false;
      fit = math.max(fit, 1);
    }
    // A row taller than the room (only ever alone on its page) is scaled
    // to fit it, as a picture is.
    final tall = over + metrics.rowsHeight(from, from + fit);
    _addRows(
      b,
      metrics,
      from,
      from + fit,
      repeat,
      scale: tall > room && room > 0 ? room / tall : 1,
    );
    _part = from + fit;
    return _part == rows ? _nextBlock() : false;
  }

  void _addRows(
    int b,
    TableMetrics metrics,
    int from,
    int to,
    bool repeat, {
    double scale = 1,
  }) {
    final height =
        ((repeat ? metrics.rowHeights[0] : 0.0) +
            metrics.rowsHeight(from, to)) *
        scale;
    _add(
      b,
      (top) => TableSlice(
        b,
        from,
        to,
        repeat,
        scale: scale,
        spot: BookSpot(b, metrics.rowChars[from]),
        top: top,
        height: height,
      ),
    );
  }

  /// A page that is full (not the chapter's last) never ends with a heading
  /// or subhead: it goes to the next page with what follows it, unless it
  /// is all the page holds.
  void _keepHeadingsWithNext() {
    if (done) return;
    while (_slices.length > 1) {
      final last = _slices.last;
      if (last is! BlockSlice) return;
      final block = page.blocks[last.block];
      if (block is! BookHeading && block is! BookSubhead) return;
      _slices.removeLast();
      _block = last.block;
      _part = 0;
      _line = 0;
    }
  }
}
