import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../audio/audio_catalogue.dart';
import '../audio/audio_controls.dart';
import '../audio/chant_timing.dart';
import '../audio/chant_player.dart';
import '../content/model.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../design/widgets/buttons.dart';
import '../design/widgets/empty_state.dart';
import '../design/widgets/progress_line.dart';
import '../design/widgets/not_found.dart';
import '../flows/flow_reading.dart';
import '../flows/flows.dart' show flowsProvider, isFlowId;
import '../library/library_gate.dart';
import '../router.dart';
import '../saved/saved.dart';
import '../settings/settings.dart';
import 'auto_scroll.dart';
import 'chant_follow.dart';
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

  /// The recording when it is a timed one (a chant), whose controls are
  /// the chanting bar; null otherwise.
  Recording? _timed;

  /// Where the chanting is. Idle until the first play of this reader asks
  /// for the recording; the player is not asked before that.
  final _chant = ValueNotifier<ChantState>(const ChantState());
  bool _chantLoaded = false;

  /// The chanting's place on the page and whether the page follows it; null
  /// for a reading without chant timing.
  ChantFollow? _follow;

  /// Whether the person's last word is "chant": set by Play chanting, cleared
  /// by auto-scroll starting, the app going to the background and leaving
  /// this reader. A load that finishes while it is false does not play.
  bool _chantWanted = false;

  /// Whether this reader has asked the player for its recording.
  bool _startedChant = false;

  /// Set once Previous or Next pirith has paused the player; the reader
  /// that replaces this one owns the player from then on.
  bool _handedOver = false;

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

  /// Whether the open reading is a pirith (set by each build): its bar
  /// goes between pirith, so the section buttons are not worked out. Never
  /// true for a flow, even one of pirith sections only.
  bool _pirith = false;

  /// Whether the text holds passages (set by each build), so that the body
  /// is built on demand and where far items sit is first an estimate.
  bool _lazy = false;

  /// Names the latest restore of a place; a touch ends it (see [_goToPlace]).
  int _restoreGeneration = 0;

  double? _width;

  /// The headings (counted from the first) Previous and Next go to.
  int? _previousHeading;
  int? _nextHeading;

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
      endKnown: () => _body.currentState?.endBuilt ?? true,
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
  void _bindAudio(Reading reading, Recording? recording, ChantPlayer? player) {
    final readingId = recording?.readingId;
    if (identical(player, _player) && readingId == _playerReading) return;
    final old = _player;
    _audioSub?.cancel();
    _audioSub = null;
    _audioStatus = ChantStatus.idle;
    _updateAwake();
    _player = player;
    _playerReading = readingId;
    _timed = recording != null && recording.timed ? recording : null;
    _chantLoaded = false;
    _chant.value = const ChantState();
    _setFollow(
      _timed == null
          ? null
          : ChantFollow(
              times: _timed!.blockTimes,
              paliLengths: paliLengthsOf(reading),
            ),
    );
    if (old != null) unawaited(old.pause());
    if (recording == null || player == null) return;
    if (_timed != null) {
      // Only listened to now; the recording is asked for at the first play.
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !identical(_player, player)) return;
        _audioSub = player.states.listen(_onAudio);
      });
      return;
    }
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !identical(_player, player)) return;
      _audioSub = player.states.listen(_onAudio);
      player.load(recording);
    });
  }

  /// The one link between audio and auto-scroll: audio starting starts the
  /// scroll, if the setting asks for it.
  void _onAudio(ChantState state) {
    if (_timed != null) {
      _audioStatus = state.status;
      // What a player left from another reading is not this one's chanting.
      if (_chantLoaded) {
        _chant.value = state;
        _follow?.onState(state);
      }
      _updateAwake();
      return;
    }
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

  /// Replaces the follower; the old one is cleared (leaving that pirith).
  /// Never notifies: this runs during build.
  void _setFollow(ChantFollow? next) {
    final old = _follow;
    if (old != null) {
      old.removeListener(_onFollowChanged);
      old.place.removeListener(_onPlace);
      old.reset();
      SchedulerBinding.instance.addPostFrameCallback((_) => old.dispose());
    }
    _follow = next;
    next?.addListener(_onFollowChanged);
    next?.place.addListener(_onPlace);
  }

  /// Started or following changed: what shows (the follow button, the
  /// blocks' tap) is looked at again.
  void _onFollowChanged() {
    if (mounted) setState(() {});
  }

  /// The place moved: the page goes with it, if it is following.
  void _onPlace() {
    final follow = _follow, place = follow?.place.value;
    if (follow == null || place == null || !follow.following) return;
    _followPlace(place);
  }

  void _followPlace(ChantPlace place) {
    // After the frame, so the block the place has entered is laid out.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      // A hand may have come down since the place changed.
      if (!mounted || !(_follow?.following ?? false)) return;
      _chase(() => _phraseTarget(place), animate: true);
    });
  }

  /// A hand on the text (touch or wheel): the page is no longer pulled back
  /// to where it was, and following stops until it is asked for.
  void _onHand() {
    _restoreGeneration++;
    _autoScroll.pause();
    _follow?.pausedByHand();
  }

  /// The person asks the page to follow again.
  void _resumeFollowing() {
    final follow = _follow;
    if (follow == null) return;
    follow.resume();
    final place = follow.place.value;
    if (place != null) _followPlace(place);
  }

  /// A tap on block [block] while the chanting is started: chant from there,
  /// and follow. An untimed block, and any tap before the chanting started
  /// or when it is neither playing nor paused, does nothing.
  void _tapBlock(int block) {
    final follow = _follow, recording = _timed;
    if (follow == null || recording == null || !follow.started) return;
    final status = _chant.value.status;
    if (status != ChantStatus.playing && status != ChantStatus.paused) return;
    final start = blockStart(recording.blockTimes, block);
    if (start == null) return;
    follow.resume();
    unawaited(_player?.seek(start));
  }

  void _toBackground() {
    _chantWanted = false;
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
      // Only one of the two at a time; the later request wins.
      _chantWanted = false;
      if (_chantLoaded) unawaited(_player?.pause());
      _autoScroll.play();
    }
  }

  /// Plays, pauses or resumes the chanting. The recording is asked for the
  /// first time it is played (and again after a failure).
  Future<void> _chantPlayOrPause() async {
    final player = _player, recording = _timed;
    if (player == null || recording == null) return;
    final status = _chant.value.status;
    if (status == ChantStatus.loading) return;
    if (status == ChantStatus.playing) {
      _chantWanted = false;
      await player.pause();
      return;
    }
    _chantWanted = true;
    _autoScroll.pause();
    if (!_chantLoaded || status == ChantStatus.failed) {
      _chantLoaded = true;
      _startedChant = true;
      _chant.value = const ChantState(status: ChantStatus.loading);
      await player.load(recording);
      if (!mounted || !identical(_player, player) || !_chantWanted) return;
    }
    await player.play();
  }

  void _chantRestart() {
    _chantWanted = true;
    _autoScroll.pause();
    unawaited(_player?.restart());
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
    // Quiet before the player is let go.
    _chantWanted = false;
    // Only a reader that started the chanting and still owns the player
    // silences it; the next pirith's reader may be playing already.
    final player = _player;
    if (player != null && !_handedOver && (_startedChant || _timed == null)) {
      unawaited(player.pause());
    }
    _setFollow(null);
    _chant.dispose();
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
    // Passages are built on demand, so where they are is only known once
    // the new offset has been laid out.
    if (_lazy ||
        SchedulerBinding.instance.schedulerPhase ==
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
    if (_pirith) return;
    final tops = _headingTops();
    int? previous, next;
    if (tops.isNotEmpty) {
      final offset = _scroll.offset;
      final current = _currentSection(tops, offset);
      if (current >= 0 && offset - tops[current] > _atStart) {
        previous = current;
      } else if (current > 0) {
        previous = current - 1;
      }
      if (current + 1 < tops.length && tops[current + 1] > offset) {
        next = current + 1;
      }
    }
    if (previous != _previousHeading || next != _nextHeading) {
      setState(() {
        _previousHeading = previous;
        _nextHeading = next;
      });
    }
  }

  /// Brings heading [index] (counted from the first) to the top. Where a
  /// heading among passages sits is first an estimate, so it is looked for
  /// again once the page is laid out there (see [_chase]).
  void _toHeading(int index) => _chase(() {
    final tops = _headingTops();
    return (
      offset: index < tops.length ? tops[index] : _scroll.offset,
      exact: true,
    );
  });

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
      _chase(
        () =>
            (offset: _body.currentState!.offsetOfSection(section), exact: true),
      );
    } else if (saved != null) {
      _goToPlace(saved.position);
    }
  }

  /// Returns to [place].
  void _goToPlace(ReadingPosition place) =>
      _chase(() => (offset: _offsetOf(place), exact: true));

  /// Where the active phrase's top sits one third of the way down the text
  /// area. A block that is not built yet has no exact place: its estimated
  /// start is gone to first (not [exact]).
  ({double offset, bool exact}) _phraseTarget(ChantPlace place) {
    final body = _body.currentState!;
    final third = _scroll.position.viewportDimension / 3;
    final top = body.offsetOfPhrase(place.block, place.phrase);
    if (top != null) return (offset: top - third, exact: true);
    final index = body.widget.items.indexWhere(
      (i) => i is PhraseBlockItem && i.index == place.block,
    );
    final extents = body.extents();
    if (index < 0 || index >= extents.length) {
      return (offset: _scroll.offset, exact: true);
    }
    return (offset: extents[index].top, exact: false);
  }

  /// Goes to what [target] says. Passages are built on demand, so where a
  /// far one sits is first an estimate: once the page has been laid out
  /// around the jump the target is asked again, until it stops moving. With
  /// [animate], the last, exact step glides (a jump when the person wants no
  /// motion).
  ///
  /// A touch or wheel on the text ends the looking at once, so the page is
  /// never pulled back from where the person put it.
  void _chase(
    ({double offset, bool exact}) Function() target, {
    bool animate = false,
    int tries = 6,
    int? generation,
  }) {
    if (_body.currentState == null || !_scroll.hasClients) return;
    if (generation == null) _restoreGeneration++;
    final mine = generation ?? _restoreGeneration;
    if (mine != _restoreGeneration) return;
    final now = target();
    final duration = NamoMotion.of(context, NamoMotion.open);
    if (animate && now.exact && duration > Duration.zero) {
      final to = now.offset.clamp(0.0, _scroll.position.maxScrollExtent);
      if ((to - _scroll.offset).abs() > 0.5) {
        unawaited(
          _scroll.animateTo(to, duration: duration, curve: NamoMotion.curve),
        );
      }
      return;
    }
    _jumpTo(now.offset);
    if (!_lazy || tries <= 0) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          mine != _restoreGeneration ||
          _body.currentState == null ||
          !_scroll.hasClients) {
        return;
      }
      final again = target();
      if (!again.exact || (again.offset - _scroll.offset).abs() > 0.5) {
        _chase(target, animate: animate, tries: tries - 1, generation: mine);
      }
    });
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
      _goToPlace(place);
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
  /// opened from. A flow goes back to Home, its editor, or else the Library;
  /// for any other reading the editor means nothing.
  void _back() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    final id = widget.readingId;
    if (isFlowId(id)) {
      context.go(switch (widget.from) {
        ReaderFrom.home => Routes.home,
        ReaderFrom.editor => Routes.flowEditor(id),
        ReaderFrom.saved || null => Routes.library,
      });
      return;
    }
    context.go(switch (widget.from) {
      ReaderFrom.home => Routes.home,
      ReaderFrom.saved => Routes.saved,
      ReaderFrom.editor || null => Routes.contents(id),
    });
  }

  /// Replaces this reader with the reading [step] places away in its
  /// category (a pirith's previous or next); the place left is saved first.
  /// Null at either end, and for a reading that is not a pirith (a flow
  /// never is).
  VoidCallback? _neighbour(Library library, Reading reading, int step) {
    if (isFlowId(reading.id) || !reading.isPhrased) return null;
    final category = library.categories
        .where((c) => c.readings.any((r) => r.id == reading.id))
        .firstOrNull;
    if (category == null) return null;
    final to = category.numberOf(reading.id) - 1 + step;
    if (to < 0 || to >= category.readings.length) return null;
    final next = category.readings[to];
    return () {
      _autoScroll.pause();
      final player = _player;
      if (player != null) unawaited(player.pause());
      // This reader may outlive the hand-over by a frame; it must not
      // release the screen lock after the next pirith has taken it.
      _setAwake(false);
      _chantWanted = false;
      _follow?.reset();
      _handedOver = true;
      _audioSub?.cancel();
      _audioSub = null;
      _save();
      // Always at the beginning, whatever place is remembered for it.
      context.pushReplacement(
        Routes.reader(
          next.id,
          sectionId: next.sections.first.id,
          from: widget.from,
        ),
      );
    };
  }

  /// The ids of [reading]'s sections shown as bookmarked. A flow's section
  /// is when the original section it shows is.
  static Set<String> _bookmarkedSections(Reading reading, SavedState saved) {
    if (!isFlowId(reading.id)) {
      return {
        for (final b in saved.bookmarks)
          if (b.readingId == reading.id) b.sectionId,
      };
    }
    return {
      for (final s in reading.sections)
        if (refOfFlowSection(s.id) case final original?
            when saved.bookmarks.contains(
              Bookmark(
                readingId: original.readingId,
                sectionId: original.sectionId,
              ),
            ))
          s.id,
    };
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
          final reading = resolveReading(
            library,
            ref.watch(flowsProvider),
            widget.readingId,
          );
          if (reading == null) return const NotFoundScreen();
          // A flow has no favourite, no recording and no neighbours, and is
          // gone through section by section even when it holds only pirith.
          final flow = isFlowId(reading.id);
          // Only a flow can have no sections.
          final empty = flow && reading.sections.isEmpty;
          final items = buildReaderItems(
            reading,
            settings.languages,
            settings.layout,
          );
          _pirith = !flow && reading.isPhrased;
          _lazy = items.any((i) => i is PhraseBlockItem);
          final favourite = saved.isFavourite(reading.id);
          final previousReading = _neighbour(library, reading, -1);
          final nextReading = _neighbour(library, reading, 1);
          final recording = flow
              ? null
              : ref.watch(audioCatalogueProvider).recordingFor(reading.id);
          _bindAudio(
            reading,
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
              body: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _TopBar(
                        title: reading.title,
                        favourite: favourite,
                        onBack: _back,
                        onFavourite: flow
                            ? null
                            : () => ref
                                  .read(savedProvider.notifier)
                                  .toggleFavourite(reading.id),
                        onSettings: () => showReaderSettingsSheet(
                          context,
                          onBackToBeginning: _backToBeginning,
                          showLayout: flow || !reading.isPhrased,
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
                          child: empty
                              ? const EmptyState(
                                  icon: Symbols.playlist_add_rounded,
                                  title: 'This flow has no sections yet.',
                                )
                              : Listener(
                                  onPointerDown: (_) => _onHand(),
                                  onPointerSignal: (_) => _onHand(),
                                  child: ReaderBody(
                                    key: _body,
                                    items: items,
                                    controller: _scroll,
                                    fontScale: settings.fontScale,
                                    lineSpacing: settings.lineSpacing,
                                    bookmarkedSections: _bookmarkedSections(
                                      reading,
                                      saved,
                                    ),
                                    onToggleBookmark: (sectionId) {
                                      // A flow's section is bookmarked as the
                                      // original it shows.
                                      final original = flow
                                          ? refOfFlowSection(sectionId)
                                          : null;
                                      ref
                                          .read(savedProvider.notifier)
                                          .toggleBookmark(
                                            original?.readingId ?? reading.id,
                                            original?.sectionId ?? sectionId,
                                          );
                                    },
                                    chantPlace: _follow?.place,
                                    // No tap, and no tap semantics, until the
                                    // chanting has been started.
                                    onTapBlock: _follow?.started ?? false
                                        ? _tapBlock
                                        : null,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                  if (_follow case final follow?)
                    _FollowButton(follow: follow, onPressed: _resumeFollowing),
                ],
              ),
              bottomNavigationBar: ListenableBuilder(
                listenable: Listenable.merge([_autoScroll, _chant]),
                builder: (context, _) => ReaderBottomBar(
                  previousTooltip: _pirith
                      ? 'Previous pirith'
                      : 'Previous section',
                  nextTooltip: _pirith ? 'Next pirith' : 'Next section',
                  onPrevious: _pirith
                      ? previousReading
                      : _previousHeading == null || empty
                      ? null
                      : () => _toHeading(_previousHeading!),
                  onNext: _pirith
                      ? nextReading
                      : _nextHeading == null || empty
                      ? null
                      : () => _toHeading(_nextHeading!),
                  onPlay: empty ? null : _playOrPause,
                  autoScroll: _autoScroll.status,
                  audio: recording == null || recording.timed
                      ? null
                      : AudioControls(recording: recording),
                  chantState: recording != null && recording.timed
                      ? _chant.value
                      : null,
                  onChantPlay: _chantPlayOrPause,
                  onChantRestart: _chantRestart,
                  onChantSeek: (to) => unawaited(_player?.seek(to)),
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

  /// Null leaves the favourite button out (a flow has none).
  final VoidCallback? onFavourite;
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
              if (onFavourite != null)
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

/// Floats above the control bar while the chanting has started and the page
/// is not following it; asks the page to follow again.
class _FollowButton extends StatelessWidget {
  const _FollowButton({required this.follow, required this.onPressed});

  final ChantFollow follow;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    // The body runs under the floating bar, whose height arrives here as the
    // bottom padding.
    final bottom = MediaQuery.paddingOf(context).bottom + NamoSpace.sm;
    return ListenableBuilder(
      listenable: Listenable.merge([follow, follow.place]),
      builder: (context, _) {
        if (!follow.started || follow.following || follow.place.value == null) {
          return const SizedBox.shrink();
        }
        return Positioned(
          left: 0,
          right: 0,
          bottom: bottom,
          child: Center(
            child: DecoratedBox(
              key: const ValueKey('follow-chanting'),
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(NamoRadius.lg),
              ),
              child: QuietButton(
                label: 'Follow the chanting',
                onPressed: onPressed,
              ),
            ),
          ),
        );
      },
    );
  }
}
