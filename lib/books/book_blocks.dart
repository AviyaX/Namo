/// How a book page's blocks are drawn, shared by the scroll column and the
/// screen pages, and the measurements both the drawing and the paginator
/// use, so what is measured is what is drawn.
library;

import 'package:flutter/material.dart';

import '../design/tokens.dart';
import '../design/typography.dart';
import '../settings/reading_language.dart';
import '../settings/settings.dart';
import 'book_model.dart';

/// The text styles a book page is drawn and measured with, already merged
/// with the surrounding default text style, and the text size and direction
/// they are laid out at.
@immutable
class BookTextStyles {
  const BookTextStyles({
    required this.prose,
    required this.strong,
    required this.heading,
    required this.caption,
    required this.title,
    required this.border,
    this.scaler = TextScaler.noScaling,
    this.direction = TextDirection.ltr,
  });

  /// The styles for [settings] in [palette]'s colours, each merged over
  /// [base] (the surrounding default text style).
  factory BookTextStyles.from({
    required NamoPalette palette,
    required AppSettings settings,
    TextStyle base = const TextStyle(),
    TextScaler scaler = TextScaler.noScaling,
    TextDirection direction = TextDirection.ltr,
  }) {
    final prose = base.merge(
      readingStyle(
        ReadingLanguage.sinhala,
        fontScale: settings.fontScale,
        lineSpacing: settings.lineSpacing,
        color: palette.text,
      ),
    );
    final strong = prose.copyWith(fontWeight: FontWeight.w600);
    return BookTextStyles(
      prose: prose,
      strong: strong,
      heading: strong.copyWith(fontSize: prose.fontSize! * 1.25),
      caption: base.merge(NamoType.caption(palette.textSecondary)),
      title: base.merge(NamoType.sectionTitleSinhala(palette.text)),
      border: palette.border,
      scaler: scaler,
      direction: direction,
    );
  }

  /// The styles as [context] draws them for [settings].
  static BookTextStyles of(BuildContext context, AppSettings settings) =>
      BookTextStyles.from(
        palette: NamoPalette.of(context),
        settings: settings,
        base: DefaultTextStyle.of(context).style,
        scaler: MediaQuery.textScalerOf(context),
        direction: Directionality.of(context),
      );

  /// The styles as [context] draws them for [settings] on a book's page:
  /// in the ink of the paper chosen ([AppSettings.bookPaper]), whatever the
  /// app's theme, with the soft ink for captions and footnotes and the
  /// paper's gold rule for table borders.
  static BookTextStyles onPaper(BuildContext context, AppSettings settings) {
    final p = NamoPalette.of(context);
    final c = bookColours(p, settings.bookPaper);
    return BookTextStyles.from(
      palette: p.copyWith(
        text: c.ink,
        textSecondary: c.inkSoft,
        border: c.rule,
      ),
      settings: settings,
      base: DefaultTextStyle.of(context).style,
      scaler: MediaQuery.textScalerOf(context),
      direction: Directionality.of(context),
    );
  }

  /// Paragraphs, verses, list items and table cells.
  final TextStyle prose;

  /// Subheads and a table's header row.
  final TextStyle strong;

  /// Headings inside the text.
  final TextStyle heading;

  /// Footnotes and the caption of a picture not bundled.
  final TextStyle caption;

  /// The page's own title.
  final TextStyle title;

  /// Table borders and the rule over the footnotes.
  final Color border;

  final TextScaler scaler;
  final TextDirection direction;

  /// The style of [table]'s row [r].
  TextStyle tableRow(BookTable table, int r) =>
      table.header && r == 0 ? strong : prose;

  @override
  bool operator ==(Object other) =>
      other is BookTextStyles &&
      other.prose == prose &&
      other.strong == strong &&
      other.heading == heading &&
      other.caption == caption &&
      other.title == title &&
      other.border == border &&
      other.scaler == scaler &&
      other.direction == direction;

  @override
  int get hashCode => Object.hash(
    prose,
    strong,
    heading,
    caption,
    title,
    border,
    scaler,
    direction,
  );
}

/// How wide [text] is on one line in [style].
double lineWidth(
  String text,
  TextStyle style,
  TextScaler scaler,
  TextDirection dir,
) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: dir,
    textScaler: scaler,
    maxLines: 1,
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}

/// The lead before each of [LeadRows]' items: as wide as the widest label
/// and a little gap, never narrower than [minLead].
double leadWidth(
  List<String?> labels,
  TextStyle style,
  double minLead,
  TextScaler scaler,
  TextDirection dir,
) {
  var lead = minLead;
  for (final label in labels.nonNulls.toSet()) {
    final width = lineWidth(label, style, scaler, dir).ceilToDouble();
    if (width + NamoSpace.sm > lead) lead = width + NamoSpace.sm;
  }
  return lead;
}

