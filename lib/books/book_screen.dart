import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../design/tokens.dart';
import '../design/typography.dart';
import '../design/widgets/buttons.dart';
import '../design/widgets/namo_page.dart';
import '../design/widgets/not_found.dart';
import '../design/widgets/page_header.dart';
import '../router.dart';
import 'book_model.dart';
import 'book_places.dart';
import 'book_widgets.dart';
import 'books_repository.dart';

/// A book's page: its cover and title, a button that opens the reader where
/// the person left off (or at the start), and the book's chapters as rows.
///
/// Back goes to the Library tab (the Tripitaka & Books page). An id that is
/// not on the shelf shows the not-found page.
class BookScreen extends ConsumerStatefulWidget {
  const BookScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<BookScreen> createState() => _BookScreenState();
}

class _BookScreenState extends ConsumerState<BookScreen> {
  void _back() => context.go(Routes.tipitaka);

  void _retry() {
    if (ref.read(booksIndexProvider).hasError) {
      ref.invalidate(booksIndexProvider);
    }
    ref.invalidate(bookProvider(widget.id));
  }

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(booksIndexProvider);
    final summary = index.value?.byId(widget.id);
    if (index.hasValue && summary == null) return const NotFoundScreen();
    final loaded = ref.watch(bookProvider(widget.id));
    final book = loaded.value;

    final List<Widget> body;
    if (book != null && summary != null) {
      body = _book(context, summary, book);
    } else if ((loaded.hasError || index.hasError) && !loaded.isLoading) {
      body = [BookLoadError(onRetry: _retry)];
    } else {
      body = [
        // The cover and title from the shelf, so the page is useful at once.
        if (summary != null) ..._head(context, summary),
        const BookLoading(),
      ];
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: NamoPage(
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: NamoIconButton(
              icon: Symbols.arrow_back_rounded,
              tooltip: 'Back',
              onPressed: _back,
            ),
          ),
          const SizedBox(height: NamoSpace.sm),
          ...body,
        ],
      ),
    );
  }

  List<Widget> _head(BuildContext context, BookSummary summary) {
    final p = NamoPalette.of(context);
    return [
      Center(
        child: BookCover(asset: summary.cover, title: summary.title, width: 160),
      ),
      const SizedBox(height: NamoSpace.lg),
      Semantics(
        header: true,
        child: Text(
          summary.title,
          textAlign: TextAlign.center,
          style: NamoType.sectionTitleSinhala(p.text),
        ),
      ),
    ];
  }

  List<Widget> _book(BuildContext context, BookSummary summary, Book book) {
    final p = NamoPalette.of(context);
    final caption = NamoType.caption(p.textSecondary);
    final place = ref.watch(bookPlacesProvider.select((s) => s.of(book.id)));
    // The saved page is found by its key first: a re-fetched book can have
    // numbered its pages differently.
    final saved = place?.pageIn(book);
    final placed = saved != null && book.page(saved)?.hasText == true;
    final target = placed ? saved : book.firstReadingFrom(1);
    final chapters = summary.chapters;
    return [
      ..._head(context, summary),
      if (summary.subtitle case final subtitle?) ...[
        const SizedBox(height: NamoSpace.xs),
        Text(subtitle, textAlign: TextAlign.center, style: caption),
      ],
      const SizedBox(height: NamoSpace.xs),
      Text(
        '$chapters ${chapters == 1 ? 'chapter' : 'chapters'}',
        textAlign: TextAlign.center,
        style: caption,
      ),
      const SizedBox(height: NamoSpace.lg),
      Center(
        child: PrimaryButton(
          key: const ValueKey('book-continue'),
          label: placed ? 'Continue reading' : 'Start reading',
          onPressed: target == null
              ? null
              : () => context.go(Routes.bookReader(book.id, target)),
        ),
      ),
      const SizedBox(height: NamoSpace.xl),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: NamoSpace.lg),
        child: Overline('Contents', header: true),
      ),
      const SizedBox(height: NamoSpace.sm),
      for (final page in book.topLevel) BookPageRow(book: book, page: page),
      const SizedBox(height: NamoSpace.xl),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: NamoSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Text: pitaka.lk', style: caption),
            Text(
              'Published by the Sri Chandawimala Dhamma Treatises '
              'Preservation Board',
              style: caption,
            ),
          ],
        ),
      ),
    ];
  }
}
