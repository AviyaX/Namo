/// Reading a book page by page: the chapter cut into screen pages, turned
/// with the curl, the page arrows and count below.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../design/tokens.dart';
import '../design/typography.dart';
import '../design/widgets/buttons.dart';
import '../design/widgets/floating_bar.dart';
import '../settings/settings.dart';
import 'book_blocks.dart';
import 'book_model.dart';
import 'book_places.dart';
import 'book_widgets.dart';
import 'books_repository.dart';
import 'curl/page_curl.dart';
import 'pagination/book_paginator.dart';
import 'pagination/chapter_stream.dart';
import 'pagination/screen_page_view.dart';

/// A book's place is saved once the page has been still this long (in
/// either reading mode).
const bookPlaceSaveDelay = Duration(milliseconds: 400);

const _nextPage = CustomSemanticsAction(label: 'Next page');
const _previousPage = CustomSemanticsAction(label: 'Previous page');

/// The width and height of a PNG from its header; null for anything else.
Size? pngSize(ByteData data) {
  const signature = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
  if (data.lengthInBytes < 24) return null;
  for (var i = 0; i < signature.length; i++) {
    if (data.getUint8(i) != signature[i]) return null;
  }
  final width = data.getUint32(16), height = data.getUint32(20);
  if (width == 0 || height == 0) return null;
  return Size(width.toDouble(), height.toDouble());
}

/// The size in pixels of each bundled picture in a book, read from the
/// pictures' headers, so a page is cut with each picture as tall as it is
/// drawn. A picture that cannot be read is left out (it is then taken as
/// 4:3).
final bookPictureSizesProvider = FutureProvider.autoDispose
    .family<Map<String, Size>, String>((ref, id) async {
      final book = await ref.watch(bookProvider(id).future);
      final sizes = <String, Size>{};
      for (final page in book.pages) {
        for (final block in page.blocks) {
          final asset = block is BookImage ? block.asset : null;
          if (asset == null || sizes.containsKey(asset)) continue;
          try {
            final size = pngSize(await rootBundle.load(asset));
            if (size != null) sizes[asset] = size;
          } catch (_) {
            // Missing from the bundle: the reader names it instead.
          }
        }
      }
      return sizes;
    });

/// Turns a page forward (true) or back.
class _TurnIntent extends Intent {
  const _TurnIntent({required this.forward});
  final bool forward;
}

/// The book read page by page from reading page [n]: the page (a sheet in
/// the reading column on a wide window, the whole width on a phone) turned
/// by dragging or tapping its sides, by the arrows below, by the arrow and
/// Page Up / Page Down keys, or by a screen reader's Next page / Previous
/// page actions.
///
/// Turning carries on across a chapter's end; [onChapter] is then told the
/// reading page now shown. The place (the reading page and the first
/// passage on the page) is saved once a page has been still a moment.
/// [onBack] leaves the reader, after the place is saved.
class BookPagesView extends ConsumerStatefulWidget {
  const BookPagesView({
    super.key,
    required this.book,
    required this.n,
    required this.onChapter,
    required this.onBack,
  });

  final Book book;
  final int n;
  final ValueChanged<int> onChapter;
  final VoidCallback onBack;

  @override
  ConsumerState<BookPagesView> createState() => BookPagesViewState();
}

class BookPagesViewState extends ConsumerState<BookPagesView> {
  final _curl = PageCurlController();
  late final BookPlacesController _places;

  ChapterStream? _stream;

  /// What the pages were cut for; a change re-cuts them.
  Object? _cutFor;
  BookTextStyles? _cutStyles;
  PageBox? _cutBox;

  /// The page shown when the pages were last re-cut, with the styles and
  /// box it was cut for: it stays on screen, drawn as it was cut, until the
  /// page holding its passage is cut afresh.
  (ScreenPage, BookTextStyles, PageBox)? _held;

  /// The way (1 next, -1 previous) an arrow was refused while the page was
  /// still being cut.
  int _waitingFor = 0;

  /// Set once the opening page has been noted as the place.
  bool _noted = false;

  /// Whether the shown page is not saved as the place yet.
  bool _dirty = false;
  Timer? _saveTimer;

  @override
  void initState() {
    super.initState();
    _places = ref.read(bookPlacesProvider.notifier);
    _curl.addListener(_changed);
  }