/// The labels a [BookList] draws before its items: numbers, bullets, or
/// none (null) when the labels are already in the text.
List<String?> listLabels(BookList list) => [
  for (var i = 0; i < list.items.length; i++)
    switch (list.marker) {
      ListMarker.number => '${list.start + i}.',
      ListMarker.bullet => '•',
      ListMarker.none => null,
    },
];

/// The labels before footnotes: 1, 2, 3 ...
List<String?> footnoteLabels(BookFootnotes notes) => [
  for (var i = 0; i < notes.items.length; i++) '${i + 1}',
];

/// The indent before a verse's lines.
const gathaIndent = NamoSpace.xl;

/// The lead a list's items are at least indented by.
const listMinLead = NamoSpace.xxl;

/// The lead footnotes are at least indented by.
const footnoteMinLead = NamoSpace.xl;

/// The height of the rule over the footnotes and the gap under it.
const footnoteRuleHeight = 1.0 + NamoSpace.sm;

/// One block of a book page, whole. Paragraphs and list and footnote item
/// text are justified; headings, verses, tables and captions are not.
class BookBlockView extends StatelessWidget {
  const BookBlockView({
    super.key,
    required this.block,
    required this.styles,
    this.fitTables = false,
  });

  final BookBlock block;
  final BookTextStyles styles;

  /// Tables are shrunk to the width instead of scrolling sideways.
  final bool fitTables;

  @override
  Widget build(BuildContext context) {
    final s = styles;
    return switch (block) {
      BookPara(:final text) => Text(
        text,
        style: s.prose,
        textAlign: TextAlign.justify,
      ),
      BookHeading(:final text) => Text(text, style: s.heading),
      BookSubhead(:final text) => Text(text, style: s.strong),
      BookGatha(:final lines) => Padding(
        padding: const EdgeInsetsDirectional.only(start: gathaIndent),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [for (final line in lines) Text(line, style: s.prose)],
        ),
      ),
      final BookList list => LeadRows(
        labels: listLabels(list),
        items: list.items,
        style: s.prose,
        minLead: listMinLead,
      ),
      final BookFootnotes notes => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FootnoteRule(color: s.border),
          LeadRows(
            labels: footnoteLabels(notes),
            items: notes.items,
            style: s.caption,
            minLead: footnoteMinLead,
          ),
        ],
      ),
      final BookTable table => BookTableView(
        rows: table.rows,
        border: s.border,
        styleOf: (r) => s.tableRow(table, r),
        fitWidth: fitTables,
      ),
      BookImage(:final alt, :final asset) =>
        asset != null
            ? BookPicture(asset: asset, alt: alt)
            : Text(
                alt.isEmpty ? 'Picture on pitaka.lk' : 'Picture: $alt',
                style: s.caption,
              ),
    };
  }
}

/// The thin rule over the footnotes and the gap under it
/// ([footnoteRuleHeight] tall).
class FootnoteRule extends StatelessWidget {
  const FootnoteRule({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SizedBox(height: 1, child: ColoredBox(color: color)),
      const SizedBox(height: NamoSpace.sm),
    ],
  );
}

/// A bundled picture at the full width, its shape kept.
class BookPicture extends StatelessWidget {
  const BookPicture({super.key, required this.asset, required this.alt});

  final String asset, alt;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: alt,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(NamoRadius.sm),
      child: Image.asset(
        asset,
        fit: BoxFit.contain,
        width: double.infinity,
        excludeFromSemantics: true,
      ),
    ),
  );
}

/// Items, each led by its label (a number, a bullet or none) in a lead as
/// wide as the widest label at the current text size, so "14." never breaks
/// over two lines; never narrower than [minLead]. A null label has no lead.
/// The items' text is justified.
class LeadRows extends StatelessWidget {
  const LeadRows({
    super.key,
    required this.labels,
    required this.items,
    required this.style,
    required this.minLead,
  });

  final List<String?> labels;
  final List<String> items;
  final TextStyle style;
  final double minLead;

