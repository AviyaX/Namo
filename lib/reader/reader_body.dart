import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../audio/chant_timing.dart' show ChantPlace;
import '../design/tokens.dart';
import '../design/typography.dart';
import '../settings/reading_language.dart';
import '../design/widgets/buttons.dart';
import 'reader_items.dart';

/// The reading itself: every item laid out at once in one scrolling column,
/// capped at [NamoSizes.readingColumn] wide and centred.
///
/// An ordinary reading is built at once (about 50 items), so every item has
/// a known position. A phrased reading (a pirith, up to about 900 phrase
/// rows) is built on demand instead: only the blocks near the screen exist,
/// and the position of the others is estimated from those that do.
class ReaderBody extends StatefulWidget {
  const ReaderBody({
    super.key,
    required this.items,
    required this.controller,
    required this.fontScale,
    required this.lineSpacing,
    required this.bookmarkedSections,
    required this.onToggleBookmark,
    this.chantPlace,
    this.onTapBlock,
  });

  final List<ReaderItem> items;
  final ScrollController controller;
  final double fontScale;
  final double lineSpacing;

  /// The ids of this reading's bookmarked sections.
  final Set<String> bookmarkedSections;

  /// Called with a section id when its heading's bookmark button is pressed.
  final ValueChanged<String> onToggleBookmark;

  /// The block and phrase being chanted; null for a reading without chanting.
  final ValueListenable<ChantPlace?>? chantPlace;

  /// Called with a block's index when it is tapped. A block has no tap at all
  /// (and no tap semantics) while this is null.
  final ValueChanged<int>? onTapBlock;

  @override
  State<ReaderBody> createState() => ReaderBodyState();
}

class ReaderBodyState extends State<ReaderBody> {
  final _contentKey = GlobalKey();
  final _viewportKey = GlobalKey();
  final List<GlobalKey> _itemKeys = [];

  ScrollController get controller => widget.controller;

  /// Whether the last item exists, so the scroll extent is the real one.
  /// Always true for a reading that is built at once.
  bool get endBuilt =>
      !_lazy ||
      (_itemKeys.length >= widget.items.length &&
          _itemKeys[widget.items.length - 1].currentContext != null);

  bool get _lazy => widget.items.any((i) => i is PhraseBlockItem);

  /// [box]'s top in scroll coordinates, or null while it has no layout.
  double? _topOf(RenderObject? box) {
    if (box is! RenderBox || !box.hasSize || !box.attached) return null;
    if (_lazy) {
      // The list's own record of where it laid the child, which (unlike a
      // position found through the paint transform) does not depend on
      // whether the scroll offset has been laid out yet. The list starts at
      // scroll offset 0.
      RenderObject? r = box;
      while (r != null && r.parentData is! SliverMultiBoxAdaptorParentData) {
        r = r.parent;
      }
      final offset =
          (r?.parentData as SliverMultiBoxAdaptorParentData?)?.layoutOffset;
      if (offset == null) return null;
      final inside = box.localToGlobal(Offset.zero, ancestor: r as RenderBox);
      return offset + inside.dy;
    }
    final content = _contentKey.currentContext?.findRenderObject();
    if (content is! RenderBox || !content.hasSize) return null;
    return box.localToGlobal(Offset.zero, ancestor: content).dy;
  }

