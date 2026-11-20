/// Drawing one screen page of a book: the slices the paginator cut, top to
/// bottom, each exactly as tall as it measured them.
library;

import 'package:flutter/material.dart';

import '../../design/tokens.dart';
import '../book_blocks.dart';
import '../book_model.dart';
import 'book_paginator.dart';

/// The space between a sheet's edge and its text.
const pageSheetPadding = NamoSpace.lg;

/// A page of paper: [NamoPalette.surface] with the app's shadow and soft
/// corners, its [child] inset by [pageSheetPadding].
class PageSheet extends StatelessWidget {
  const PageSheet({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(NamoRadius.sm),
        boxShadow: p.floatShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(pageSheetPadding),
        child: child,
      ),
    );
  }
}

/// The slices of [page] (a screen page of [chapter]) drawn top to bottom
/// with the paginator's gaps. The text starts at the top of the available
/// space and is as wide as it, so give it the [PageBox] it was cut for
/// (inside the sheet's padding when [sheet]). With [sheet] the page is a
/// [PageSheet]; otherwise it is full-bleed on the background.
class ScreenPageView extends StatelessWidget {
  const ScreenPageView({
    super.key,
    required this.chapter,
    required this.page,
    required this.styles,
    required this.sheet,
  });

  final BookPage chapter;
  final ScreenPage page;
  final BookTextStyles styles;
  final bool sheet;

  @override
  Widget build(BuildContext context) {
    final slices = page.slices;
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < slices.length; i++) ...[
          SizedBox(height: gapBefore(i == 0 ? null : slices[i - 1], slices[i])),
          KeyedSubtree(
            key: ValueKey('page-slice-$i'),
            child: _slice(slices[i]),
          ),
        ],
      ],
    );
    return RepaintBoundary(
      child: sheet
          ? PageSheet(child: text)
          : ColoredBox(color: NamoPalette.of(context).background, child: text),
    );
  }

  Widget _slice(PageSlice slice) {
    final s = styles;
    switch (slice) {
      case TitleSlice():
        return Semantics(
          header: true,
          child: Text(chapter.title, style: s.title),
        );
      case BlockSlice(:final block):
        return BookBlockView(
          block: chapter.blocks[block],
          styles: s,
          fitTables: true,
        );
      case LinesSlice(
        :final block,
        :final item,
        :final charStart,
        :final charEnd,
      ):
        return _lines(chapter.blocks[block], item, charStart, charEnd);
      case GathaSlice(:final block, :final fromLine, :final toLine):
        final g = chapter.blocks[block] as BookGatha;
        return Padding(
          padding: const EdgeInsetsDirectional.only(start: gathaIndent),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final line in g.lines.sublist(fromLine, toLine))
                Text(line, style: s.prose),
            ],
          ),
        );
      case TableSlice(
        :final block,
        :final fromRow,
        :final toRow,
        :final repeatHeader,
        :final scale,
        :final height,
      ):
        final t = chapter.blocks[block] as BookTable;
        final table = BookTableView(
          rows: t.rows,
          border: s.border,
          styleOf: (r) => s.tableRow(t, r),
          fitWidth: true,
          repeatHeader: repeatHeader,
          fromRow: fromRow,
          toRow: toRow,
        );
        if (scale == 1) return table;
        // Laid out at the full width, then drawn smaller, centred.
        return SizedBox(
          height: height,
          child: LayoutBuilder(
            builder: (context, constraints) => Center(
              child: SizedBox(
                width: constraints.maxWidth * scale,
                child: FittedBox(
                  fit: BoxFit.fitWidth,
                  alignment: Alignment.topCenter,
                  child: SizedBox(width: constraints.maxWidth, child: table),
                ),
              ),
            ),
          ),
        );
      case ImageSlice(:final block, :final scale, :final height):
        final image = chapter.blocks[block] as BookImage;
        return SizedBox(
          height: height,
          child: FractionallySizedBox(
            widthFactor: scale,
            child: BookPicture(asset: image.asset!, alt: image.alt),
          ),
        );
    }
  }

  /// The text `charStart` to `charEnd` of a paragraph, heading, subhead,
  /// list item, footnote or verse line, in that block's style.
  Widget _lines(BookBlock b, int item, int charStart, int charEnd) {
    final s = styles;
    if (b is BookGatha) {
      return Padding(
        padding: const EdgeInsetsDirectional.only(start: gathaIndent),
        child: Text(
          b.lines[item].substring(charStart, charEnd),
          style: s.prose,
        ),
      );
    }
    final whole = switch (b) {
      BookPara(:final text) => (text, s.prose),
      BookHeading(:final text) => (text, s.heading),
      BookSubhead(:final text) => (text, s.strong),
      _ => null,
    };
    if (whole case (final text, final style)) {
      return Text(text.substring(charStart, charEnd), style: style);
    }
    final (labels, items, style, minLead) = switch (b) {
      final BookList l => (listLabels(l), l.items, s.prose, listMinLead),
      final BookFootnotes f => (
        footnoteLabels(f),
        f.items,
        s.caption,
        footnoteMinLead,
      ),
      _ => throw StateError('lines of $b'),
    };
    final lead = leadWidth(labels, style, minLead, s.scaler, s.direction);
    final label = labels[item];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (b is BookFootnotes && item == 0 && charStart == 0)
          FootnoteRule(color: s.border),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (label != null)
              SizedBox(
                width: lead,
                child: charStart == 0
                    ? Text(label, style: style, softWrap: false)
                    : null,
              ),
            Expanded(
              child: Text(
                items[item].substring(charStart, charEnd),
                style: style,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
