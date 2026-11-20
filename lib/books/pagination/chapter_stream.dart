// ignore_for_file: prefer_initializing_formals
/// The chapters around the one being read, cut into screen pages ahead of
/// time so a page turn can carry straight across a chapter's end.
///
/// Only the current chapter and the reading pages either side of it stay
/// cut. Cutting runs a few pages at a time, one frame apart, current
/// chapter first, then the next, then the previous.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../book_model.dart';
import '../book_places.dart';
import 'book_paginator.dart';

/// How many pages are cut between two frames.
const _chunk = 4;

Future<void> _nextFrame() => SchedulerBinding.instance.endOfFrame;

/// One chapter's pages so far, and what is left to cut.
class _Chapter {
  _Chapter(Iterable<ScreenPage> pages) : _rest = pages.iterator;

  final Iterator<ScreenPage> _rest;
  final List<ScreenPage> pages = [];
  bool done = false;

  /// Cuts up to [_chunk] more pages.
  void cutSome() {
    for (var i = 0; i < _chunk && !done; i++) {
      if (_rest.moveNext()) {
        pages.add(_rest.current);
      } else {
        done = true;
      }
    }
  }
}

class ChapterStream extends ChangeNotifier {
  ChapterStream({
    required this.book,
    required int n,
    required BookSpot? spot,
    required Iterable<ScreenPage> Function(BookPage) cut,
    Future<void> Function() yieldFrame = _nextFrame,
  }) : _n = n,
       _spot = spot,
       _cut = cut,
       _yieldFrame = yieldFrame {
    _run(_generation);
  }

  final Book book;
  final Future<void> Function() _yieldFrame;
  Iterable<ScreenPage> Function(BookPage) _cut;

  final Map<int, _Chapter> _chapters = {};
  int _n;
  int _index = 0;

  /// Where the current chapter opens; null for its first page.
  BookSpot? _spot;

  /// Whether the page holding [_spot] has been cut and [_index] is set.
  bool _located = false;

  /// What to show while a re-cut has not yet reached the spot.
  ScreenPage? _heldCurrent;
  int _heldIndex = 0;
  int? _heldCount;

  /// Raised by every restart; cutting from an older one stops.
  int _generation = 0;
  bool _disposed = false;

  /// The direction (1 next, -1 previous) of a turn that had to wait.
  int _waitingFor = 0;

  /// The chapter being read.
  int get n => _n;

  /// The current page's 0-based place in its chapter.
  int get index => _located ? _index : _heldIndex;

  /// The chapter's page count; null until it is fully cut.
  int? get count {
    if (!_located) return _heldCount;
    final c = _chapters[_n]!;
    return c.done ? c.pages.length : null;
  }

  /// Null only until the current chapter's first page is cut.
  ScreenPage? get current =>
      _located ? _chapters[_n]!.pages[_index] : _heldCurrent;

  /// The page after [current]; null at the book's end or while it is not
  /// cut yet.
  ScreenPage? get peekNext {
    if (!_located) return null;
    final c = _chapters[_n]!;
    if (_index + 1 < c.pages.length) return c.pages[_index + 1];
    if (!c.done) return null;
    final next = book.nextReading(_n);
    final pages = next == null ? null : _chapters[next]?.pages;
    return pages == null || pages.isEmpty ? null : pages.first;
  }

  /// The page before [current]; null at the book's start or while it is not
  /// cut yet (a previous chapter's last page needs the whole chapter).
  ScreenPage? get peekPrevious {
    if (!_located) return null;
    if (_index > 0) return _chapters[_n]!.pages[_index - 1];
    final previous = book.previousReading(_n);
    final c = previous == null ? null : _chapters[previous];
    return c == null || !c.done || c.pages.isEmpty ? null : c.pages.last;
  }

  /// True while a turn was refused only because the page is still being cut.
  bool get waiting => _waitingFor != 0;

