import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../design/tokens.dart';
import '../design/typography.dart';
import '../design/widgets/buttons.dart';
import '../design/widgets/empty_state.dart';
import '../design/widgets/not_found.dart';
import '../design/widgets/progress_line.dart';
import '../design/widgets/segmented_selector.dart';
import '../reader/reader_settings_sheet.dart';
import '../router.dart';
import '../settings/settings.dart';
import 'tipitaka_book.dart';
import 'tipitaka_reader_rows.dart';
import 'tipitaka_repository.dart';
import 'tipitaka_state.dart';
import 'tipitaka_labels.dart';
import 'tipitaka_tree.dart';

/// One Tripitaka reading in Pali, Sinhala or both, opened at the entry the
/// person last had at the top.
///
/// The body is built lazily around an anchor: a [CustomScrollView] whose
/// centre is the anchored entry, with the entries above it in a reversed
/// list before it. Opening at a remembered entry so builds nothing far above
/// it, and the entry sits exactly at the top.
class TipitakaReaderScreen extends ConsumerStatefulWidget {
  const TipitakaReaderScreen({
    super.key,
    required this.readingKey,
    this.fromSaved = false,
  });

  final String readingKey;

  /// Back goes to Saved instead of the reading's list.
  final bool fromSaved;

  @override
  ConsumerState<TipitakaReaderScreen> createState() =>
      _TipitakaReaderScreenState();
}

class _TipitakaReaderScreenState extends ConsumerState<TipitakaReaderScreen> {
  static const _saveEvery = Duration(milliseconds: 400);

  final _scroll = ScrollController();
  final _viewport = GlobalKey();
  final _progress = ValueNotifier<double>(0);

  /// The rows built now, by entry index.
  final _rows = <int, Element>{};

  late final TipitakaPlacesController _places;

  /// The entry at the centre of the scroll view; set when the reading has
  /// loaded.
  int? _anchor;
  int _count = 0;

  /// The top-most visible entry.
  int? _top;
  bool _dirty = false;
  bool _measureQueued = false;
  Timer? _saveTimer;

  @override
  void initState() {
    super.initState();
    _places = ref.read(tipitakaPlacesProvider.notifier);
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    // Providers cannot change while the tree is being torn down, so the last
    // place is handed over once this frame is done.
    final top = _top;
    if (_dirty && top != null && _count > 0) {
      final places = _places, key = widget.readingKey, count = _count;
      SchedulerBinding.instance.addPostFrameCallback(
        (_) => places.remember(key, entry: top, fraction: (top + 1) / count),
      );
    }
    _scroll.dispose();
    _progress.dispose();
    super.dispose();
  }

  // ---- place --------------------------------------------------------------

