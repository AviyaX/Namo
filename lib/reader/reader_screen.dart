import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../design/tokens.dart';
import '../design/typography.dart';
import '../design/widgets/not_found.dart';
import '../library/library_gate.dart';
import '../router.dart';
import '../saved/saved.dart';
import '../settings/settings.dart';
import 'position_controller.dart';
import 'reader_body.dart';
import 'reader_bottom_bar.dart';
import 'reader_items.dart';
import 'reader_settings_sheet.dart';
import 'reading_position.dart';

/// How close (in pixels) to a heading counts as being at its start.
const _atStart = 8.0;

/// How long the page must be still before its place is saved.
const _saveDelay = Duration(milliseconds: 400);

class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({super.key, required this.readingId, this.sectionId});

  final String readingId;

  /// The section to open at; null opens at the saved place, an unknown one
  /// at the top.
  final String? sectionId;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  final _scroll = ScrollController();
  final _body = GlobalKey<ReaderBodyState>();
  final _progress = ValueNotifier<double>(0);
  late final PositionController _positions;
  late final AppLifecycleListener _lifecycle;

  /// Whether the jump to the section or saved place has been scheduled.
  bool _opened = false;

  /// Whether that jump has happened; nothing is saved before it.
  bool _restored = false;

  /// The place to return to once a new layout is done (see [_keepPlace]).
  ReadingPosition? _pendingRestore;

  /// The place at the top after the last scroll, not yet saved when
  /// [_dirty].
  ReadingPosition? _latest;
  double _latestProgress = 0;
  bool _dirty = false;
  Timer? _saveTimer;

  double? _width;
  double? _previousTarget;
  double? _nextTarget;

  @override
  void initState() {
    super.initState();
    _positions = ref.read(positionProvider.notifier);
    _lifecycle = AppLifecycleListener(onHide: _save, onPause: _save);
    _scroll.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final width = MediaQuery.sizeOf(context).width;
    if (_width != null && width != _width) _keepPlace();
    _width = width;
  }

  @override
  void didUpdateWidget(ReaderScreen old) {
    super.didUpdateWidget(old);
    if (old.readingId != widget.readingId) {
      _saveLater();
      _latest = null;
      _pendingRestore = null;
      _restored = false;
    }
    if (old.readingId != widget.readingId ||
        old.sectionId != widget.sectionId) {
      _opened = false;
    }
  }

  @override
  void dispose() {
    // Providers cannot change while the tree is being torn down, so the last
    // place is noted now and handed over once this frame is done.
    _saveLater();
    _lifecycle.dispose();
    _scroll.dispose();
    _progress.dispose();
    super.dispose();
  }

  /// Saves the place at the top now, if it changed since the last save.
  void _save() {
    _saveTimer?.cancel();
    _saveTimer = null;
    final latest = _latest;
    if (!_dirty || latest == null) return;
    _dirty = false;
    _positions.save(latest, _latestProgress);
  }

  /// [_save] for life-cycle methods, where providers cannot change: the
  /// unsaved place is taken now and saved at the end of the frame.
  void _saveLater() {
    _saveTimer?.cancel();
    _saveTimer = null;
    final latest = _latest;
    if (!_dirty || latest == null) return;
    _dirty = false;
    final positions = _positions, progress = _latestProgress;
    SchedulerBinding.instance.addPostFrameCallback(
      (_) => positions.save(latest, progress),
    );
  }

  ReadingPosition? _capture() {
    final body = _body.currentState;
    if (body == null || !_scroll.hasClients) return null;
    return capturePosition(
      readingId: widget.readingId,
      items: body.widget.items,
      extents: body.extents(),
      scrollOffset: _scroll.offset,
    );
  }

  /// Each heading's offset, clamped to what the page can scroll to; empty
  /// before the current items are laid out.
  List<double> _headingTops() {
    final body = _body.currentState;
    if (body == null || !_scroll.hasClients) return const [];
    final items = body.widget.items;
    final extents = body.extents();
    if (extents.length != items.length) return const [];
    final max = _scroll.position.maxScrollExtent;
    return [
      for (var i = 0; i < items.length; i++)
        if (items[i] is HeadingItem) extents[i].top.clamp(0.0, max),
    ];
  }

  /// The index of the section the top of the page is in, or -1.
  int _currentSection(List<double> tops, double offset) =>
      tops.lastIndexWhere((top) => top <= offset + _atStart);

  void _onScroll() {
    // The scroll position can change during layout; the page is looked at
    // once that frame is done.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback(
        (_) => _afterScroll(scrolled: true),
      );
    } else {
      _afterScroll(scrolled: true);
    }
  }

  /// Updates the buttons and the progress line; after a scroll, also notes
  /// the place at the top and saves it once the page is still.
  void _afterScroll({required bool scrolled}) {
    if (!mounted || !_scroll.hasClients) return;
    _updateButtons();
    final position = _scroll.position;
    _progress.value = progressOf(position.pixels, position.maxScrollExtent);
    if (!scrolled || !_restored || _pendingRestore != null) return;
    final place = _capture();
    if (place == null) return;
    _latest = place;
    _latestProgress = _progress.value;
    _dirty = true;
    _saveTimer?.cancel();
    _saveTimer = Timer(_saveDelay, _save);
  }

  void _updateButtons() {
    final tops = _headingTops();
    double? previous, next;
    if (tops.isNotEmpty) {
      final offset = _scroll.offset;
      final current = _currentSection(tops, offset);
      if (current >= 0 && offset - tops[current] > _atStart) {
        previous = tops[current];
      } else if (current > 0) {
        previous = tops[current - 1];
      }
      if (current + 1 < tops.length && tops[current + 1] > offset) {
        next = tops[current + 1];
      }
    }
    if (previous != _previousTarget || next != _nextTarget) {
      setState(() {
        _previousTarget = previous;
        _nextTarget = next;
      });
    }
  }

  void _jumpTo(double offset) {
    if (!_scroll.hasClients) return;
    _scroll.jumpTo(offset.clamp(0.0, _scroll.position.maxScrollExtent));
  }

  double _offsetOf(ReadingPosition place) {
    final body = _body.currentState!;
    return offsetForPosition(
      position: place,
      items: body.widget.items,
      extents: body.extents(),
      maxScrollExtent: _scroll.position.maxScrollExtent,
    );
  }

  /// Goes to [ReaderScreen.sectionId], or else to the saved place.
  void _open() {
    final body = _body.currentState;
    if (body == null || !_scroll.hasClients) return;
    final section = widget.sectionId;
    final saved = ref.read(positionProvider).byReading[widget.readingId];
    _restored = true;
    if (section != null) {
      _jumpTo(body.offsetOfSection(section));
    } else if (saved != null) {
      _jumpTo(_offsetOf(saved.position));
    }
  }

  /// Before the reading is laid out again (other languages, layout, text
  /// size, spacing or window width), note the verse at the top while the
  /// old layout is still there, then return to it once the new one is done.
  void _keepPlace() {
    if (!_restored || _pendingRestore != null) return;
    final place = _capture();
    if (place == null) return;
    _pendingRestore = place;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _pendingRestore != place) return;
      _pendingRestore = null;
      if (_body.currentState == null || !_scroll.hasClients) return;
      _jumpTo(_offsetOf(place));
    });
  }

  void _backToBeginning() {
    _jumpTo(0);
    _saveTimer?.cancel();
    _saveTimer = null;
    _latest = null;
    _dirty = false;
    _positions.clear(widget.readingId);
  }

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(Routes.contents(widget.readingId));
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(settingsProvider, (previous, next) {
      if (previous == null) return;
      if (previous.languages != next.languages ||
          previous.layout != next.layout ||
          previous.fontScale != next.fontScale ||
          previous.lineSpacing != next.lineSpacing) {
        _keepPlace();
      }
    });
    final settings = ref.watch(settingsProvider);
    final saved = ref.watch(savedProvider);
    final p = NamoPalette.of(context);

    return ColoredBox(
      color: p.background,
      child: LibraryGate(
        builder: (context, library) {
          final reading = library.reading(widget.readingId);
          if (reading == null) return const NotFoundScreen();
          final category = library.categoryOf(reading.id);
          final items = buildReaderItems(
            reading,
            settings.languages,
            settings.layout,
          );
          final favourite = saved.isFavourite(reading.id);

          if (!_opened) {
            _opened = true;
            SchedulerBinding.instance.addPostFrameCallback((_) {
              if (mounted) _open();
            });
          }
          SchedulerBinding.instance.addPostFrameCallback(
            (_) => _afterScroll(scrolled: false),
          );

          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                tooltip: 'Back',
                icon: const Icon(Icons.arrow_back),
                onPressed: _back,
              ),
              titleSpacing: 0,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    reading.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (category != null && category.title != reading.title)
                    Text(
                      category.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: namoText(
                        NamoFonts.english,
                        size: 14,
                        color: p.textQuiet,
                      ),
                    ),
                ],
              ),
              actions: [
                IconButton(
                  tooltip: favourite
                      ? 'Remove from favourites'
                      : 'Add to favourites',
                  icon: Icon(
                    favourite ? Icons.favorite : Icons.favorite_border,
                    color: favourite ? p.accent : p.heading,
                  ),
                  onPressed: () => ref
                      .read(savedProvider.notifier)
                      .toggleFavourite(reading.id),
                ),
                IconButton(
                  key: const ValueKey('reader-settings'),
                  tooltip: 'Reading settings',
                  icon: const Icon(Icons.tune),
                  onPressed: () => showReaderSettingsSheet(
                    context,
                    onBackToBeginning: _backToBeginning,
                  ),
                ),
              ],
            ),
            body: ReaderBody(
              key: _body,
              items: items,
              controller: _scroll,
              fontScale: settings.fontScale,
              lineSpacing: settings.lineSpacing,
              bookmarkedSections: {
                for (final b in saved.bookmarks)
                  if (b.readingId == reading.id) b.sectionId,
              },
              onToggleBookmark: (sectionId) => ref
                  .read(savedProvider.notifier)
                  .toggleBookmark(reading.id, sectionId),
            ),
            bottomNavigationBar: ValueListenableBuilder<double>(
              valueListenable: _progress,
              builder: (context, progress, _) => ReaderBottomBar(
                progress: progress,
                onPrevious: _previousTarget == null
                    ? null
                    : () => _jumpTo(_previousTarget!),
                onNext: _nextTarget == null
                    ? null
                    : () => _jumpTo(_nextTarget!),
              ),
            ),
          );
        },
      ),
    );
  }
}
