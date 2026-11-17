/// The pieces the books' pages share: the loading and failure states, a
/// cover, the row chevron and a page's row.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../design/tokens.dart';
import '../design/typography.dart';
import '../design/widgets/empty_state.dart';
import '../design/widgets/list_row.dart';
import '../router.dart';
import '../tipitaka/tipitaka_labels.dart';
import 'book_model.dart';

/// A quiet progress mark while a book loads (the Library's own).
class BookLoading extends StatelessWidget {
  const BookLoading({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(NamoSpace.xl),
      child: SizedBox.square(
        dimension: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: NamoPalette.of(context).sage,
        ),
      ),
    ),
  );
}

/// A book failed to load: a plain message and a way to try again.
class BookLoadError extends ConsumerWidget {
  const BookLoadError({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) => EmptyState(
    icon: Symbols.error_outline_rounded,
    title: 'The book could not be opened.',
    actionLabel: 'Try again',
    onAction: onRetry,
  );
}

/// A book's cover at 2 : 3, rounded, with a hairline edge. A cover that
/// cannot be drawn shows the title's first letter on the quiet ground.
class BookCover extends StatelessWidget {
  const BookCover({
    super.key,
    required this.asset,
    required this.title,
    this.width,
  });

  final String asset;
  final String title;

  /// Left null, the cover fills the width it is given.
  final double? width;

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    const radius = BorderRadius.all(Radius.circular(NamoRadius.sm));
    final cover = AspectRatio(
      aspectRatio: 2 / 3,
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(color: p.border),
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: Image.asset(
            asset,
            fit: BoxFit.cover,
            excludeFromSemantics: true,
            errorBuilder: (context, _, _) => ColoredBox(
              color: p.backgroundAlt,
              child: Center(
                child: Text(
                  title.isEmpty ? '' : String.fromCharCode(title.runes.first),
                  style: NamoType.sectionTitleSinhala(p.gold),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return width == null ? cover : SizedBox(width: width, child: cover);
  }
}

/// The chevron at the end of a row that opens something.
Widget bookChevron(BuildContext context) => Icon(
  Symbols.chevron_right_rounded,
  size: NamoSizes.iconSmall,
  weight: 300,
  color: NamoPalette.of(context).textSecondary,
);

/// A page of [book] as a row. A page with children shows how many and opens
/// their list; a page without opens the reader. [own] is a parent's own
/// text, at the top of its list: it opens the reader at the page.
class BookPageRow extends StatelessWidget {
  const BookPageRow({
    super.key,
    required this.book,
    required this.page,
    this.own = false,
  });

  final Book book;
  final BookPage page;
  final bool own;

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    final n = page.n;
    final hasChildren = !own && book.childrenOf(n).isNotEmpty;
    final texts = hasChildren ? book.readingPagesUnder(n) : 0;
    final chevron = bookChevron(context);
    return ListRow(
      key: ValueKey(own ? 'book-row-own-$n' : 'book-row-$n'),
      title: page.title,
      titleFamily: NamoFonts.sinhala,
      // The count is spoken as the Tripitaka's rows speak theirs.
      semanticLabel: hasChildren ? '${page.title}, ${textsLabel(texts)}' : null,
      trailing: !hasChildren
          ? chevron
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$texts',
                  style: NamoType.caption(p.textSecondary),
                ),
                const SizedBox(width: NamoSpace.xs),
                chevron,
              ],
            ),
      onTap: () {
        if (!hasChildren) {
          final target = book.firstReadingFrom(n);
          if (target != null) context.go(Routes.bookReader(book.id, target));
        } else {
          context.go(Routes.bookContents(book.id, n));
        }
      },
    );
  }
}
