import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../design/tokens.dart';
import '../design/typography.dart';
import 'reader_items.dart';

/// The reading itself: every item laid out at once in one scrolling column,
/// capped at [NamoSizes.readingColumn] wide and centred.
///
/// The whole reading is built at once (about 50 items), so every item has a
/// known position; revisit when a reading passes a few hundred verses.
class ReaderBody extends StatefulWidget {
  const ReaderBody({
    super.key,
    required this.items,
    required this.controller,
    required this.fontScale,
    required this.lineSpacing,
    required this.bookmarkedSections,
    required this.onToggleBookmark,
  });

  final List<ReaderItem> items;
  final ScrollController controller;
  final double fontScale;
  final double lineSpacing;

  /// The ids of this reading's bookmarked sections.
  final Set<String> bookmarkedSections;

  /// Called with a section id when its heading's bookmark button is pressed.
  final ValueChanged<String> onToggleBookmark;

  @override
  State<ReaderBody> createState() => ReaderBodyState();
}

class ReaderBodyState extends State<ReaderBody> {
  final _contentKey = GlobalKey();
  final List<GlobalKey> _itemKeys = [];

  ScrollController get controller => widget.controller;

  /// Where each item of [ReaderBody.items] sits, in scroll offsets: an item
  /// whose `top` is the scroll offset is at the top of the body. Empty until
  /// the current items have been laid out.
  List<({double top, double height})> extents() {
    final content = _contentKey.currentContext?.findRenderObject();
    if (content is! RenderBox || !content.hasSize) return const [];
    final out = <({double top, double height})>[];
    for (var i = 0; i < widget.items.length; i++) {
      final box = _itemKeys[i].currentContext?.findRenderObject();
      if (box is! RenderBox || !box.hasSize || !box.attached) return const [];
      final top = box.localToGlobal(Offset.zero, ancestor: content).dy;
      out.add((top: top, height: box.size.height));
    }
    return out;
  }

  /// The scroll offset that puts [sectionId]'s heading at the top; 0 for a
  /// section that is not in the reading or before the first layout.
  double offsetOfSection(String sectionId) {
    final index = widget.items.indexWhere(
      (i) => i is HeadingItem && i.sectionId == sectionId,
    );
    if (index < 0) return 0;
    final ex = extents();
    return ex.isEmpty ? 0 : ex[index].top;
  }

  Widget _item(int index) {
    final item = widget.items[index];
    final child = switch (item) {
      HeadingItem() => _HeadingView(
        key: ValueKey('heading-${item.sectionId}'),
        item: item,
        fontScale: widget.fontScale,
        bookmarked: widget.bookmarkedSections.contains(item.sectionId),
        onToggleBookmark: () => widget.onToggleBookmark(item.sectionId),
      ),
      VerseTextItem() => _VerseView(
        key: ValueKey('verse-${item.verseId}-${item.language.code}'),
        item: item,
        fontScale: widget.fontScale,
        lineSpacing: widget.lineSpacing,
      ),
    };
    return KeyedSubtree(key: _itemKeys[index], child: child);
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    while (_itemKeys.length < items.length) {
      _itemKeys.add(GlobalKey());
    }
    final lastHeading = items.lastIndexWhere((i) => i is HeadingItem);
    final split = lastHeading < 0 ? items.length : lastHeading;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          controller: widget.controller,
          child: KeyedSubtree(
            key: _contentKey,
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: NamoSizes.readingColumn,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < split; i++) _item(i),
                      // The last section is at least a screen tall, so its
                      // heading can also be brought to the top.
                      if (split < items.length)
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (var i = split; i < items.length; i++)
                                _item(i),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HeadingView extends StatelessWidget {
  const _HeadingView({
    super.key,
    required this.item,
    required this.fontScale,
    required this.bookmarked,
    required this.onToggleBookmark,
  });

  final HeadingItem item;
  final double fontScale;
  final bool bookmarked;
  final VoidCallback onToggleBookmark;

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    final section = item.section;
    // The bookmark button is 48 high; the heading's first line is centred on
    // it, whatever the text size, and the rest wraps beneath.
    final firstLine = MediaQuery.textScalerOf(context)
        .scale(20 * fontScale * 1.4);
    final inset = firstLine >= NamoSizes.touchTarget
        ? 0.0
        : (NamoSizes.touchTarget - firstLine) / 2;
    return Padding(
      padding: const EdgeInsets.only(top: 28, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Padding(
                    padding: EdgeInsets.only(top: inset),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '${section.number}',
                          softWrap: true,
                          style: namoText(
                            NamoFonts.english,
                            size: 18 * fontScale,
                            color: p.heading,
                            weight: 600,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            section.heading,
                            softWrap: true,
                            style: namoText(
                              NamoFonts.sinhala,
                              size: 20 * fontScale,
                              color: p.heading,
                              weight: 600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: bookmarked
                    ? 'Remove bookmark'
                    : 'Bookmark this section',
                constraints: const BoxConstraints(
                  minWidth: NamoSizes.touchTarget,
                  minHeight: NamoSizes.touchTarget,
                ),
                icon: Icon(
                  Symbols.bookmark_rounded,
                  fill: bookmarked ? 1 : 0,
                  weight: 300,
                  color: bookmarked ? p.accent : p.textQuiet,
                ),
                onPressed: onToggleBookmark,
              ),
            ],
          ),
          for (final note in item.notes)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                note,
                softWrap: true,
                style: namoText(
                  NamoFonts.english,
                  size: 14 * fontScale,
                  color: p.textQuiet,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _VerseView extends StatelessWidget {
  const _VerseView({
    super.key,
    required this.item,
    required this.fontScale,
    required this.lineSpacing,
  });

  final VerseTextItem item;
  final double fontScale;
  final double lineSpacing;

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        item.text,
        softWrap: true,
        style: readingStyle(
          item.language,
          fontScale: fontScale,
          lineSpacing: lineSpacing,
          color: item.secondary ? p.textQuiet : p.text,
        ),
      ),
    );
  }
}