  /// The top of the line phrase [phrase] of block [block] (both zero-based)
  /// starts on, in the block's first shown passage, in scroll coordinates;
  /// the top of the block when the phrase has no text there. Null before
  /// layout, and while the block is not built.
  double? offsetOfPhrase(int block, int phrase) {
    final index = widget.items.indexWhere(
      (i) => i is PhraseBlockItem && i.index == block,
    );
    if (index < 0 || index >= _itemKeys.length) return null;
    final context = _itemKeys[index].currentContext;
    if (context == null) return null;
    final item = widget.items[index] as PhraseBlockItem;
    final blockTop = _topOf(context.findRenderObject());
    final language = _firstShownLanguage(item);
    if (language == null || phrase < 0 || phrase >= item.phrases.length) {
      return blockTop;
    }
    final ranges = _passageRanges(item, language);
    final range = ranges[phrase];
    if (range == null) return blockTop;
    final key = ValueKey('passage-${item.verseId}-${language.name}');
    RenderParagraph? paragraph;
    void visit(Element e) {
      if (paragraph != null) return;
      final r = e.renderObject;
      if (r is RenderParagraph) {
        paragraph = r;
        return;
      }
      e.visitChildren(visit);
    }

    void find(Element e) {
      if (paragraph != null) return;
      if (e.widget.key == key) {
        visit(e);
        return;
      }
      e.visitChildren(find);
    }

    (context as Element).visitChildren(find);
    final box = paragraph;
    if (box == null || !box.hasSize || !box.attached) return blockTop;
    final top = _topOf(box);
    if (top == null) return blockTop;
    // The phrase's own range: its first box is on the line it starts on.
    final boxes = box.getBoxesForSelection(
      TextSelection(baseOffset: range.$1, extentOffset: range.$2),
    );
    if (boxes.isEmpty) return top;
    // The line's box top relative to the first line's, so the first line
    // is at the passage's own top whatever its leading.
    final first = box.getBoxesForSelection(
      TextSelection(
        baseOffset: 0,
        extentOffset: ranges.whereType<(int, int)>().first.$2,
      ),
    );
    final lineOne = first.isEmpty ? 0.0 : first.first.top;
    return top + boxes.first.top - lineOne;
  }

  /// The first of the block's chosen languages in which any phrase has text.
  static ReadingLanguage? _firstShownLanguage(PhraseBlockItem item) {
    for (final l in item.languages) {
      if (item.phrases.any((p) => p.text(l).isNotEmpty)) return l;
    }
    return null;
  }