  @override
  void didUpdateWidget(BookPagesView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final stream = _stream;
    // A reading page asked for from outside (not one the pages turned to).
    if (stream != null && widget.book.firstReadingFrom(widget.n) != stream.n) {
      _waitingFor = 0;
      stream.jumpTo(widget.n, null);
      _markMoved();
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    // Providers cannot change while the tree is being torn down, so the last
    // place is handed over once this frame is done.
    final stream = _stream;
    final start = stream?.current?.start;
    if (_dirty && stream != null && start != null) {
      final places = _places, id = widget.book.id, n = stream.n;
      final key = widget.book.page(n)?.key;
      SchedulerBinding.instance.addPostFrameCallback(
        (_) => places.remember(id, n: n, key: key, offset: 0, spot: start),
      );
    }
    stream?.dispose();
    _curl.dispose();
    super.dispose();
  }

  /// The first passage on the page shown; null until it is cut.
  BookSpot? get spot => _stream?.current?.start;

  /// Saves the place now and leaves through [BookPagesView.onBack].
  void back() {
    saveNow();
    widget.onBack();
  }

  /// Shows the first page of the chapter being read.
  void backToBeginning() {
    final stream = _stream;
    if (stream == null) return;
    _waitingFor = 0;
    stream.jumpTo(stream.n, null);
    _markMoved();
  }

  // ---- place --------------------------------------------------------------

  void _markMoved() {
    _dirty = true;
    _saveTimer?.cancel();
    _saveTimer = Timer(bookPlaceSaveDelay, saveNow);
  }

  /// Saves the shown page as the place, if it is not saved yet.
  void saveNow() {
    _saveTimer?.cancel();
    _saveTimer = null;
    final stream = _stream;
    final start = stream?.current?.start;
    if (!_dirty || stream == null || start == null) return;
    _dirty = false;
    _places.remember(
      widget.book.id,
      n: stream.n,
      key: widget.book.page(stream.n)?.key,
      offset: 0,
      spot: start,
    );
  }

  /// Where chapter [n] opens: the saved spot when the place is in it (a
  /// place saved before spots were is found from its scroll offset), else
  /// null (its first page).
  BookSpot? _openingSpot(int n, BookTextStyles styles, double screen) {
    final book = widget.book;
    final place = ref.read(bookPlacesProvider).of(book.id);
    if (place == null || place.pageIn(book) != n) return null;
    final spot = place.spot;
    if (spot != null) return spot;
    final page = book.page(n);
    if (page == null) return null;
    final width = math.min(
      screen - 2 * NamoSizes.pageMargin(screen),
      NamoSizes.readingColumn,
    );
    return spotAtOffset(
      page,
      styles,
      width,
      place.offset,
      imageSize: _imageSize,
    );
  }

  Map<String, Size> _sizes = const {};
  Size? _imageSize(String asset) => _sizes[asset];

  // ---- turning ------------------------------------------------------------

  void _changed() {
    final stream = _stream;
    if (stream == null || !mounted) return;
    if (!stream.waiting) _waitingFor = 0;
    if (!_noted && stream.current != null) {
      _noted = true;
      _markMoved();
    }
    setState(() {});
  }

  /// The pages moved one way: announces the page and saves it in a moment.
  /// Into a new chapter, the place is saved at once and then the screen is
  /// told: a reader that is built afresh for it (the mode was switched
  /// since it opened) opens at this page.
  void _turned(int chapterBefore) {
    final stream = _stream!;
    if (stream.n != chapterBefore) {
      _dirty = true;
      saveNow();
      widget.onChapter(stream.n);
    } else {
      _markMoved();
    }
    final count = stream.count;
    final page = 'Page ${stream.index + 1}';
    SemanticsService.sendAnnouncement(
      View.of(context),
      count == null ? page : '$page of $count',
      Directionality.of(context),
    );
  }

  void _turnedForward() {
    final stream = _stream!;
    final before = stream.n;
    if (stream.next()) _turned(before);
  }

  void _turnedBack() {
    final stream = _stream!;
    final before = stream.n;
    if (stream.previous()) _turned(before);
  }

  /// Turns with the curl when the page that way is cut; otherwise asks the
  /// stream, which waits for it (or refuses at the book's end).
  void _turn({required bool forward}) {
    final stream = _stream;
    if (stream == null || _curl.turning) return;
    final ready = forward ? stream.peekNext : stream.peekPrevious;
    if (ready != null) {
      forward ? _curl.turnForward() : _curl.turnBack();
      return;
    }
    final before = stream.n;
    if (forward ? stream.next() : stream.previous()) {
      _turned(before);
    } else if (stream.waiting) {
      setState(() => _waitingFor = forward ? 1 : -1);
    }
  }

  /// No page that way: the book's first or last page is shown.
  bool _atEnd({required bool forward}) {
    final stream = _stream;
    if (stream == null || stream.current == null) return true;
    final book = widget.book;
    if (!forward) {
      return stream.index == 0 && book.previousReading(stream.n) == null;
    }
    final count = stream.count;
    return count != null &&
        stream.index == count - 1 &&
        book.nextReading(stream.n) == null;
  }

  // ---- build --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final sizes = ref.watch(bookPictureSizesProvider(widget.book.id));
    // Read before cutting so each picture is cut as tall as it is drawn.
    if (sizes.isLoading && !sizes.hasValue) return const BookLoading();
    _sizes = sizes.value ?? const {};
    final settings = ref.watch(settingsProvider);
    final styles = BookTextStyles.of(context, settings);
    final screen = MediaQuery.sizeOf(context).width;
    final sheet = screen >= NamoSizes.wideBreakpoint;

    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.arrowLeft): _TurnIntent(
          forward: false,
        ),
        SingleActivator(LogicalKeyboardKey.pageUp): _TurnIntent(forward: false),
        SingleActivator(LogicalKeyboardKey.arrowRight): _TurnIntent(
          forward: true,
        ),
        SingleActivator(LogicalKeyboardKey.pageDown): _TurnIntent(
          forward: true,
        ),
      },
      child: Actions(
        actions: {
          _TurnIntent: CallbackAction<_TurnIntent>(
            onInvoke: (intent) => _turn(forward: intent.forward),
          ),
        },
        child: Focus(
          autofocus: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: SafeArea(
                  top: false,
                  bottom: false,
                  child: LayoutBuilder(
                    builder: (context, area) => _pageArea(
                      context,
                      area.biggest,
                      styles,
                      sheet: sheet,
                      screen: screen,
                    ),
                  ),
                ),
              ),
              _bottomBar(context),
            ],
          ),
        ),
      ),
    );
  }

  /// Cuts the pages for [box] and [styles] (the first time, or again when
  /// either changed).
  void _cut(PageBox box, BookTextStyles styles, double screen) {
    final cutFor = (
      box,
      styles.prose,
      styles.heading,
      styles.title,
      styles.caption,
      styles.scaler,
      styles.direction,
    );
    if (cutFor == _cutFor) return;
    _cutFor = cutFor;
    final shown = _stream?.current;
    if (shown != null && !identical(shown, _held?.$1)) {
      _held = (shown, _cutStyles!, _cutBox!);
    }
    _cutStyles = styles;
    _cutBox = box;
    Iterable<ScreenPage> cut(BookPage page) =>
        paginate(page, styles, box, imageSize: _imageSize);
    final stream = _stream;
    if (stream != null) {
      stream.recut(cut);
      return;
    }
    final n = widget.book.firstReadingFrom(widget.n) ?? widget.n;
    _stream = ChapterStream(
      book: widget.book,
      n: n,
      spot: _openingSpot(n, styles, screen),
      cut: cut,
    )..addListener(_changed);
  }

  Widget _pageArea(
    BuildContext context,
    Size area,
    BookTextStyles styles, {
    required bool sheet,
    required double screen,
  }) {
    final margin = NamoSizes.pageMargin(screen);
    final column = math.max(
      0.0,
      math.min(area.width - 2 * margin, NamoSizes.readingColumn),
    );
    const top = scrollTopPadding, bottom = NamoSpace.sm;
    final height = math.max(0.0, area.height - top - bottom);
    final box = sheet
        ? PageBox(
            width: math.max(0, column - 2 * pageSheetPadding),
            height: math.max(0, height - 2 * pageSheetPadding),
          )
        : PageBox(width: column, height: height);
    if (box.width <= 0 || box.height <= 0) return const SizedBox.shrink();
    _cut(box, styles, screen);
    final stream = _stream!;
    final book = widget.book;

    Widget? page(ScreenPage? page, int? n) {
      final chapter = n == null ? null : book.page(n);
      if (page == null || chapter == null) return null;
      final held = _held;
      final old = held != null && identical(page, held.$1);
      Widget view = ScreenPageView(
        chapter: chapter,
        page: page,
        styles: old ? held.$2 : styles,
        sheet: sheet,
      );
      if (old) {
        // Cut for another text size or box: drawn as it was cut, clipped.
        final inset = sheet ? 2 * pageSheetPadding : 0.0;
        view = OverflowBox(
          alignment: Alignment.topCenter,
          minWidth: held.$3.width + inset,
          maxWidth: held.$3.width + inset,
          minHeight: held.$3.height + inset,
          maxHeight: held.$3.height + inset,
          child: view,
        );
      }
      // A sheet fills the curl; its shadow is drawn once, under the curl.
      if (sheet) return ClipRect(child: view);
      return Padding(
        padding: const EdgeInsets.fromLTRB(0, top, 0, bottom),
        child: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: box.width,
            height: box.height,
            child: ClipRect(child: view),
          ),
        ),
      );
    }

    final current = page(stream.current, stream.n);
    if (current == null) return const BookLoading();
    final curl = PageCurl(
      key: const ValueKey('book-page-curl'),
      current: current,
      next: page(stream.peekNext, stream.peekNextChapter),
      previous: page(stream.peekPrevious, stream.peekPreviousChapter),
      onTurnedForward: _turnedForward,
      onTurnedBack: _turnedBack,
      controller: _curl,
    );
    final canNext = !_atEnd(forward: true);
    final canPrevious = !_atEnd(forward: false);
    final turnable = Semantics(
      key: const ValueKey('book-page-area'),
      container: true,
      customSemanticsActions: {
        if (canNext) _nextPage: () => _turn(forward: true),
        if (canPrevious) _previousPage: () => _turn(forward: false),
      },
      child: curl,
    );
    if (!sheet) return turnable;
    final p = NamoPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, top, 0, bottom),
      child: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          key: const ValueKey('book-page-sheet'),
          width: column,
          height: height,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(NamoRadius.sm),
              boxShadow: p.floatShadow,
            ),
            child: turnable,
          ),
        ),
      ),
    );
  }

  Widget _bottomBar(BuildContext context) {
    final p = NamoPalette.of(context);
    final stream = _stream;
    final count = stream?.count;
    final index = stream?.index ?? 0;
    final shown = stream?.current != null;
    Widget arrow({required bool forward}) {
      final waiting = _waitingFor == (forward ? 1 : -1);
      return NamoIconButton(
        key: ValueKey(forward ? 'book-page-next' : 'book-page-prev'),
        icon: forward
            ? Symbols.chevron_right_rounded
            : Symbols.chevron_left_rounded,
        tooltip: forward ? 'Next page' : 'Previous page',
        onPressed: _atEnd(forward: forward)
            ? null
            : waiting
            ? () {}
            : () => _turn(forward: forward),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(NamoSpace.lg),
        child: FloatingBar(
          child: Row(
            children: [
              _Waiting(
                waiting: _waitingFor == -1,
                child: arrow(forward: false),
              ),
              Expanded(
                // As tall as the count: the bar keeps to its own height.
                child: Center(
                  heightFactor: 1,
                  child: Text(
                    !shown
                        ? ''
                        : count == null
                        ? '${index + 1}'
                        : '${index + 1} of $count',
                    key: const ValueKey('book-page-count'),
                    style: NamoType.caption(p.textSecondary),
                  ),
                ),
              ),
              _Waiting(waiting: _waitingFor == 1, child: arrow(forward: true)),
            ],
          ),
        ),
      ),
    );
  }
}

/// An arrow that, while its page is still being cut, shows a small progress
/// mark over itself instead of its chevron.
class _Waiting extends StatelessWidget {
  const _Waiting({required this.waiting, required this.child});

  final bool waiting;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!waiting) return child;
    return Stack(
      alignment: Alignment.center,
      children: [
        Opacity(opacity: 0, child: child),
        const IgnorePointer(child: BookLoading.small()),
      ],
    );
  }
}
