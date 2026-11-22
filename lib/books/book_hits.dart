import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../design/tokens.dart';
import '../design/typography.dart';
import '../design/widgets/list_row.dart';
import '../design/widgets/page_header.dart';
import '../router.dart';
import 'book_model.dart';

/// The books that match a search: a "Books" heading and a row per book, each
/// opening the book's page. Builds nothing when there are none.
class BookHits extends StatelessWidget {
  const BookHits({super.key, required this.books});

  final List<BookSummary> books;

  @override
  Widget build(BuildContext context) {
    if (books.isEmpty) return const SizedBox.shrink();
    final p = NamoPalette.of(context);
    return Column(
      key: const ValueKey('book-hits'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: NamoSpace.lg),
          child: Overline('Books', header: true),
        ),
        const SizedBox(height: NamoSpace.sm),
        for (final b in books)
          ListRow(
            key: ValueKey('book-hit-${b.id}'),
            title: b.title,
            titleFamily: NamoFonts.sinhala,
            subtitle: b.subtitle,
            onTap: () => context.go(Routes.book(b.id)),
            trailing: Icon(
              Symbols.chevron_right_rounded,
              size: NamoSizes.iconSmall,
              weight: 300,
              color: p.textSecondary,
            ),
          ),
        const SizedBox(height: NamoSpace.lg),
      ],
    );
  }
}
