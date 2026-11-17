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

/// The Library's shelf of books: a heading, then the covers in a grid, each
/// opening its book's page, and the space below it. Nothing shows while the
/// index loads, or when there are no books.
class BooksPart extends ConsumerWidget {
  const BooksPart({super.key = const ValueKey('books-shelf')});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = NamoPalette.of(context);
    final index = ref.watch(booksIndexProvider);
    final books = index.value?.books;
    if (books == null && !index.hasError) return const SizedBox.shrink();
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
            books == null
                ? 'The books could not be opened.'
                : 'රේරුකානේ චන්දවිමල හිමියන්ගේ පොත්',
            // The caption's family is the Sinhala one.
            style: NamoType.caption(p.textSecondary),
          ),
        ),
        if (books != null) ...[
          const SizedBox(height: NamoSpace.sm),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: NamoSpace.sm),
            child: LayoutBuilder(
              builder: (context, box) {
                // Four across when the Library's column is 600 wide or more.
                final column = box.maxWidth + 2 * NamoSpace.sm;
                final columns = column >= 600 ? 4 : 3;
                final width = (box.maxWidth / columns).floorToDouble();
                return Wrap(
                  children: [
                    for (final b in books)
                      SizedBox(width: width, child: _BookCard(book: b)),
                  ],
                );
              },
            ),
          ),
        ],
        const SizedBox(height: NamoSpace.xl),
      ],
    );
  }
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
      child: Padding(
        padding: const EdgeInsets.all(NamoSpace.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