  void _measureSoon() {
    if (_measureQueued) return;
    _measureQueued = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _measureQueued = false;
      if (mounted) _measure();
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  /// Finds the top-most visible entry; notes it and saves it soon.
  void _measure() {
    final view = _viewport.currentContext?.findRenderObject();
    if (view is! RenderBox || !view.hasSize || _count == 0) return;
    final top = view.localToGlobal(Offset.zero).dy;
    int? first;
    for (final MapEntry(key: i, value: element) in _rows.entries) {
      final box = element.renderObject;
      if (box is! RenderBox || !box.attached || !box.hasSize) continue;
      final bottom = box.localToGlobal(Offset(0, box.size.height)).dy;
      if (bottom > top + 0.5 && (first == null || i < first)) first = i;
    }
    if (first == null || first == _top) return;
    _top = first;
    _progress.value = (first + 1) / _count;
    _dirty = true;
    _saveTimer ??= Timer(_saveEvery, _save);
  }

  void _save() {
    _saveTimer = null;
    final top = _top;
    if (!_dirty || top == null || _count == 0) return;
    _dirty = false;
    _places.remember(
      widget.readingKey,
      entry: top,
      fraction: (top + 1) / _count,
    );
  }

  /// Puts entry [i] at the top and builds around it.
  void _anchorAt(int i) {
    if (_scroll.hasClients) _scroll.jumpTo(0);
    setState(() => _anchor = i);
    _measureSoon();
  }

  void _backToBeginning() => _anchorAt(0);

  // ---- navigation ---------------------------------------------------------

  /// The top-bar arrow and the system Back: Saved when opened from there,
  /// else the reading's own list when it has children, else its parent's.
  void _back() {
    if (ref.read(tipitakaTreeProvider).hasError) {
      // A failed load is tried afresh next time.
      ref.invalidate(tipitakaManifestProvider);
      ref.invalidate(tipitakaTreeProvider);
    }
    if (widget.fromSaved) {
      context.go(Routes.saved);
      return;
    }
    final tree = ref.read(tipitakaTreeProvider).value;
    final key = widget.readingKey;
    final node = tree?.node(key);
    if (tree == null || node == null) {
      context.go(Routes.tipitaka);
    } else if (tree.children(key).isNotEmpty) {
      context.go(Routes.tipitakaNode(key));
    } else if (node.parent case final parent?) {
      context.go(Routes.tipitakaNode(parent));
    } else {
      context.go(Routes.tipitaka);
    }
  }

  // ---- build --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    ref.listen(settingsProvider, (previous, next) {
      if (previous == null) return;
      // Keep the entry at the top where it is when the text changes size.
      if ((previous.fontScale != next.fontScale ||
              previous.lineSpacing != next.lineSpacing) &&
          _top != null) {
        _anchorAt(_top!);
      }
    });
    final p = NamoPalette.of(context);
    final key = widget.readingKey;
    final tree = ref.watch(tipitakaTreeProvider).value;
    final loaded = ref.watch(tipitakaReadingProvider(key));
    final node = tree?.node(key);
    final title = node == null ? '' : tipitakaName(node);

    final Widget page;
    if (loaded.hasError && !loaded.isLoading) {
      page = _frame(
        title: title,
        body: EmptyState(
          icon: Symbols.error_outline_rounded,
          title: 'This text could not be opened.',
          actionLabel: 'Go back',
          onAction: _back,
        ),
      );
    } else if (loaded.value case final reading?) {
      if (tree == null) return const NotFoundScreen();
      page = _reader(context, tree, reading, title);
    } else if (loaded.hasValue && !loaded.isLoading) {
      // Loaded: the key is unknown or not a reading.
      return const NotFoundScreen();
    } else {
      page = _frame(
        title: title,
        body: Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2, color: p.sage),
          ),
        ),
      );
    }

    // The reader is the only page on the stack, so a system Back would
    // otherwise leave the app.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(backgroundColor: p.background, body: page),
    );
  }

  /// The top bar with only Back over [body] (loading and failure).
  Widget _frame({required String title, required Widget body}) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _TopBar(title: title, onBack: _back),
      Expanded(child: body),
    ],
  );

  Widget _reader(
    BuildContext context,
    TipitakaTree tree,
    TipitakaReading reading,
    String title,
  ) {
    final p = NamoPalette.of(context);
    final settings = ref.watch(settingsProvider);
    final saved = ref.watch(tipitakaSavedProvider).contains(reading.key);
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= NamoSizes.wideBreakpoint;
    final chosen =
        ref.watch(tipitakaViewProvider) ?? defaultTipitakaView(wide: wide);
    final view = reading.hasSinhala ? chosen : TipitakaView.pali;

    _count = reading.pali.length;
    if (_anchor == null) {
      final place = ref.read(tipitakaPlacesProvider).of(reading.key);
      final at = (place?.entry ?? 0).clamp(0, _count == 0 ? 0 : _count - 1);
      _anchor = at;
      _top = at;
      _progress.value = _count == 0 ? 0 : (at + 1) / _count;
      // Opening counts as reading: the place is noted at once.
      _dirty = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) _save();
      });
    }
    final anchor = _anchor!;

    final rows = TipitakaReadingRows(
      reading: reading,
      view: view,
      wide: wide,
      fontScale: settings.fontScale,
      lineSpacing: settings.lineSpacing,
      palette: p,
    );
    final margin = NamoSizes.pageMargin(width);
    final maxWidth = view == TipitakaView.both && wide
        ? NamoSizes.phraseColumn
        : NamoSizes.readingColumn;
    Widget slot(int i) => _RowSlot(
      key: ValueKey('tipitaka-entry-$i'),
      index: i,
      rows: _rows,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: rows.build(i),
        ),
      ),
    );

    final previous = tree.previousReading(reading.key);
    final next = tree.nextReading(reading.key);
    final centre = ValueKey('tipitaka-centre-$anchor');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _TopBar(
          title: title,
          onBack: _back,
          saved: saved,
          onSave: () =>
              ref.read(tipitakaSavedProvider.notifier).toggle(reading.key),
          onSettings: () => showReaderSettingsSheet(
            context,
            onBackToBeginning: _backToBeginning,
            textOnly: true,
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(margin, 0, margin, NamoSpace.sm),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: NamoSizes.readingColumn,
              ),
              child: SegmentedSelector<TipitakaView>(
                semanticLabel: 'Language',
                segments: const [
                  Segment(TipitakaView.pali, 'පාලි'),
                  Segment(TipitakaView.sinhala, 'සිංහල'),
                  Segment(TipitakaView.both, 'Both'),
                ],
                selected: {chosen},
                onPressed: (v) {
                  if (v == chosen) return;
                  ref.read(tipitakaViewProvider.notifier).choose(v);
                  // The rows change height: keep the top entry in place.
                  if (_top != null) _anchorAt(_top!);
                },
              ),
            ),
          ),
        ),
        ValueListenableBuilder<double>(
          valueListenable: _progress,
          builder: (context, progress, _) => ProgressLine(value: progress),
        ),
        Expanded(
          child: SafeArea(
            top: false,
            bottom: false,
            child: NotificationListener<ScrollNotification>(
              onNotification: (_) {
                _measureSoon();
                return false;
              },
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: margin),
                child: CustomScrollView(
                  key: _viewport,
                  controller: _scroll,
                  center: centre,
                  slivers: [
                    // Entries above the anchor, built upwards.
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, j) => slot(anchor - 1 - j),
                        childCount: anchor,
                      ),
                    ),
                    SliverList(
                      key: centre,
                      delegate: SliverChildBuilderDelegate(
                        (context, j) => slot(anchor + j),
                        childCount: _count - anchor,
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: TipitakaNeighbours(
                        tree: tree,
                        previous: previous,
                        next: next,
                        maxWidth: maxWidth,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}


/// One built row; known to the reader while it is built, so the reader can
/// find the top-most visible entry.
class _RowSlot extends StatefulWidget {
  const _RowSlot({
    super.key,
    required this.index,
    required this.rows,
    required this.child,
  });

  final int index;
  final Map<int, Element> rows;
  final Widget child;

  @override
  State<_RowSlot> createState() => _RowSlotState();
}

class _RowSlotState extends State<_RowSlot> {
  @override
  void initState() {
    super.initState();
    widget.rows[widget.index] = context as Element;
  }

  @override
  void didUpdateWidget(_RowSlot old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index || !identical(old.rows, widget.rows)) {
      if (identical(old.rows[old.index], context)) old.rows.remove(old.index);
      widget.rows[widget.index] = context as Element;
    }
  }

  @override
  void dispose() {
    if (identical(widget.rows[widget.index], context)) {
      widget.rows.remove(widget.index);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}


/// The reader's quiet top bar: Back, the reading's name on one line, the
/// bookmark and reading settings (these two only once the text is open).
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.onBack,
    this.saved = false,
    this.onSave,
    this.onSettings,
  });

  final String title;
  final VoidCallback onBack;
  final bool saved;
  final VoidCallback? onSave;
  final VoidCallback? onSettings;

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    return ColoredBox(
      key: const ValueKey('tipitaka-reader-top-bar'),
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
                child: Semantics(
                  header: true,
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: NamoType.label(p.textSecondary),
                  ),
                ),
              ),
              const SizedBox(width: NamoSpace.xs),
              if (onSave != null)
                NamoIconButton(
                  icon: Symbols.bookmark_rounded,
                  tooltip: saved ? 'Remove bookmark' : 'Bookmark this text',
                  filled: saved,
                  color: saved ? p.gold : p.text,
                  onPressed: onSave,
                ),
              if (onSettings != null)
                NamoIconButton(
                  key: const ValueKey('tipitaka-reader-settings'),
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
