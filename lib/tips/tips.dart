import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/key_value_store.dart';

/// The first-run tips: each points at one control, the first time its
/// screen is reached.
enum Tip {
  recordings(
    'Recordings',
    'Recordings download by themselves over Wi-Fi after install. Settings shows the progress under Recordings.',
  ),
  myFlows(
    'My flows',
    'Choose the sections you chant, in your order, and read them as one.',
  ),
  readerSettings(
    'Languages and layout',
    'Choose Pali, Sinhala or English here, and how two languages sit together.',
  ),
  scrollChant(
    'Scroll and Chant',
    'Scroll moves the text by itself. Chant plays the recording and follows the words.',
  ),

  /// A tip told by motion, not a bubble: the corner of a book's page peels
  /// up and back once, the first time a book opens in Pages mode. No screen
  /// shows it as a bubble.
  bookPeel('Turning pages', '');

  const Tip(this.title, this.body);
  final String title, body;
}

const tipsKey = 'namo.tips.v1';

class TipsState {
  const TipsState({this.seen = const {}, this.active});

  final Set<Tip> seen;
  final Tip? active;

  TipsState copyWith({
    Set<Tip>? seen,
    Tip? active,
    bool clearActive = false,
  }) =>
      TipsState(
        seen: seen ?? this.seen,
        active: clearActive ? null : (active ?? this.active),
      );

  Map<String, dynamic> toJson() => {
        'seen': (seen.map((t) => t.name).toList()..sort()),
      };

  /// Forgiving: unknown names are ignored, anything else gives an empty state.
  factory TipsState.fromJson(Object? json) {
    if (json is! Map) return const TipsState();
    final names = json['seen'];
    if (names is! List) return const TipsState();
    return TipsState(
      seen: Set.unmodifiable({
        for (final t in Tip.values)
          if (names.contains(t.name)) t,
      }),
    );
  }
}

class TipsController extends Notifier<TipsState> {
  TipsController({this.web = kIsWeb});

  final bool web;

  @override
  TipsState build() {
    final text = ref.read(keyValueStoreProvider).read(tipsKey);
    if (text == null) return const TipsState();
    try {
      return TipsState.fromJson(jsonDecode(text));
    } on FormatException {
      return const TipsState();
    }
  }

  void _set(TipsState next) {
    state = next;
    ref.read(keyValueStoreProvider).save(tipsKey, jsonEncode(next.toJson()));
  }

  /// Recordings are never downloaded on the web, so that tip is never due.
  bool isDue(Tip t) =>
      !state.seen.contains(t) && (t != Tip.recordings || !web);

  /// Makes [t] the tip on show, unless it is not due or another is showing.
  bool request(Tip t) {
    if (!isDue(t) || state.active != null) return false;
    state = state.copyWith(active: t);
    return true;
  }

  /// The person has read the tip on show: it is seen for good.
  void dismiss() {
    final t = state.active;
    if (t == null) return;
    _set(TipsState(seen: Set.unmodifiable({...state.seen, t})));
  }

  /// The screen went away before the tip was read: it stays due.
  void withdraw(Tip t) {
    if (state.active == t) state = state.copyWith(clearActive: true);
  }

  /// [t] has been shown by other means than a bubble (the book's peel): it
  /// is seen for good.
  void markSeen(Tip t) {
    if (state.seen.contains(t)) return;
    _set(state.copyWith(seen: Set.unmodifiable({...state.seen, t})));
  }

  void resetAll() => _set(const TipsState());
}

final tipsProvider = NotifierProvider<TipsController, TipsState>(
  TipsController.new,
);

/// Tests switch tips off here; the app leaves them on.
final tipsAllowedProvider = Provider<bool>((_) => true);