  /// Where each item of [ReaderBody.items] sits, in scroll offsets: an item
  /// whose `top` is the scroll offset is at the top of the body. Empty until
  /// the current items have been laid out.
  List<({double top, double height})> extents() {
    if (_lazy) return _lazyExtents();
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

  /// The extents of a lazily built reading: exact for the items that are
  /// built, and for the rest the average height of those, laid out before
  /// and after them. Empty while nothing is laid out.
  List<({double top, double height})> _lazyExtents() {
    final n = widget.items.length;
    if (n == 0 || _itemKeys.length < n) return const [];
    final tops = List<double?>.filled(n, null);
    final heights = List<double>.filled(n, 0);
    var first = -1, last = -1, built = 0;
    var sum = 0.0;
    for (var i = 0; i < n; i++) {
      final box = _itemKeys[i].currentContext?.findRenderObject();
      final top = _topOf(box);
      if (top == null) continue;
      tops[i] = top;
      heights[i] = (box as RenderBox).size.height;
      sum += heights[i];
      built++;
      if (first < 0) first = i;
      last = i;
    }
    if (first < 0) return const [];
    final average = sum / built;
    final out = List<({double top, double height})>.filled(n, (
      top: 0,
      height: 0,
    ));
    for (var i = first; i <= last; i++) {
      out[i] = (
        top: tops[i] ?? out[i - 1].top + out[i - 1].height,
        height: heights[i],
      );
    }
    for (var i = first - 1; i >= 0; i--) {
      out[i] = (top: out[i + 1].top - average, height: average);
    }
    for (var i = last + 1; i < n; i++) {
      out[i] = (top: out[i - 1].top + out[i - 1].height, height: average);
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

  /// The room above item [index]: 32 above a heading that is not the first,
  /// 12 between the two languages of one verse, 24 between verses, 16
  /// between a heading and its first verse.
  double _gapAbove(int index) {
    final item = widget.items[index];
    final before = index == 0 ? null : widget.items[index - 1];
    return switch (item) {
      HeadingItem() => before == null ? NamoSpace.xl : NamoSpace.xxl,
      VerseTextItem() => switch (before) {
        VerseTextItem(:final verseId) when verseId == item.verseId =>
          NamoSpace.md,
        VerseTextItem() => NamoSpace.xl,
        _ => NamoSpace.lg,
      },
      PhraseBlockItem() =>
        before is PhraseBlockItem ? NamoSpace.xl : NamoSpace.lg,
    };
  }

  Widget _item(int index) {
    final item = widget.items[index];
    final gap = _gapAbove(index);
    final child = switch (item) {
      HeadingItem() => _HeadingView(
        key: ValueKey('heading-${item.sectionId}'),
        item: item,
        gap: gap,
        fontScale: widget.fontScale,
        bookmarked: widget.bookmarkedSections.contains(item.sectionId),
        onToggleBookmark: () => widget.onToggleBookmark(item.sectionId),
      ),
      PhraseBlockItem() => _PhraseBlockView(
        key: ValueKey('block-${item.verseId}'),
        item: item,
        gap: gap,
        fontScale: widget.fontScale,
        lineSpacing: widget.lineSpacing,
        chantPlace: widget.chantPlace,
        onTap: widget.onTapBlock == null
            ? null
            : () => widget.onTapBlock!(item.index),
      ),
      VerseTextItem() => _VerseView(
        key: ValueKey('verse-${item.verseId}-${item.language.code}'),
        item: item,
        gap: gap,
        fontScale: widget.fontScale,
        lineSpacing: widget.lineSpacing,
      ),
    };
    return KeyedSubtree(key: _itemKeys[index], child: child);
  }

  Widget _buildLazy() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final margin = NamoSizes.pageMargin(width);
        final column = min(width, NamoSizes.phraseColumn);
        final side = (width - column) / 2 + margin;
        return CustomScrollView(
          key: _viewportKey,
          controller: widget.controller,
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                side,
                0,
                side,
                MediaQuery.paddingOf(context).bottom + NamoSpace.xl,
              ),
              sliver: SliverList.builder(
                itemCount: widget.items.length,
                itemBuilder: (context, i) => _item(i),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    while (_itemKeys.length < items.length) {
      _itemKeys.add(GlobalKey());
    }
    if (_lazy) return _buildLazy();
    final lastHeading = items.lastIndexWhere((i) => i is HeadingItem);
    final split = lastHeading < 0 ? items.length : lastHeading;

    return LayoutBuilder(
      builder: (context, constraints) {
        final margin = NamoSizes.pageMargin(constraints.maxWidth);
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
                  // At the foot, room to bring the last line fully above the
                  // floating control bar: the bar's whole height arrives in
                  // the bottom padding (the body runs under it).
                  padding: EdgeInsets.fromLTRB(
                    margin,
                    0,
                    margin,
                    MediaQuery.paddingOf(context).bottom + NamoSpace.xl,
                  ),
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
    required this.gap,
    required this.fontScale,
    required this.bookmarked,
    required this.onToggleBookmark,
  });

  final HeadingItem item;
  final double gap;
  final double fontScale;
  final bool bookmarked;
  final VoidCallback onToggleBookmark;

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    final section = item.section;
    final size = 20 * fontScale;
    final heading = NamoType.sectionTitleSinhala(p.text)
        .copyWith(fontSize: size);
    // The bookmark button is 48 high; the heading's first line is centred on
    // it, whatever the text size, and the rest wraps beneath.
    final firstLine = MediaQuery.textScalerOf(context)
        .scale(size * heading.height!);
    final inset = firstLine >= NamoSizes.touchTarget
        ? 0.0
        : (NamoSizes.touchTarget - firstLine) / 2;
    return Padding(
      padding: EdgeInsets.only(top: gap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
                        // A pirith is one section: no number before it.
                        if (item.canBookmark) ...[
                          Text(
                            '${section.number}',
                            softWrap: true,
                            style: NamoType.sectionTitle(p.gold)
                                .copyWith(fontSize: size),
                          ),
                          const SizedBox(width: NamoSpace.md),
                        ],
                        Expanded(
                          child: Text(
                            section.heading,
                            softWrap: true,
                            style: heading,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (item.canBookmark) ...[
                const SizedBox(width: NamoSpace.xs),
                NamoIconButton(
                  tooltip: bookmarked
                      ? 'Remove bookmark'
                      : 'Bookmark this section',
                  icon: Symbols.bookmark_rounded,
                  filled: bookmarked,
                  color: bookmarked ? p.gold : p.textSecondary,
                  onPressed: onToggleBookmark,
                ),
              ],
            ],
          ),
          if (item.romanTitle != null)
            Padding(
              padding: const EdgeInsets.only(top: NamoSpace.xs),
              child: Text(
                item.romanTitle!,
                softWrap: true,
                style: NamoType.romanName(p.textSecondary),
              ),
            ),
          if (item.credit != null && item.credit!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: NamoSpace.xs),
              child: Text(
                item.credit!,
                softWrap: true,
                style: NamoType.caption(p.textSecondary),
              ),
            ),
          for (final note in item.notes)
            Padding(
              padding: const EdgeInsets.only(top: NamoSpace.xs),
              child: Text(
                note,
                softWrap: true,
                // Follows the reading's text size, never below 12.
                style: NamoType.caption(p.textSecondary)
                    .copyWith(fontSize: max(12.0, 13 * fontScale)),
              ),
            ),
          const SizedBox(height: NamoSpace.md),
          SizedBox(height: 1, child: ColoredBox(color: p.border)),
        ],
      ),
    );
  }
}

class _VerseView extends StatelessWidget {
  const _VerseView({
    super.key,
    required this.item,
    required this.gap,
    required this.fontScale,
    required this.lineSpacing,
  });

