/// Search over the Tripitaka's section names. A person types Sinhala letters
/// or plain English letters; both are folded to simple keys for matching only.
/// Nothing here changes or displays the source text.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'tipitaka_repository.dart';
import 'tipitaka_tree.dart';

final _notLetterOrDigit = RegExp(r'[^\p{L}\p{M}\p{N}]', unicode: true);

/// For matching only, never displayed: drops U+200C and U+200D, whitespace
/// and punctuation; keeps letters (including Sinhala vowel signs and the hal
/// sign) and digits; lower-cases Latin.
String foldName(String text) =>
    text.toLowerCase().replaceAll(_notLetterOrDigit, '');

// Sinhala block, U+0D80-U+0DFF. Each entry is what the character gives in a
// plain a-z key. Consonants get a following 'a' unless a hal or vowel sign
// follows (see [latinKey]).
const _consonants = <int, String>{
  0x0D9A: 'k', // ක
  0x0D9B: 'kh', // ඛ
  0x0D9C: 'g', // ග
  0x0D9D: 'gh', // ඝ
  0x0D9E: 'n', // ඞ
  0x0D9F: 'ng', // ඟ
  0x0DA0: 'c', // ච
  0x0DA1: 'ch', // ඡ
  0x0DA2: 'j', // ජ
  0x0DA3: 'jh', // ඣ
  0x0DA4: 'n', // ඤ
  0x0DA5: 'gn', // ඥ
  0x0DA6: 'nj', // ඦ
  0x0DA7: 't', // ට
  0x0DA8: 'th', // ඨ
  0x0DA9: 'd', // ඩ
  0x0DAA: 'dh', // ඪ
  0x0DAB: 'n', // ණ
  0x0DAC: 'nd', // ඬ
  0x0DAD: 't', // ත
  0x0DAE: 'th', // ථ
  0x0DAF: 'd', // ද
  0x0DB0: 'dh', // ධ
  0x0DB1: 'n', // න
  0x0DB3: 'nd', // ඳ
  0x0DB4: 'p', // ප
  0x0DB5: 'ph', // ඵ
  0x0DB6: 'b', // බ
  0x0DB7: 'bh', // භ
  0x0DB8: 'm', // ම
  0x0DB9: 'mb', // ඹ
  0x0DBA: 'y', // ය
  0x0DBB: 'r', // ර
  0x0DBD: 'l', // ල
  0x0DC0: 'v', // ව
  0x0DC1: 's', // ශ
  0x0DC2: 's', // ෂ
  0x0DC3: 's', // ස
  0x0DC4: 'h', // හ
  0x0DC5: 'l', // ළ
  0x0DC6: 'f', // ෆ
};

// Independent vowels; long ones fold to short.
const _vowels = <int, String>{
  0x0D85: 'a', // අ
  0x0D86: 'a', // ආ
  0x0D87: 'i', // ඉ
  0x0D88: 'i', // ඊ
  0x0D89: 'u', // උ
  0x0D8A: 'u', // ඌ
  0x0D8B: 'ru', // ඍ
  0x0D8C: 'ru', // ඎ
  0x0D91: 'e', // එ
  0x0D92: 'e', // ඒ
  0x0D93: 'ai', // ඓ
  0x0D94: 'o', // ඔ
  0x0D95: 'o', // ඕ
  0x0D96: 'au', // ඖ
};

// Vowel signs that follow a consonant.
const _vowelSigns = <int, String>{
  0x0DCF: 'a', // ා
  0x0DD0: 'a', // ැ
  0x0DD1: 'a', // ෑ
  0x0DD2: 'i', // ි
  0x0DD3: 'i', // ී
  0x0DD4: 'u', // ු
  0x0DD6: 'u', // ූ
  0x0DD8: 'ru', // ෘ
  0x0DD9: 'e', // ෙ
  0x0DDA: 'e', // ේ
  0x0DDB: 'ai', // ෛ
  0x0DDC: 'o', // ො
  0x0DDD: 'o', // ෝ
  0x0DDE: 'au', // ෞ
};

const _hal = 0x0DCA; // ්
const _anusvara = 0x0D82; // ං -> m

// Spellings of one vowel sign as several code points, made one.
const _joinedSigns = <String, String>{
  'ෝ': 'ෝ', // e + aa + hal -> oo
  'ො': 'ො', // e + aa -> o
  'ෞ': 'ෞ', // e + au length mark -> au
  'ෙෙ': 'ෛ', // e + e -> ai
};
final _joinedSignsPattern = RegExp(_joinedSigns.keys.join('|'));

