/// How tall a book page's blocks are drawn at a width, line by line, with
/// the same styles, leads and table widths `book_blocks.dart` draws them
/// with.
library;

import 'dart:math' as math;

import 'package:flutter/painting.dart';

import '../book_blocks.dart';
import '../book_model.dart';

/// Where each of a run of texts [lengths] long starts when they are
/// counted one after another.
List<int> runningStarts(List<int> lengths) {
  final starts = <int>[];
  var at = 0;
  for (final n in lengths) {
    starts.add(at);
    at += n;
  }
  return starts;
}

/// A text laid out at a width: where each line starts and how tall it is.
class TextLines {
  TextLines._(this.text, this.starts, this.heights);

  factory TextLines.layout(
    String text,
    TextStyle style,
    double width,
    TextScaler scaler,
    TextDirection dir,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: dir,
      textScaler: scaler,
    )..layout(maxWidth: width);
    final metrics = painter.computeLineMetrics();
    final starts = <int>[], heights = <double>[];
    for (final line in metrics) {
      final at = painter.getPositionForOffset(Offset(0, line.baseline));
      starts.add(painter.getLineBoundary(at).start);
      heights.add(line.height);
    }
    painter.dispose();
    if (starts.isEmpty) {
      starts.add(0);
      heights.add(0);
    }
    return TextLines._(text, starts, heights);
  }

  final String text;

  /// The character each line starts at.
  final List<int> starts;
  final List<double> heights;

  int get count => starts.length;

  /// Where lines `[a, b)` start in the text.
  int start(int a) => starts[a];

  /// Where lines `[a, b)` end in the text: the next line's start, less the
  /// hard line break that ends line `b - 1` (drawn, it would add a line).
  int end(int b) {
    if (b >= count) return text.length;
    final next = starts[b];
    return next > 0 && text[next - 1] == '\n' ? next - 1 : next;
  }

  /// How tall lines `[a, b)` are.
  double height(int a, int b) {
    var h = 0.0;
    for (var i = a; i < b; i++) {
      h += heights[i];
    }
    return h;
  }
}

/// How one block is drawn: its height, and where each of its lines starts
/// (its distance from the block's top and the character it starts at).
sealed class BlockMetrics {
  double get height;

  /// The block's lines, top to bottom: (distance from the block's top,
  /// character within the block).
  Iterable<(double, int)> get lineTops;
}

/// A paragraph.
class ParaMetrics extends BlockMetrics {
  ParaMetrics(this.lines);
  final TextLines lines;

  @override
  double get height => lines.height(0, lines.count);

  @override
  Iterable<(double, int)> get lineTops sync* {
    var y = 0.0;
    for (var i = 0; i < lines.count; i++) {
      yield (y, lines.starts[i]);
      y += lines.heights[i];
    }
  }
}

/// A heading or subhead: kept whole unless taller than a page.
class HeadingMetrics extends ParaMetrics {
  HeadingMetrics(super.lines);
}

/// A picture's caption: never broken.
class WholeMetrics extends BlockMetrics {
  WholeMetrics(this.height);
  @override
  final double height;

  @override
  Iterable<(double, int)> get lineTops => const [(0.0, 0)];
}

/// A verse: each of its lines (a line may wrap).
class GathaMetrics extends BlockMetrics {
  GathaMetrics(this.lineHeights, this.lineChars);
  final List<double> lineHeights;

  /// The character each verse line starts at, counting the lines before it
  /// one after another.
  final List<int> lineChars;

  @override
  double get height => lines(0, lineHeights.length);

  double lines(int a, int b) {
    var h = 0.0;
    for (var i = a; i < b; i++) {
      h += lineHeights[i];
    }
    return h;
  }

  @override
  Iterable<(double, int)> get lineTops sync* {
    var y = 0.0;
    for (var i = 0; i < lineHeights.length; i++) {
      yield (y, lineChars[i]);
      y += lineHeights[i];
    }
  }
}

/// A list or the footnotes: items, each led by its label.
class ItemsMetrics extends BlockMetrics {
  ItemsMetrics({
    required this.labels,
    required this.items,
    required this.labelHeight,
    required this.rule,
  }) : itemChars = runningStarts([for (final i in items) i.text.length]);

  final List<String?> labels;
  final List<TextLines> items;
  final double labelHeight;

  /// The height of what is drawn over the first item (the footnotes' rule),
  /// or 0.
  final double rule;

  /// The character each item starts at, counting the items before it one
  /// after another.
  final List<int> itemChars;

  /// How tall lines `[a, b)` of item [i] are drawn, with its label when
  /// they include the first line and the rule over the first item.
  double itemHeight(int i, int a, int b) {
    var h = items[i].height(a, b);
    if (a == 0 && labels[i] != null) h = math.max(h, labelHeight);
    if (a == 0 && i == 0) h += rule;
    return h;
  }

  @override
  double get height {
    var h = 0.0;
    for (var i = 0; i < items.length; i++) {
      h += itemHeight(i, 0, items[i].count);
    }
    return h;
  }