  final VerseTextItem item;
  final double gap;
  final double fontScale;
  final double lineSpacing;

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    return Padding(
      padding: EdgeInsets.only(top: gap),
      child: Text(
        item.text,
        softWrap: true,
        style: readingStyle(
          item.language,
          fontScale: fontScale,
          lineSpacing: lineSpacing,
          color: item.secondary ? p.textSecondary : p.text,
        ),
      ),
    );
  }
}

/// How many times each block (by verse id) has been built; for tests of what
/// a place change rebuilds.
@visibleForTesting
final Map<String, int> blockBuildCounts = {};

/// For each phrase of [item], where its text starts and ends (end
/// exclusive) in the passage in [language], which is the phrase texts joined
/// by single spaces (single line breaks in a unit kept line by line); null
/// for a phrase with no text in [language].
List<(int, int)?> _passageRanges(PhraseBlockItem item, ReadingLanguage language) {
  final out = <(int, int)?>[];
  var at = 0;
  for (final phrase in item.phrases) {
    final t = phrase.text(language);
    if (t.isEmpty) {
      out.add(null);
      continue;
    }
    out.add((at, at + t.length));
    at += t.length + 1;
  }
  return out;
}

/// One block of a pirith: for each chosen language one flowing passage, the
/// phrases of the block in order, one under the other (narrow) or side by
/// side (wide, two languages). While it is the block being chanted it has a
/// quiet background, and the phrase being chanted is marked in every
/// passage: a sage background and an underline, which change no metrics.
///
/// It listens to the place itself and rebuilds only when its own part of the
/// place changes: the blocks a place change leaves and enters.
class _PhraseBlockView extends StatefulWidget {
  const _PhraseBlockView({
    super.key,
    required this.item,
    required this.gap,
    required this.fontScale,
    required this.lineSpacing,
    required this.chantPlace,
    required this.onTap,
  });

  final PhraseBlockItem item;
  final double gap;
  final double fontScale;
  final double lineSpacing;
  final ValueListenable<ChantPlace?>? chantPlace;
  final VoidCallback? onTap;

  @override
  State<_PhraseBlockView> createState() => _PhraseBlockViewState();
}

class _PhraseBlockViewState extends State<_PhraseBlockView> {
  /// The phrase being chanted when this is the active block, else null.
  int? _active;