  /// Moves to the next page, across a chapter's end when need be. False at
  /// the book's end, or (with [waiting] set) when the page is not cut yet.
  bool next() {
    if (!_located) return _wait(1);
    final c = _chapters[_n]!;
    if (_index + 1 < c.pages.length) {
      _index++;
      notifyListeners();
      return true;
    }
    if (!c.done) return _wait(1);
    final next = book.nextReading(_n);
    if (next == null) return false;
    final pages = _chapters[next]?.pages;
    if (pages == null || pages.isEmpty) return _wait(1);
    _enter(next, 0);
    return true;
  }

  /// Moves to the previous page; as [next], the other way.
  bool previous() {
    if (!_located) return _wait(-1);
    if (_index > 0) {
      _index--;
      notifyListeners();
      return true;
    }
    final previous = book.previousReading(_n);
    if (previous == null) return false;
    final c = _chapters[previous];
    if (c == null || !c.done || c.pages.isEmpty) return _wait(-1);
    _enter(previous, c.pages.length - 1);
    return true;
  }

  /// Cuts all three chapters again with [cut] (the text size or the page
  /// box changed), keeping the page that holds the current passage. The old
  /// page stays in [current] until the new one is cut.
  void recut(Iterable<ScreenPage> Function(BookPage) cut) {
    if (_located) {
      _heldCurrent = current;
      _heldIndex = _index;
      _heldCount = count;
      _spot = _heldCurrent!.start;
    }
    _cut = cut;
    _chapters.clear();
    _located = false;
    _waitingFor = 0;
    _restart();
  }

  /// Opens chapter [n] at [spot] (its first page when null), cutting
  /// afresh except for chapters already cut.
  void jumpTo(int n, BookSpot? spot) {
    _n = n;
    _spot = spot;
    _located = false;
    _waitingFor = 0;
    _heldCurrent = null;
    _heldIndex = 0;
    _heldCount = null;
    _chapters.removeWhere((k, _) => k < n - 1 || k > n + 1);
    _restart();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }

  bool _wait(int direction) {
    _waitingFor = direction;
    return false;
  }

  /// Crosses into chapter [n] at page [index], dropping what is now out of
  /// range and cutting what is now missing.
  void _enter(int n, int index) {
    _n = n;
    _index = index;
    _waitingFor = 0;
    _chapters.removeWhere((k, _) => k < n - 1 || k > n + 1);
    _generation++;
    notifyListeners();
    _run(_generation);
  }

  void _restart() {
    _generation++;
    _locate();
    _run(_generation);
  }

  /// Sets [_index] once the page holding [_spot] is cut.
  void _locate() {
    if (_located) return;
    final c = _chapters[_n];
    if (c == null || c.pages.isEmpty) return;
    final spot = _spot;
    if (spot == null || c.done || c.pages.last.start.compareTo(spot) > 0) {
      _index = spot == null ? 0 : pageIndexOf(c.pages, spot);
      _located = true;
    }
  }

  /// The chapter to cut next: current, then next, then previous.
  _Chapter? _toCut() {
    for (final n in [_n, book.nextReading(_n), book.previousReading(_n)]) {
      if (n == null) continue;
      final page = book.page(n);
      if (page == null) continue;
      final c = _chapters.putIfAbsent(n, () => _Chapter(_cut(page)));
      if (!c.done) return c;
    }
    return null;
  }

  bool _turnReady() => switch (_waitingFor) {
    1 => peekNext != null || book.nextReading(_n) == null,
    -1 =>
      peekPrevious != null || _index > 0 || book.previousReading(_n) == null,
    _ => true,
  };

  Future<void> _run(int generation) async {
    while (true) {
      final c = _toCut();
      if (c == null) return;
      await _yieldFrame();
      if (_disposed || generation != _generation) return;
      c.cutSome();
      _locate();
      if (_waitingFor != 0 && _turnReady()) _waitingFor = 0;
      notifyListeners();
    }
  }
}
