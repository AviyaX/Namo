import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../design/tokens.dart';
import '../design/widgets/buttons.dart';
import '../design/widgets/namo_page.dart';
import '../design/widgets/not_found.dart';
import '../design/widgets/page_header.dart';
import '../router.dart';
import 'book_widgets.dart';
import 'books_repository.dart';

/// The pages under page [n] of a book, as rows under its title. A page with
/// text of its own has a first row that opens that text.
///
/// Back goes to the parent's list, or to the book's page from a chapter.
/// A book or page that is not there, or a page with nothing under it, shows
/// the not-found page.
class BookContentsScreen extends ConsumerStatefulWidget {
  const BookContentsScreen({super.key, required this.id, required this.n});

  final String id;
  final int n;

  @override
  ConsumerState<BookContentsScreen> createState() =>
      _BookContentsScreenState();
}

class _BookContentsScreenState extends ConsumerState<BookContentsScreen> {
  void _back() {
    final parent = ref.read(bookProvider(widget.id)).value?.parentOf(widget.n);
    context.go(
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

  @override
  Widget build(BuildContext context) {
    final index = ref.watch(booksIndexProvider);
    if (index.hasValue && index.value!.byId(widget.id) == null) {
      return const NotFoundScreen();
    }
    final loaded = ref.watch(bookProvider(widget.id));
    final book = loaded.value;

    final List<Widget> body;
    if (book != null) {
      final page = book.page(widget.n);
      final children = book.childrenOf(widget.n);
      if (page == null || children.isEmpty) return const NotFoundScreen();
      body = [
        PageHeader(title: page.title),
        const SizedBox(height: NamoSpace.lg),
        if (page.hasText) BookPageRow(book: book, page: page, own: true),
        for (final child in children) BookPageRow(book: book, page: child),
      ];
    } else if ((loaded.hasError || index.hasError) && !loaded.isLoading) {
      body = [BookLoadError(onRetry: _retry)];
    } else {
      body = const [BookLoading()];
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
          const SizedBox(height: NamoSpace.xs),
          ...body,
        ],
      ),
    );
  }
}
