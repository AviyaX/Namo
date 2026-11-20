import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../design/tokens.dart';
import '../design/typography.dart';
import '../design/widgets/buttons.dart';
import '../design/widgets/floating_bar.dart';
import '../design/widgets/not_found.dart';
import '../reader/reader_settings_sheet.dart';
import '../router.dart';
import '../settings/reading_language.dart';
import '../settings/settings.dart';
import 'book_model.dart';
import 'book_places.dart';
import 'book_widgets.dart';
import 'books_repository.dart';

/// The place is saved once the page has been still this long.
const _saveDelay = Duration(milliseconds: 400);

/// One page of a book, full screen: its title and text in one column, the
/// way back and the reading settings above, the previous and next reading
/// pages and the count below.
///
/// The place (the page and how far down it) is noted on opening and once
/// scrolling stops, and a page opened again at its saved place returns
/// there. A page without text, or a number past the end, goes on to the
/// nearest reading page.
class BookReaderScreen extends ConsumerStatefulWidget {
  const BookReaderScreen({super.key, required this.id, required this.n});

  final String id;
  final int n;

  @override
  ConsumerState<BookReaderScreen> createState() => _BookReaderScreenState();
}

class _BookReaderScreenState extends ConsumerState<BookReaderScreen> {
  final _scroll = ScrollController();
  late final BookPlacesController _places;

  /// The book the steps below were worked out for, and the page's key.
  Book? _book;
  String? _key;
  int _index = 0, _total = 0;
  int? _previous, _next;

  /// Set once the loaded page has been shown (or sent on).
  bool _opened = false;

  /// The last offset seen, and whether it is not saved yet.
  double _offset = 0;
  bool _dirty = false;
  Timer? _saveTimer;