/// A plain a-z key for Pali written in Sinhala script, for matching only.
String latinKey(String paliInSinhalaScript) {
  final text = paliInSinhalaScript
      .replaceAll('‌', '')
      .replaceAll('‍', '')
      .replaceAllMapped(_joinedSignsPattern, (m) => _joinedSigns[m[0]]!);
  final out = StringBuffer();
  var pendingA = false;
  void flush() {
    if (pendingA) out.write('a');
    pendingA = false;
  }

  for (final c in text.runes) {
    final consonant = _consonants[c];
    final vowel = _vowels[c];
    final sign = _vowelSigns[c];
    if (consonant != null) {
      flush();
      out.write(consonant);
      pendingA = true;
    } else if (sign != null) {
      if (pendingA) {
        out.write(sign);
        pendingA = false;
      }
    } else if (c == _hal) {
      pendingA = false;
    } else if (vowel != null) {
      flush();
      out.write(vowel);
    } else if (c == _anusvara) {
      flush();
      out.write('m');
    }
  }
  flush();
  return out.toString();
}

const _plainLetters = <String, String>{
  'ā': 'a', 'ī': 'i', 'ū': 'u', 'ṃ': 'm', 'ṁ': 'm', 'ṅ': 'n', 'ñ': 'n',
  'ṇ': 'n', 'ṭ': 't', 'ḍ': 'd', 'ḷ': 'l', 'ś': 's', 'ṣ': 's', 'ē': 'e',
  'ō': 'o', 'ä': 'a', 'æ': 'a', 'é': 'e', 'è': 'e', 'ï': 'i', 'ö': 'o',
  'ü': 'u',
};
final _longVowels = RegExp(r'aa+|ii+|uu+');
final _notAToZ = RegExp('[^a-z]');

/// Folds what a person types in Latin letters the same way: diacritics off,
/// long vowels short, lower case, a-z only.
String foldLatinQuery(String query) {
  final out = StringBuffer();
  for (final ch in query.toLowerCase().split('')) {
    out.write(_plainLetters[ch] ?? ch);
  }
  return out
      .toString()
      .replaceAll(_notAToZ, '')
      .replaceAllMapped(_longVowels, (m) => m[0]![0]);
}

final _sinhalaLetter = RegExp(r'[අ-ෆ]');

/// What a typed [query] folds to for matching: Sinhala-letter queries as
/// names are folded, others as Latin letters. Empty when there is nothing to
/// match.
String foldTipitakaQuery(String query) => _sinhalaLetter.hasMatch(query)
    ? foldName(query)
    : foldLatinQuery(query);

class _Entry {
  _Entry(this.node, this.pali, this.sinhala, this.latin);
  final TipitakaNode node;
  final String pali, sinhala, latin;
}

class TipitakaSearchIndex {
  /// Folds every name once, in tree order.
  TipitakaSearchIndex(TipitakaTree tree) {
    final seen = <String>{};
    void walk(String key) {
      if (!seen.add(key)) return;
      final node = tree.node(key);
      if (node == null) return;
      _entries.add(_Entry(
        node,
        foldName(node.pali),
        foldName(node.sinhala),
        latinKey(node.pali),
      ));
      for (final child in tree.children(key)) {
        walk(child.key);
      }
    }

    for (final root in TipitakaTree.roots) {
      walk(root);
    }
  }

  final _entries = <_Entry>[];

  /// Best first: whole-name match, then starts-with, then contains; ties in
  /// tree order. Empty for a query that folds to nothing.
  List<TipitakaNode> find(String query, {int limit = 50}) {
    if (limit <= 0) return const [];
    final sinhala = _sinhalaLetter.hasMatch(query);
    final q = foldTipitakaQuery(query);
    if (q.isEmpty) return const [];
    final buckets = [
      <TipitakaNode>[],
      <TipitakaNode>[],
      <TipitakaNode>[],
    ];
    for (final e in _entries) {
      final rank = sinhala
          ? _min(_rank(e.pali, q), _rank(e.sinhala, q))
          : _rank(e.latin, q);
      if (rank < 3) buckets[rank].add(e.node);
    }
    return [for (final b in buckets) ...b].take(limit).toList();
  }

  /// 0 whole name, 1 starts with, 2 contains, 3 no match.
  static int _rank(String name, String q) {
    if (name == q) return 0;
    if (name.startsWith(q)) return 1;
    return name.contains(q) ? 2 : 3;
  }

  static int _min(int a, int b) => a < b ? a : b;
}

/// Not retried on its own (like the tree it is built from): a failure shows
/// the load message, whose Try again builds it afresh.
final tipitakaSearchProvider = FutureProvider<TipitakaSearchIndex>(
  (ref) async {
    final tree = await ref.watch(tipitakaTreeProvider.future);
    return TipitakaSearchIndex(tree);
  },
  retry: (_, _) => null,
);