  @override
  Widget build(BuildContext context) {
    final lead = leadWidth(
      labels,
      DefaultTextStyle.of(context).style.merge(style),
      minLead,
      MediaQuery.textScalerOf(context),
      Directionality.of(context),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < items.length; i++)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (labels[i] case final label?)
                SizedBox(
                  width: lead,
                  child: Text(label, style: style, softWrap: false),
                ),
              Expanded(
                child: Text(
                  items[i],
                  style: style,
                  textAlign: TextAlign.justify,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// The padding inside each table cell.
const tableCellPad = NamoSpace.sm;

/// The widths of a table's columns in [room] and the scale it is drawn at
/// (below 1 only when [fitWidth] and its narrowest widths are still wider
/// than [room]).
///
/// Columns of short cells keep their natural widths (when [fitWidth] is
/// false the table then scrolls sideways if wider than [room]); a table with
/// longer cells is fitted to [room], its widest columns narrowed so their
/// cells wrap, but never below a cell's longest word.
({List<double> widths, double scale}) tableLayout(
  List<List<String>> rows,
  TextStyle Function(int row) styleOf,
  double room,
  TextScaler scaler,
  TextDirection dir, {
  bool fitWidth = false,
}) {
  final columns = rows.fold(0, (m, r) => r.length > m ? r.length : m);
  // Each column's width unwrapped (its longest line) and at the least (its
  // longest word), with the cell padding and a pixel to spare.
  final most = List.filled(columns, 0.0), least = List.filled(columns, 0.0);
  for (var r = 0; r < rows.length; r++) {
    final style = styleOf(r);
    for (var c = 0; c < rows[r].length; c++) {
      final cell = rows[r][c];
      for (final line in cell.split('\n')) {
        final w =
            lineWidth(line, style, scaler, dir).ceilToDouble() +
            2 * tableCellPad +
            1;
        if (w > most[c]) most[c] = w;
      }
      for (final word in cell.split(RegExp(r'[ \n]+'))) {
        final w =
            lineWidth(word, style, scaler, dir).ceilToDouble() +
            2 * tableCellPad +
            1;
        if (w > least[c]) least[c] = w;
      }
    }
  }
  final natural = most.fold(0.0, (a, b) => a + b);
  final narrowest = least.fold(0.0, (a, b) => a + b);
  if (!room.isFinite || natural <= room) return (widths: most, scale: 1.0);
  if (narrowest >= room) {
    return (widths: least, scale: fitWidth ? room / narrowest : 1.0);
  }
  // The room left over the narrowest widths goes to the columns that can use
  // it, in proportion to how much more each would take.
  final spare = room - narrowest, wants = natural - narrowest;
  return (
    widths: [
      for (var c = 0; c < columns; c++)
        least[c] + spare * (most[c] - least[c]) / wants,
    ],
    scale: 1.0,
  );
}

/// A table (see [tableLayout] for its column widths), or the rows
/// [fromRow] to [toRow] of it, after the header row when [repeatHeader].
/// The column widths are always worked out from all the rows, so the parts
/// of a table cut over several pages line up.
class BookTableView extends StatelessWidget {
  const BookTableView({
    super.key,
    required this.rows,
    required this.border,
    required this.styleOf,
    this.fitWidth = false,
    this.repeatHeader = false,
    this.fromRow = 0,
    this.toRow,
  });

  final List<List<String>> rows;
  final Color border;
  final TextStyle Function(int row) styleOf;

  /// Never scrolls sideways: a table wider than the room is shrunk to it.
  final bool fitWidth;

  /// Row 0 (the header) is drawn first.
  final bool repeatHeader;

  final int fromRow;

  /// Null: to the last row.
  final int? toRow;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final base = DefaultTextStyle.of(context).style;
      final layout = tableLayout(
        rows,
        (r) => base.merge(styleOf(r)),
        constraints.maxWidth,
        MediaQuery.textScalerOf(context),
        Directionality.of(context),
        fitWidth: fitWidth,
      );
      final widths = layout.widths;
      final shown = [
        if (repeatHeader) 0,
        for (var r = fromRow; r < (toRow ?? rows.length); r++) r,
      ];
      final table = Table(
        border: TableBorder.all(color: border),
        columnWidths: {
          for (var c = 0; c < widths.length; c++)
            c: FixedColumnWidth(widths[c]),
        },
        children: [
          for (final r in shown)
            TableRow(
              children: [
                for (var c = 0; c < widths.length; c++)
                  Padding(
                    padding: const EdgeInsets.all(tableCellPad),
                    child: Text(
                      c < rows[r].length ? rows[r][c] : '',
                      style: styleOf(r),
                    ),
                  ),
              ],
            ),
        ],
      );
      if (!fitWidth) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: table,
        );
      }
      return Align(
        alignment: AlignmentDirectional.topStart,
        child: layout.scale < 1
            ? SizedBox(
                width: constraints.maxWidth,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.topStart,
                  child: table,
                ),
              )
            : table,
      );
    },
  );
}