  @override
  Iterable<(double, int)> get lineTops sync* {
    var y = rule;
    for (var i = 0; i < items.length; i++) {
      final lines = items[i];
      var lineY = y;
      for (var l = 0; l < lines.count; l++) {
        yield (lineY, itemChars[i] + lines.starts[l]);
        lineY += lines.heights[l];
      }
      y += itemHeight(i, 0, lines.count) - (i == 0 ? rule : 0);
    }
  }
}

/// A table: each row's height, at the scale it is drawn.
class TableMetrics extends BlockMetrics {
  TableMetrics(this.rowHeights, this.rowChars, this.header);
  final List<double> rowHeights;

  /// The character each row starts at, counting the cells before it one
  /// after another.
  final List<int> rowChars;
  final bool header;

  int get rows => rowHeights.length;

  double rowsHeight(int a, int b) {
    var h = 0.0;
    for (var i = a; i < b; i++) {
      h += rowHeights[i];
    }
    return h;
  }

  @override
  double get height => rowsHeight(0, rows);

  @override
  Iterable<(double, int)> get lineTops sync* {
    var y = 0.0;
    for (var r = 0; r < rows; r++) {
      yield (y, rowChars[r]);
      y += rowHeights[r];
    }
  }
}

/// A bundled picture at the full width.
class ImageMetrics extends BlockMetrics {
  ImageMetrics(this.height);
  @override
  final double height;

  @override
  Iterable<(double, int)> get lineTops => const [(0.0, 0)];
}

/// Measures a page's title and blocks at [width] with [styles].
class BookMeasurer {
  BookMeasurer(
    this.styles,
    this.width, {
    required this.fitTables,
    this.imageSize,
  });

  final BookTextStyles styles;
  final double width;

  /// Tables are shrunk to the width (Pages) rather than scrolling (Scroll).
  final bool fitTables;

  /// A bundled picture's size in pixels; null, or a null answer, takes a
  /// picture as 4:3.
  final Size? Function(String asset)? imageSize;

  TextLines _lines(String text, TextStyle style, double width) =>
      TextLines.layout(text, style, width, styles.scaler, styles.direction);

  double _height(String text, TextStyle style, double width) {
    final lines = _lines(text, style, width);
    return lines.height(0, lines.count);
  }

  double titleHeight(String title) => _height(title, styles.title, width);

  BlockMetrics measure(BookBlock block) {
    final s = styles;
    return switch (block) {
      BookPara(:final text) => ParaMetrics(_lines(text, s.prose, width)),
      BookHeading(:final text) => HeadingMetrics(
        _lines(text, s.heading, width),
      ),
      BookSubhead(:final text) => HeadingMetrics(_lines(text, s.strong, width)),
      BookGatha(:final lines) => GathaMetrics([
        for (final l in lines) _height(l, s.prose, width - gathaIndent),
      ], runningStarts([for (final l in lines) l.length])),
      final BookList list => _items(
        listLabels(list),
        list.items,
        s.prose,
        listMinLead,
        0,
      ),
      final BookFootnotes notes => _items(
        footnoteLabels(notes),
        notes.items,
        s.caption,
        footnoteMinLead,
        footnoteRuleHeight,
      ),
      final BookTable table => _table(table),
      BookImage(:final alt, :final asset) =>
        asset == null
            ? WholeMetrics(
                _height(
                  alt.isEmpty ? 'Picture on pitaka.lk' : 'Picture: $alt',
                  s.caption,
                  width,
                ),
              )
            : ImageMetrics(_imageHeight(asset)),
    };
  }

  ItemsMetrics _items(
    List<String?> labels,
    List<String> items,
    TextStyle style,
    double minLead,
    double rule,
  ) {
    final lead = leadWidth(
      labels,
      style,
      minLead,
      styles.scaler,
      styles.direction,
    );
    return ItemsMetrics(
      labels: labels,
      items: [
        for (var i = 0; i < items.length; i++)
          _lines(items[i], style, labels[i] == null ? width : width - lead),
      ],
      labelHeight: labels.any((l) => l != null)
          ? _height(labels.firstWhere((l) => l != null)!, style, lead)
          : 0,
      rule: rule,
    );
  }

  TableMetrics _table(BookTable table) {
    final rows = table.rows;
    TextStyle styleOf(int r) => styles.tableRow(table, r);
    final layout = tableLayout(
      rows,
      styleOf,
      width,
      styles.scaler,
      styles.direction,
      fitWidth: fitTables,
    );
    final heights = <double>[];
    for (var r = 0; r < rows.length; r++) {
      var h = 0.0;
      for (var c = 0; c < layout.widths.length; c++) {
        final cell = c < rows[r].length ? rows[r][c] : '';
        final cellHeight =
            _height(cell, styleOf(r), layout.widths[c] - 2 * tableCellPad) +
            2 * tableCellPad;
        if (cellHeight > h) h = cellHeight;
      }
      heights.add(h * layout.scale);
    }
    return TableMetrics(
      heights,
      runningStarts([
        for (final row in rows) row.fold(0, (n, c) => n + c.length),
      ]),
      table.header,
    );
  }

  double _imageHeight(String asset) {
    final size = imageSize?.call(asset);
    if (size == null || size.width <= 0 || size.height <= 0) {
      return width * 3 / 4;
    }
    return width * size.height / size.width;
  }
}