  /// Set once this page has been left. It may stay on screen for its exit
  /// transition, still moving, but its place is no longer the person's: the
  /// next page's is.
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _places = ref.read(bookPlacesProvider.notifier);
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    // Providers cannot change while the tree is being torn down, so the last
    // place is handed over once this frame is done.
    if (_dirty && !_leaving) {
      final places = _places, id = widget.id, n = widget.n, key = _key;
      final offset = _offset;
      SchedulerBinding.instance.addPostFrameCallback(
        (_) => places.remember(id, n: n, key: key, offset: offset),
      );
    }
    _scroll.dispose();
    super.dispose();
  }

  // ---- place --------------------------------------------------------------

  bool _onScroll(ScrollNotification notification) {
    // Only the page's own scrolling (a wide table scrolls sideways inside).
    if (_leaving || notification.depth != 0 || !_scroll.hasClients) {
      return false;
    }
    _offset = _scroll.offset;
    _dirty = true;
    _saveTimer?.cancel();
    _saveTimer = Timer(_saveDelay, _save);
    return false;
  }

  void _save() {
    _saveTimer?.cancel();
    _saveTimer = null;
    if (!_dirty) return;
    _dirty = false;
    _places.remember(widget.id, n: widget.n, key: _key, offset: _offset);
  }

  /// The page has loaded: notes it as the place, or returns to the saved
  /// offset when the place is this page (found by its key first).
  void _openPlace() {
    final book = _book;
    if (!mounted || _leaving || book == null) return;
    final place = ref.read(bookPlacesProvider).of(widget.id);
    if (place != null && place.pageIn(book) == widget.n) {
      // Not laid out: the saved offset is kept rather than noted as 0.
      if (!_scroll.hasClients) return;
      final to = place.offset.clamp(0.0, _scroll.position.maxScrollExtent);
      _scroll.jumpTo(to);
      _offset = to;
      _dirty = false;
      _saveTimer?.cancel();
      _saveTimer = null;
      // Found by its key under another n, or saved before keys were: noted
      // again as it is now.
      if (place.n != widget.n || place.key != _key) {
        _places.remember(widget.id, n: widget.n, key: _key, offset: to);
      }
    } else {
      _places.remember(widget.id, n: widget.n, key: _key, offset: 0);
    }
  }

  void _backToBeginning() {
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  // ---- navigation ---------------------------------------------------------

  /// Leaves for [location], saving a place not saved yet first.
  void _go(String location) {
    _save();
    _leaving = true;
    context.go(location);
  }

  void _back() {
    final book = ref.read(bookProvider(widget.id)).value;
    final parent = book?.parentOf(widget.n);
    _go(
      parent == null
          ? Routes.book(widget.id)
          : Routes.bookContents(widget.id, parent.n),
    );
  }

  void _retry() {
    if (ref.read(booksIndexProvider).hasError) {
      ref.invalidate(booksIndexProvider);
    }
    ref.invalidate(bookProvider(widget.id));
  }

  void _stepsFor(Book book) {
    if (identical(book, _book)) return;
    _book = book;
    _key = book.page(widget.n)?.key;
    _index = book.readingIndexOf(widget.n);
    _total = book.readingPages.length;
    _previous = book.previousReading(widget.n);
    _next = book.nextReading(widget.n);
  }

  // ---- build --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    final index = ref.watch(booksIndexProvider);
    final summary = index.value?.byId(widget.id);
    if (index.hasValue && summary == null) return const NotFoundScreen();
    final loaded = ref.watch(bookProvider(widget.id));
    final book = loaded.value;
    final title = book?.title ?? summary?.title ?? '';

    Widget body;
    Widget? bar;
    if (book != null) {
      final page = book.page(widget.n);
      if (page == null || !page.hasText) {
        if (!_opened) {
          _opened = true;
          SchedulerBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _leaving = true;
            final target = book.firstReadingFrom(widget.n);
            context.go(
              target == null
                  ? Routes.book(widget.id)
                  : Routes.bookReader(widget.id, target),
            );
          });
        }
        body = const BookLoading();
      } else {
        _stepsFor(book);
        if (!_opened) {
          _opened = true;
          SchedulerBinding.instance.addPostFrameCallback((_) => _openPlace());
        }
        body = _page(context, page);
        bar = _bottomBar(context);
      }
    } else if ((loaded.hasError || index.hasError) && !loaded.isLoading) {
      body = BookLoadError(onRetry: _retry);
    } else {
      body = const BookLoading();
    }

    // The reader is the only page on the stack, so a system Back would
    // otherwise leave the app.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: p.background,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TopBar(
              title: title,
              onBack: _back,
              onSettings: bar == null
                  ? null
                  : () => showReaderSettingsSheet(
                      context,
                      onBackToBeginning: _backToBeginning,
                      textOnly: true,
                      bookMode: true,
                    ),
            ),
            Expanded(child: body),
          ],
        ),
        bottomNavigationBar: bar,
      ),
    );
  }

  Widget _page(BuildContext context, BookPage page) {
    final p = NamoPalette.of(context);
    final settings = ref.watch(settingsProvider);
    final prose = readingStyle(
      ReadingLanguage.sinhala,
      fontScale: settings.fontScale,
      lineSpacing: settings.lineSpacing,
      color: p.text,
    );
    final margin = NamoSizes.pageMargin(MediaQuery.sizeOf(context).width);
    final blocks = [for (final b in page.blocks) _block(context, b, prose)];
    return SafeArea(
      top: false,
      child: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: SingleChildScrollView(
          controller: _scroll,
          padding: EdgeInsets.fromLTRB(
            margin,
            NamoSpace.sm,
            margin,
            NamoSpace.xxl,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: NamoSizes.readingColumn,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      page.title,
                      style: NamoType.sectionTitleSinhala(p.text),
                    ),
                  ),
                  const SizedBox(height: NamoSpace.lg),
                  for (var i = 0; i < blocks.length; i++) ...[
                    if (i > 0) const SizedBox(height: NamoSpace.md),
                    blocks[i],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _block(BuildContext context, BookBlock block, TextStyle prose) {
    final p = NamoPalette.of(context);
    final strong = prose.copyWith(fontWeight: FontWeight.w600);
    final caption = NamoType.caption(p.textSecondary);
    return switch (block) {
      BookPara(:final text) => Text(text, style: prose),
      BookHeading(:final text) => Text(
        text,
        style: strong.copyWith(fontSize: prose.fontSize! * 1.25),
      ),
      BookSubhead(:final text) => Text(text, style: strong),
      BookGatha(:final lines) => Padding(
        padding: const EdgeInsetsDirectional.only(start: NamoSpace.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [for (final line in lines) Text(line, style: prose)],
        ),
      ),
      BookList(:final marker, :final start, :final items) => _LeadRows(
        labels: [
          for (var i = 0; i < items.length; i++)
            switch (marker) {
              ListMarker.number => '${start + i}.',
              ListMarker.bullet => '•',
              ListMarker.none => null,
            },
        ],
        items: items,
        style: prose,
        minLead: NamoSpace.xxl,
      ),
      BookFootnotes(:final items) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: 1, child: ColoredBox(color: p.border)),
          const SizedBox(height: NamoSpace.sm),
          _LeadRows(
            labels: [for (var i = 0; i < items.length; i++) '${i + 1}'],
            items: items,
            style: caption,
            minLead: NamoSpace.xl,
          ),
        ],
      ),
      BookTable(:final header, :final rows) => _BookTable(
        rows: rows,
        border: p.border,
        styleOf: (r) => header && r == 0 ? strong : prose,
      ),
      BookImage(:final alt, :final asset) =>
        asset != null
            ? Semantics(
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
              )
            : Text(
                alt.isEmpty ? 'Picture on pitaka.lk' : 'Picture: $alt',
                style: caption,
              ),
    };
  }

  Widget _bottomBar(BuildContext context) {
    final p = NamoPalette.of(context);
    final previous = _previous, next = _next;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(NamoSpace.lg),
        child: FloatingBar(
          child: Row(
            children: [
              NamoIconButton(
                key: const ValueKey('book-prev'),
                icon: Symbols.chevron_left_rounded,
                tooltip: 'Previous page',
                onPressed: previous == null
                    ? null
                    : () => _go(Routes.bookReader(widget.id, previous)),
              ),
              Expanded(
                // As tall as the count: the bar keeps to its own height.
                child: Center(
                  heightFactor: 1,
                  child: Text(
                    '$_index / $_total',
                    style: NamoType.caption(p.textSecondary),
                  ),
                ),
              ),
              NamoIconButton(
                key: const ValueKey('book-next'),
                icon: Symbols.chevron_right_rounded,
                tooltip: 'Next page',
                onPressed: next == null
                    ? null
                    : () => _go(Routes.bookReader(widget.id, next)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// How wide [text] is on one line in [style] at the device's text size.
double _lineWidth(BuildContext context, String text, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: DefaultTextStyle.of(context).style.merge(style),
    ),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}

/// Items, each led by its label (a number, a bullet or none) in a lead as
/// wide as the widest label at the current text size, so "14." never breaks
/// over two lines; never narrower than [minLead]. A null label has no lead.
class _LeadRows extends StatelessWidget {
  const _LeadRows({
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
    var lead = minLead;
    for (final label in labels.nonNulls.toSet()) {
      final width = _lineWidth(context, label, style).ceilToDouble();
      if (width + NamoSpace.sm > lead) lead = width + NamoSpace.sm;
    }
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
              Expanded(child: Text(items[i], style: style)),
            ],
          ),
      ],
    );
  }
}

/// A table. Columns of short cells (the syllable grids) keep their natural
/// widths and the table scrolls sideways when wider than the column of
/// text; a table with longer cells is fitted to the column, its widest
/// columns narrowed so their cells wrap, but never below a cell's longest
/// word.
class _BookTable extends StatelessWidget {
  const _BookTable({
    required this.rows,
    required this.border,
    required this.styleOf,
  });

  final List<List<String>> rows;
  final Color border;
  final TextStyle Function(int row) styleOf;

  static const _pad = NamoSpace.sm;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = rows.fold(0, (m, r) => r.length > m ? r.length : m);
      // Each column's width unwrapped (its longest line) and at the least
      // (its longest word), with the cell padding and a pixel to spare.
      final most = List.filled(columns, 0.0), least = List.filled(columns, 0.0);
      for (var r = 0; r < rows.length; r++) {
        final style = styleOf(r);
        for (var c = 0; c < rows[r].length; c++) {
          final cell = rows[r][c];
          for (final line in cell.split('\n')) {
            final w =
                _lineWidth(context, line, style).ceilToDouble() + 2 * _pad + 1;
            if (w > most[c]) most[c] = w;
          }
          for (final word in cell.split(RegExp(r'[ \n]+'))) {
            final w =
                _lineWidth(context, word, style).ceilToDouble() + 2 * _pad + 1;
            if (w > least[c]) least[c] = w;
          }
        }
      }
      final room = constraints.maxWidth;
      final natural = most.fold(0.0, (a, b) => a + b);
      final narrowest = least.fold(0.0, (a, b) => a + b);
      final List<double> widths;
      if (!room.isFinite || natural <= room) {
        widths = most;
      } else if (narrowest >= room) {
        widths = least;
      } else {
        // The room left over the narrowest widths goes to the columns that
        // can use it, in proportion to how much more each would take.
        final spare = room - narrowest, wants = natural - narrowest;
        widths = [
          for (var c = 0; c < columns; c++)
            least[c] + spare * (most[c] - least[c]) / wants,
        ];
      }
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Table(
          border: TableBorder.all(color: border),
          columnWidths: {
            for (var c = 0; c < columns; c++) c: FixedColumnWidth(widths[c]),
          },
          children: [
            for (var r = 0; r < rows.length; r++)
              TableRow(
                children: [
                  for (var c = 0; c < columns; c++)
                    Padding(
                      padding: const EdgeInsets.all(_pad),
                      child: Text(
                        c < rows[r].length ? rows[r][c] : '',
                        style: styleOf(r),
                      ),
                    ),
                ],
              ),
          ],
        ),
      );
    },
  );
}

/// The reader's quiet top bar: Back, the book's title on one line, and the
/// reading settings once the page is open.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.title, required this.onBack, this.onSettings});

  final String title;
  final VoidCallback onBack;
  final VoidCallback? onSettings;

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    return ColoredBox(
      key: const ValueKey('book-reader-top-bar'),
      color: p.background,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.all(NamoSpace.xs),
          child: Row(
            children: [
              NamoIconButton(
                icon: Symbols.arrow_back_rounded,
                tooltip: 'Back',
                onPressed: onBack,
              ),
              const SizedBox(width: NamoSpace.xs),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: NamoType.label(p.textSecondary),
                ),
              ),
              const SizedBox(width: NamoSpace.xs),
              if (onSettings != null)
                NamoIconButton(
                  icon: Symbols.tune_rounded,
                  tooltip: 'Reading settings',
                  onPressed: onSettings,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