  int? _phraseNow() {
    final place = widget.chantPlace?.value;
    return place != null && place.block == widget.item.index
        ? place.phrase
        : null;
  }

  @override
  void initState() {
    super.initState();
    _active = _phraseNow();
    widget.chantPlace?.addListener(_onPlace);
  }

  @override
  void didUpdateWidget(_PhraseBlockView old) {
    super.didUpdateWidget(old);
    if (!identical(old.chantPlace, widget.chantPlace)) {
      old.chantPlace?.removeListener(_onPlace);
      widget.chantPlace?.addListener(_onPlace);
      _active = _phraseNow();
    }
  }

  @override
  void dispose() {
    widget.chantPlace?.removeListener(_onPlace);
    super.dispose();
  }

  void _onPlace() {
    final now = _phraseNow();
    if (now != _active) setState(() => _active = now);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    assert(() {
      blockBuildCounts.update(item.verseId, (n) => n + 1, ifAbsent: () => 1);
      return true;
    }());
    final p = NamoPalette.of(context);
    final wide = MediaQuery.sizeOf(context).width >= NamoSizes.wideBreakpoint;
    Widget? passage(int which) {
      final l = item.languages[which];
      final style = readingStyle(
        l,
        fontScale: widget.fontScale,
        lineSpacing: widget.lineSpacing,
        color: which == 0 ? p.text : p.textSecondary,
      );
      // The marked secondary text takes the full text colour, which keeps
      // it readable on the mark.
      final marked = TextStyle(
        color: p.text,
        backgroundColor: p.sageMark,
        decoration: TextDecoration.underline,
        decorationColor: p.sage,
      );
      final spans = <InlineSpan>[];
      if (item.keepLines && l == ReadingLanguage.sinhala) {
        // A unit's Sinhala is its meaning, with its own line breaks.
        final meaning = item.meaning;
        if (meaning != null) spans.add(TextSpan(text: meaning));
      } else {
        // A unit's lines each start a line; a pirith's phrases flow.
        final gap = TextSpan(text: item.keepLines ? '\n' : ' ');
        for (var i = 0; i < item.phrases.length; i++) {
          final t = item.phrases[i].text(l);
          if (t.isEmpty) continue;
          if (spans.isNotEmpty) spans.add(gap);
          spans.add(TextSpan(text: t, style: _active == i ? marked : null));
        }
      }
      if (spans.isEmpty) return null;
      return Text.rich(
        TextSpan(style: style, children: spans),
        key: ValueKey('passage-${item.verseId}-${l.name}'),
        softWrap: true,
      );
    }

    final passages = [
      for (var w = 0; w < item.languages.length; w++) passage(w),
    ].whereType<Widget>().toList();
    Widget block;
    // A unit's meaning is always under its lines.
    if (wide && passages.length == 2 && !item.keepLines) {
      block = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: passages[0]),
          const SizedBox(width: NamoSpace.xl),
          Expanded(child: passages[1]),
        ],
      );
    } else {
      block = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var k = 0; k < passages.length; k++) ...[
            if (k > 0) const SizedBox(height: NamoSpace.sm),
            passages[k],
          ],
        ],
      );
    }
    if (_active != null) {
      block = Stack(
        fit: StackFit.passthrough,
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: -NamoSpace.sm,
            right: -NamoSpace.sm,
            top: -NamoSpace.xs,
            bottom: -NamoSpace.xs,
            child: ExcludeSemantics(
              child: DecoratedBox(
                key: const ValueKey('block-active'),
                decoration: BoxDecoration(
                  color: p.sageTint,
                  borderRadius: BorderRadius.circular(NamoRadius.sm),
                ),
              ),
            ),
          ),
          block,
        ],
      );
    }
    if (widget.onTap != null) {
      block = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        // A short block is still a full-size target.
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: NamoSizes.touchTarget),
          child: block,
        ),
      );
    }
    return Padding(
      padding: EdgeInsets.only(top: widget.gap),
      child: block,
    );
  }
}
