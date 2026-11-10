import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../design/tokens.dart';
import '../design/typography.dart';
import '../design/widgets/not_found.dart';
import '../library/library_gate.dart';
import '../router.dart';
import '../settings/settings.dart';
import 'reader_body.dart';
import 'reader_bottom_bar.dart';
import 'reader_items.dart';
import 'reader_settings_sheet.dart';

/// How close (in pixels) to a heading counts as being at its start.
const _atStart = 8.0;

class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({super.key, required this.readingId, this.sectionId});

  final String readingId;

  /// The section to open at; null or unknown opens at the top.
  final String? sectionId;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  final _scroll = ScrollController();
  final _body = GlobalKey<ReaderBodyState>();

  /// Whether the jump to [ReaderScreen.sectionId] has been scheduled.
  bool _opened = false;
  double? _previousTarget;
  double? _nextTarget;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(ReaderScreen old) {
    super.didUpdateWidget(old);
    if (old.readingId != widget.readingId ||
        old.sectionId != widget.sectionId) {
      _opened = false;
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
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
    // The scroll position can change during layout; buttons are updated
    // once that frame is done.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => _updateButtons());
    } else {
      _updateButtons();
    }
  }

  void _updateButtons() {
    if (!mounted) return;
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

  void _openAtSection() {
    final section = widget.sectionId;
    final body = _body.currentState;
    if (body == null) return;
    _jumpTo(section == null ? 0 : body.offsetOfSection(section));
  }

  /// Before the reading is laid out again (other languages, layout, text
  /// size or spacing), note the section at the top and how far into it the
  /// page is, then return there once the new layout is done.
  void _keepSection() {
    final tops = _headingTops();
    if (tops.isEmpty) return;
    final offset = _scroll.offset;
    final current = _currentSection(tops, offset);
    if (current < 0) return;
    double sectionEnd(List<double> tops, int i) =>
        i + 1 < tops.length ? tops[i + 1] : _scroll.position.maxScrollExtent;
    final start = tops[current], end = sectionEnd(tops, current);
    final fraction = end > start
        ? ((offset - start) / (end - start)).clamp(0.0, 1.0)
        : 0.0;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final now = _headingTops();
      if (current >= now.length) return;
      final nowStart = now[current], nowEnd = sectionEnd(now, current);
      _jumpTo(nowStart + fraction * (nowEnd - nowStart));
    });
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
        _keepSection();
      }
    });
    final settings = ref.watch(settingsProvider);
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

          if (!_opened) {
            _opened = true;
            SchedulerBinding.instance.addPostFrameCallback((_) {
              if (mounted) _openAtSection();
            });
          }
          SchedulerBinding.instance.addPostFrameCallback(
            (_) => _updateButtons(),
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
                  if (category != null)
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
                // Wired in Task 10.
                const IconButton(
                  tooltip: 'Add to favourites',
                  icon: Icon(Icons.favorite_border),
                  onPressed: null,
                ),
                IconButton(
                  key: const ValueKey('reader-settings'),
                  tooltip: 'Reading settings',
                  icon: const Icon(Icons.tune),
                  onPressed: () => showReaderSettingsSheet(context),
                ),
              ],
            ),
            body: ReaderBody(
              key: _body,
              items: items,
              controller: _scroll,
              fontScale: settings.fontScale,
              lineSpacing: settings.lineSpacing,
            ),
            bottomNavigationBar: ReaderBottomBar(
              onPrevious: _previousTarget == null
                  ? null
                  : () => _jumpTo(_previousTarget!),
              onNext: _nextTarget == null ? null : () => _jumpTo(_nextTarget!),
            ),
          );
        },
      ),
    );
  }
}
