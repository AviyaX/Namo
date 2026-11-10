import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../audio/audio_catalogue.dart';
import '../audio/audio_controls.dart';
import '../audio/chant_player.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../design/widgets/buttons.dart';
import '../design/widgets/progress_line.dart';
import '../design/widgets/not_found.dart';
import '../library/library_gate.dart';
import '../router.dart';
import '../saved/saved.dart';
import '../settings/settings.dart';
import 'auto_scroll.dart';
import 'position_controller.dart';
import 'reader_body.dart';
import 'reader_bottom_bar.dart';
import 'reader_items.dart';
import 'reader_settings_sheet.dart';
import 'reading_position.dart';
import 'screen_awake.dart';

/// How close (in pixels) to a heading counts as being at its start.
const _atStart = 8.0;

/// How long the page must be still before its place is saved.
const _saveDelay = Duration(milliseconds: 400);

/// While the page keeps moving (auto-scroll), the place is saved at most
/// this often.
const _saveWhileMoving = Duration(milliseconds: 2500);

class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({
    super.key,
    required this.readingId,
    this.sectionId,
    this.from,
  });

  final String readingId;

  /// The section to open at; null opens at the saved place, an unknown one
  /// at the top.
  final String? sectionId;

  /// The page Back returns to; null for the Library with this reading's
  /// sections showing.
  final ReaderFrom? from;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen>
    with SingleTickerProviderStateMixin {
  final _scroll = ScrollController();
  final _body = GlobalKey<ReaderBodyState>();
  final _progress = ValueNotifier<double>(0);
  late final PositionController _positions;
  late final AppLifecycleListener _lifecycle;

  /// Auto-scroll, driven once per frame by [_ticker] while it runs.
  late final AutoScrollEngine _autoScroll;
  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;

  /// The recording's player, once bound; null for a reading without one.
  ChantPlayer? _player;
  String? _playerReading;
  StreamSubscription<ChantState>? _audioSub;
  ChantStatus _audioStatus = ChantStatus.idle;

  /// Keeps the screen on while the page scrolls or a recording plays.
  late final ScreenAwake _awake;
  bool _holdingAwake = false;

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

  /// Saves once the page is still ([_saveDelay]); restarted by each scroll.
  Timer? _saveTimer;

  /// Saves while the page keeps moving ([_saveWhileMoving]); started by the
  /// first scroll after a save, not restarted by later ones.
  Timer? _movingSaveTimer;

  double? _width;
  double? _previousTarget;
  double? _nextTarget;

  @override
  void initState() {
    super.initState();
    _positions = ref.read(positionProvider.notifier);
    _awake = ref.read(screenAwakeProvider);
    _lifecycle = AppLifecycleListener(
      onHide: _toBackground,
      onPause: _toBackground,
    );
    _scroll.addListener(_onScroll);
    _autoScroll = AutoScrollEngine(
      controller: _scroll,
      speed: ref.read(settingsProvider).scrollSpeed,
    )..addListener(_onAutoScroll);
    _ticker = createTicker(_onTick);
  }

  /// Runs the ticker only while auto-scroll is running.
  void _onAutoScroll() {
    final running = _autoScroll.status == AutoScrollStatus.running;
    if (running && !_ticker.isActive) {
      _lastTick = Duration.zero;
      _ticker.start();
    } else if (!running && _ticker.isActive) {
      _ticker.stop();
    }
    _updateAwake();
  }

  /// Holds the screen on while auto-scroll runs or the recording plays, and
  /// releases it once neither does.
  void _updateAwake() => _setAwake(
    _autoScroll.status == AutoScrollStatus.running ||
        _audioStatus == ChantStatus.playing,
  );

  void _setAwake(bool hold) {
    if (hold == _holdingAwake) return;
    _holdingAwake = hold;
    unawaited(hold ? _awake.hold() : _awake.release());
  }

  void _onTick(Duration elapsed) {
    final since = elapsed - _lastTick;
    _lastTick = elapsed;
    _autoScroll.onFrame(since);
  }

  /// Loads [recording] into [player] (both null for a reading without
  /// one) and watches it. Called on every build; does nothing new unless
  /// the reading or the player changed.
  void _bindAudio(Recording? recording, ChantPlayer? player) {
    final readingId = recording?.readingId;
    if (identical(player, _player) && readingId == _playerReading) return;
    final old = _player;
    _audioSub?.cancel();
    _audioSub = null;
    _audioStatus = ChantStatus.idle;
    _updateAwake();
    _player = player;
    _playerReading = readingId;
    if (old != null) unawaited(old.pause());
    if (recording == null || player == null) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !identical(_player, player)) return;
      _audioSub = player.states.listen(_onAudio);
      player.load(recording);
    });
  }

  /// The one link between audio and auto-scroll: audio starting starts the
  /// scroll, if the setting asks for it.
  void _onAudio(ChantState state) {
    final started =
        state.status == ChantStatus.playing &&
        _audioStatus != ChantStatus.playing;
    _audioStatus = state.status;
    if (started &&
        ref.read(settingsProvider).autoScrollWithAudio &&
        _autoScroll.status != AutoScrollStatus.running) {
      _autoScroll.play();
    }
    _updateAwake();
  }

  void _toBackground() {
    _autoScroll.pause();
    final player = _player;
    if (player != null) unawaited(player.pause());
    // The player reports its pause later; the screen is let go now.
    _setAwake(false);
    _save();
  }

  void _playOrPause() {
    if (_autoScroll.status == AutoScrollStatus.running) {
      _autoScroll.pause();
    } else {
      _autoScroll.play();
    }
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
      _autoScroll.pause();
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
    _audioSub?.cancel();
    _setAwake(false);
    _lifecycle.dispose();
    _ticker.dispose();
    _autoScroll.dispose();
    _scroll.dispose();
    _progress.dispose();
    super.dispose();
  }

  void _cancelSaveTimers() {
    _saveTimer?.cancel();
    _saveTimer = null;
    _movingSaveTimer?.cancel();
    _movingSaveTimer = null;
  }

  /// Saves the place at the top now, if it changed since the last save.
  void _save() {
    _cancelSaveTimers();
    final latest = _latest;
    if (!_dirty || latest == null) return;
    _dirty = false;
    _positions.save(latest, _latestProgress);
  }

  /// [_save] for life-cycle methods, where providers cannot change: the
  /// unsaved place is taken now and saved at the end of the frame.
  void _saveLater() {
    _cancelSaveTimers();
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
  /// the place at the top and saves it once the page is still, or every
  /// [_saveWhileMoving] while it keeps moving.
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
    _movingSaveTimer ??= Timer(_saveWhileMoving, _save);
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

  /// Moves the page on purpose; auto-scroll carries on from there.
  void _jumpTo(double offset) {
    if (!_scroll.hasClients) return;
    _scroll.jumpTo(offset.clamp(0.0, _scroll.position.maxScrollExtent));
    _autoScroll.syncToPage();
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
    _autoScroll.reset();
    _cancelSaveTimers();
    _latest = null;
    _dirty = false;
    _positions.clear(widget.readingId);
  }

  /// The top-bar arrow and the system Back: to the page the reading was
  /// opened from.
  void _back() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(switch (widget.from) {
      ReaderFrom.home => Routes.home,
      ReaderFrom.saved => Routes.saved,
      null => Routes.contents(widget.readingId),
    });
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
      _autoScroll.speed = next.scrollSpeed;
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
          final items = buildReaderItems(
            reading,
            settings.languages,
            settings.layout,
          );
          final favourite = saved.isFavourite(reading.id);
          final recording = ref
              .watch(audioCatalogueProvider)
              .recordingFor(reading.id);
          _bindAudio(
            recording,
            recording == null ? null : ref.watch(chantPlayerProvider),
          );

          if (!_opened) {
            _opened = true;
            SchedulerBinding.instance.addPostFrameCallback((_) {
              if (mounted) _open();
            });
          }
          SchedulerBinding.instance.addPostFrameCallback(
            (_) => _afterScroll(scrolled: false),
          );

          // The reader is the only page on the stack, so a system Back
          // (Android's button or gesture) would otherwise leave the app.
          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) _back();
            },
            child: Scaffold(
              backgroundColor: p.background,
              // The text runs under the floating control bar, which hands
              // its whole height to the body in MediaQuery.padding.bottom.
              extendBody: true,
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _TopBar(
                    title: reading.title,
                    favourite: favourite,
                    onBack: _back,
                    onFavourite: () => ref
                        .read(savedProvider.notifier)
                        .toggleFavourite(reading.id),
                    onSettings: () => showReaderSettingsSheet(
                      context,
                      onBackToBeginning: _backToBeginning,
                    ),
                  ),
                  ValueListenableBuilder<double>(
                    valueListenable: _progress,
                    builder: (context, progress, _) =>
                        ProgressLine(value: progress),
                  ),
                  Expanded(
                    child: SafeArea(
                      top: false,
                      bottom: false,
                      // A touch or a mouse wheel on the text pauses
                      // auto-scroll at once.
                      child: Listener(
                        onPointerDown: (_) => _autoScroll.pause(),
                        onPointerSignal: (_) => _autoScroll.pause(),
                        child: ReaderBody(
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
                      ),
                    ),
                  ),
                ],
              ),
              bottomNavigationBar: ListenableBuilder(
                listenable: _autoScroll,
                builder: (context, _) => ReaderBottomBar(
                  onPrevious: _previousTarget == null
                      ? null
                      : () => _jumpTo(_previousTarget!),
                  onNext: _nextTarget == null
                      ? null
                      : () => _jumpTo(_nextTarget!),
                  onPlay: _playOrPause,
                  autoScroll: _autoScroll.status,
                  audio: recording == null
                      ? null
                      : AudioControls(recording: recording),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The reader's quiet top bar: Back, the reading's title on one line,
/// favourite and reading settings. Flat, on the page's background, inside
/// the top safe area.
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.favourite,
    required this.onBack,
    required this.onFavourite,
    required this.onSettings,
  });

  final String title;
  final bool favourite;
  final VoidCallback onBack;
  final VoidCallback onFavourite;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    return ColoredBox(
      key: const ValueKey('reader-top-bar'),
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
              NamoIconButton(
                icon: Symbols.favorite_rounded,
                tooltip: favourite
                    ? 'Remove from favourites'
                    : 'Add to favourites',
                filled: favourite,
                color: favourite ? p.gold : p.text,
                onPressed: onFavourite,
              ),
              NamoIconButton(
                key: const ValueKey('reader-settings'),
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
