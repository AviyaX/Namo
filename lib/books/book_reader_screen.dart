import 'dart:async';
import 'dart:math' as math;

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
import '../settings/settings.dart';
import 'book_blocks.dart';
import 'book_model.dart';
import 'book_pages_view.dart';
import 'book_places.dart';
import 'book_widgets.dart';
import 'books_repository.dart';
import 'pagination/book_paginator.dart';

/// One page of a book, full screen, the way back and the reading settings
/// above. Read in Pages mode it is a [BookPagesView]: the text on pages
/// turned like paper, carrying on into the next reading pages while this
/// screen stays (the address follows). In Scroll mode it is the page's
/// title and text in one column, with the previous and next reading pages
/// and the count below.
///
/// In Scroll mode the place (the page, how far down it and the first line
/// shown) is noted on opening and once scrolling stops, and a page opened
/// again at its saved place returns there. Switching between Pages and
/// Scroll keeps the passage: the place is saved as the mode changes, and
/// the other view opens at it. A page without text, or a number past the
/// end, goes on to the nearest reading page.
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

  final _pagesKey = GlobalKey<BookPagesViewState>();

  /// The book and page the steps below were worked out for, and the page's
  /// key.
  Book? _book;
  int? _stepsN;
  String? _key;
  int _index = 0, _total = 0;
  int? _previous, _next;

  /// Set once the loaded page has been shown (or sent on).
  bool _opened = false;

  /// The last offset seen, and whether it is not saved yet.
  double _offset = 0;
  bool _dirty = false;
  Timer? _saveTimer;

  /// The scroll column last drawn (the page, its styles and width) and the
  /// pictures' sizes (null until they are read), to find the line at an
  /// offset and the other way.
  (BookPage, BookTextStyles, double)? _column;
  Map<String, Size>? _sizes;

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
  void didUpdateWidget(BookReaderScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // In Pages mode the screen stays while the pages move on (or another
    // page is asked for): the new page is checked afresh.
    // In Pages mode the screen also stays when a page without text is sent
    // on to the nearest reading page: the new page is not being left.
    if (oldWidget.n != widget.n) {
      _opened = false;
      _leaving = false;
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    // Providers cannot change while the tree is being torn down, so the last
    // place is handed over once this frame is done.
    if (_dirty && !_leaving) {
      final places = _places, id = widget.id, n = widget.n, key = _key;
      final offset = _offset, spot = _spotAt(offset);
      SchedulerBinding.instance.addPostFrameCallback(
        (_) => places.remember(id, n: n, key: key, offset: offset, spot: spot),
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
    _saveTimer = Timer(bookPlaceSaveDelay, _save);
    return false;
  }

  void _save() {
    _saveTimer?.cancel();
    _saveTimer = null;
    if (!_dirty) return;
    _dirty = false;
    _places.remember(
      widget.id,
      n: widget.n,
      key: _key,
      offset: _offset,
      spot: _spotAt(_offset),
    );
  }

  /// The first line at or below [offset] in the scroll column; null before
  /// it is drawn or the pictures' sizes are read (it would be measured
  /// with every picture taken as 4:3).
  BookSpot? _spotAt(double offset) {
    final column = _column;
    if (column == null || _sizes == null) return null;
    final (page, styles, width) = column;
    return spotAtOffset(page, styles, width, offset, imageSize: _imageSize);
  }

  Size? _imageSize(String asset) => _sizes?[asset];

  /// The page has loaded: notes it as the place, or returns to the saved
  /// place when it is this page (found by its key first). The saved line is
  /// gone back to when the saved offset no longer shows it at the top (the
  /// place was saved by the pages, or at another text size or width).
  void _openPlace() {
    final book = _book;
    if (!mounted || _leaving || book == null) return;
    final place = ref.read(bookPlacesProvider).of(widget.id);
    if (place != null && place.pageIn(book) == widget.n) {
      // Not laid out: the saved offset is kept rather than noted as 0.
      final column = _column;
      if (!_scroll.hasClients || column == null) return;
      final spot = place.spot;
      var to = place.offset;
      if (spot != null && _spotAt(to) != spot) {
        final (page, styles, width) = column;
        to = offsetOfSpot(page, styles, width, spot, imageSize: _imageSize);
      }
      to = to.clamp(0.0, _scroll.position.maxScrollExtent);
      _scroll.jumpTo(to);
      _offset = to;
      _dirty = false;
      _saveTimer?.cancel();
      _saveTimer = null;
      // Found by its key under another n, or saved before keys were: noted
      // again as it is now.
      if (place.n != widget.n || place.key != _key) {
        _places.remember(
          widget.id,
          n: widget.n,
          key: _key,
          offset: to,
          spot: spot ?? _spotAt(to),
        );
      }
    } else {
      _places.remember(
        widget.id,
        n: widget.n,
        key: _key,
        offset: 0,
        spot: BookSpot.title,
      );
    }
  }

  /// The reading mode is changing: the place is saved now, so the other
  /// view opens at the passage shown, and Scroll looks for it afresh.
  void _modeChanged(BookReadingMode? before, BookReadingMode now) {
    if (before == now) return;
    if (now == BookReadingMode.pages) {
      _save();
    } else {
      _pagesKey.currentState?.saveNow();
    }
    _opened = false;
  }

  void _backToBeginning() {
    final pages = _pagesKey.currentState;
    if (pages != null) return pages.backToBeginning();
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  // ---- navigation ---------------------------------------------------------

  /// Leaves for [location], saving a place not saved yet first.
  void _go(String location) {
    _save();
    _leaving = true;
    context.go(location);
  }

  /// Back from the top bar or the system: the pages save their place first.
  void _backPressed() {
    final pages = _pagesKey.currentState;
    pages == null ? _back() : pages.back();
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
    if (identical(book, _book) && _stepsN == widget.n) return;
    _book = book;
    _stepsN = widget.n;
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
    var title = book?.title ?? summary?.title ?? '';
    ref.listen(settingsProvider.select((s) => s.bookReadingMode), _modeChanged);

    Widget body;
    Widget? bar;
    var opened = false;
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
      } else if (ref.watch(settingsProvider.select((s) => s.bookReadingMode)) ==
          BookReadingMode.pages) {
        opened = true;
        // The chapter being read (it follows the pages across chapters).
        title = page.title.isEmpty ? title : page.title;
        body = BookPagesView(
          key: _pagesKey,
          book: book,
          n: widget.n,
          // The address follows the pages in place: the browser's history
          // keeps one entry for the reader, so Back leaves it.
          onChapter: (n) => Router.neglect(
            context,
            () => context.go(Routes.bookReader(widget.id, n)),
          ),
          onBack: _back,
        );
      } else {
        _stepsFor(book);
        // Read so the column is measured with each picture as tall as it
        // is drawn; the place is gone back to once they are.
        final sizes = ref.watch(bookPictureSizesProvider(widget.id));
        _sizes = sizes.hasValue || sizes.hasError
            ? sizes.value ?? const {}
            : null;
        if (!_opened && _sizes != null) {
          _opened = true;
          SchedulerBinding.instance.addPostFrameCallback((_) => _openPlace());
        }
        opened = true;
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
        if (!didPop) _backPressed();
      },
      child: Scaffold(
        backgroundColor: p.background,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TopBar(
              title: title,
              onBack: _backPressed,
              onSettings: !opened
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
    final styles = BookTextStyles.of(context, ref.watch(settingsProvider));
    final screen = MediaQuery.sizeOf(context).width;
    final margin = NamoSizes.pageMargin(screen);
    _column = (
      page,
      styles,
      math.min(screen - 2 * margin, NamoSizes.readingColumn),
    );
    final blocks = [
      for (final b in page.blocks) BookBlockView(block: b, styles: styles),
    ];
    return SafeArea(
      top: false,
      child: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: SingleChildScrollView(
          controller: _scroll,
          padding: EdgeInsets.fromLTRB(
            margin,
            scrollTopPadding,
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
                    child: Text(page.title, style: styles.title),
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

/// The reader's quiet top bar: Back, the title on one line (the book's in
/// Scroll mode, the chapter's in Pages mode), and the reading settings once
/// the page is open.
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
