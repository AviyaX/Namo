import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../design/tokens.dart';
import '../design/typography.dart';
import '../design/widgets/page_header.dart';
import '../design/widgets/pressable.dart';
import '../router.dart';
import 'book_model.dart';
import 'book_widgets.dart';
import 'books_repository.dart';

/// The Library's shelf of books: a heading, then the covers in one sideways
/// row, each opening its book's page, and the space below it. While the
/// index loads the heading shows over an empty row as tall as the covers',
/// so the topics below do not move when they arrive. Nothing shows when
/// there are no books.
class BooksPart extends ConsumerWidget {
  const BooksPart({super.key = const ValueKey('books-shelf')});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = NamoPalette.of(context);
    final index = ref.watch(booksIndexProvider);
    final books = index.value?.books;
    final loading = books == null && !index.hasError;
    if (books != null && books.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: NamoSpace.lg),
          child: Overline('පොත්', header: true),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: NamoSpace.lg),
          child: Text(
            books == null && !loading
                ? 'The books could not be opened.'
                : 'රේරුකානේ චන්දවිමල හිමියන්ගේ පොත්',
            // The caption's family is the Sinhala one.
            style: NamoType.caption(p.textSecondary),
          ),
        ),
        if (loading) ...[
          const SizedBox(height: NamoSpace.sm),
          SizedBox(
            key: const ValueKey('books-shelf-loading'),
            height: _cardHeight(context),
          ),
        ],
        if (books != null) ...[
          const SizedBox(height: NamoSpace.sm),
          SizedBox(
            height: _cardHeight(context),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              // The first cover lines up with the heading above it; the
              // last clears the edge by the same.
              padding: const EdgeInsets.symmetric(horizontal: NamoSpace.lg),
              itemCount: books.length,
              separatorBuilder: (_, _) => const SizedBox(width: NamoSpace.md),
              itemBuilder: (context, i) => _BookCard(book: books[i]),
            ),
          ),
        ],
        const SizedBox(height: NamoSpace.xl),
      ],
    );
  }
}

/// A card's width; the cover is 2 : 3 within it.
const _cardWidth = 112.0;

/// The row's height: the cover, the gap and two lines of title at the
/// device's text size, with a little room for Sinhala marks.
double _cardHeight(BuildContext context) {
  final title = NamoType.readingTitle(NamoPalette.of(context).text);
  final line = MediaQuery.textScalerOf(context).scale(title.fontSize!) *
      (title.height ?? 1.4);
  return _cardWidth * 3 / 2 + NamoSpace.xs + 2 * line + NamoSpace.xs;
}

class _BookCard extends StatelessWidget {
  const _BookCard({required this.book});

  final BookSummary book;

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    return Pressable(
      key: ValueKey('book-${book.id}'),
      semanticLabel: '${book.title}, book',
      excludeChildSemantics: true,
      onTap: () => context.go(Routes.book(book.id)),
      child: SizedBox(
        width: _cardWidth,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            BookCover(asset: book.cover, title: book.title),
            const SizedBox(height: NamoSpace.xs),
            Text(
              book.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: NamoType.readingTitle(p.text),
            ),
          ],
        ),
      ),
    );
  }
}
