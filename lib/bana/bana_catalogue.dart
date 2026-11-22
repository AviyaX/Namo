/// The bana list: dharma talks on YouTube, by topic and monk. The file is
/// `assets/bana/bana.json` (built by `tool/bana/build_bana.py`), or a newer
/// copy fetched from the app's storage. Titles are shown exactly as the file
/// holds them.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';

class BanaTopic {
  const BanaTopic({required this.id, required this.si, required this.en});
  final String id, si, en;
}

class BanaSpeaker {
  const BanaSpeaker({required this.id, required this.name});
  final String id, name;
}

class BanaChannel {
  const BanaChannel({required this.id, required this.name, required this.url});
  final String id, name, url;
}

/// One YouTube talk.
@immutable
class Bana {
  const Bana({
    required this.id,
    required this.title,
    required this.speaker,
    required this.channel,
    required this.topics,
    required this.seconds,
    required this.embeddable,
    this.series,
    this.part,
  });

  final String id, title, speaker, channel;
  final List<String> topics;
  final int seconds;
  final bool embeddable;

  /// The series id and the part number (from 1), when it is a series part.
  final String? series;
  final int? part;

  Uri get watchUri => Uri.parse('https://www.youtube.com/watch?v=$id');
  Uri get thumbnailUri => Uri.parse('https://i.ytimg.com/vi/$id/mqdefault.jpg');

  /// `m:ss`, or `h:mm:ss` from an hour up.
  String get lengthLabel {
    final h = seconds ~/ 3600, m = seconds % 3600 ~/ 60, s = seconds % 60;
    final ss = s.toString().padLeft(2, '0');
    return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$ss' : '$m:$ss';
  }
}

/// A numbered series; [parts] are video ids in part order.
@immutable
class BanaSeries {
  const BanaSeries({
    required this.id,
    required this.title,
    required this.speaker,
    required this.channel,
    required this.topics,
    required this.parts,
  });

  final String id, title, speaker, channel;
  final List<String> topics, parts;
}

/// What the list shows: a whole series, or one bana.
sealed class BanaItem {
  const BanaItem();
}

class SeriesItem extends BanaItem {
  const SeriesItem(this.series);
  final BanaSeries series;
}

class SingleItem extends BanaItem {
  const SingleItem(this.bana);
  final Bana bana;
}

Never _bad(String what) => throw FormatException('bana: $what');

String _string(Map json, String key) {
  final v = json[key];
  if (v is! String) _bad('"$key" is not text');
  return v;
}

List<String> _strings(Map json, String key) {
  final v = json[key];
  if (v is! List || v.any((e) => e is! String)) _bad('"$key" is not a list');
  return List.unmodifiable(v.cast<String>());
}

List<Map> _maps(Map json, String key) {
  final v = json[key];
  if (v == null) return const [];
  if (v is! List || v.any((e) => e is! Map)) _bad('"$key" is not a list');
  return v.cast<Map>();
}

class BanaCatalogue {
  BanaCatalogue._({
    required this.version,
    required this.topics,
    required this.speakers,
    required this.channels,
    required this.series,
    required this.bana,
  })  : _byId = {for (final b in bana) b.id: b},
        _seriesById = {for (final s in series) s.id: s};

  final int version;
  final List<BanaTopic> topics;
  final List<BanaSpeaker> speakers;
  final Map<String, BanaChannel> channels;
  final List<BanaSeries> series;
  final List<Bana> bana;
  final Map<String, Bana> _byId;
  final Map<String, BanaSeries> _seriesById;

  /// Reads the file's text; null if it is not a usable list.
  static BanaCatalogue? parse(String json) {
    try {
      final root = jsonDecode(json);
      if (root is! Map) _bad('not an object');
      final version = root['version'];
      if (version is! int) _bad('no version');
      final channels = [
        for (final c in _maps(root, 'channels'))
          BanaChannel(
            id: _string(c, 'id'),
            name: _string(c, 'name'),
            url: _string(c, 'url'),
          ),
      ];
      return BanaCatalogue._(
        version: version,
        topics: [
          for (final t in _maps(root, 'topics'))
            BanaTopic(
              id: _string(t, 'id'),
              si: _string(t, 'si'),
              en: _string(t, 'en'),
            ),
        ],
        speakers: [
          for (final s in _maps(root, 'speakers'))
            BanaSpeaker(id: _string(s, 'id'), name: _string(s, 'name')),
        ],
        channels: {for (final c in channels) c.id: c},
        series: [
          for (final s in _maps(root, 'series'))
            BanaSeries(
              id: _string(s, 'id'),
              title: _string(s, 'title'),
              speaker: _string(s, 'speaker'),
              channel: _string(s, 'channel'),
              topics: _strings(s, 'topics'),
              parts: _strings(s, 'parts'),
            ),
        ],
        bana: [
          for (final b in _maps(root, 'bana'))
            Bana(
              id: _string(b, 'id'),
              title: _string(b, 'title'),
              speaker: _string(b, 'speaker'),
              channel: _string(b, 'channel'),
              topics: _strings(b, 'topics'),
              seconds: b['seconds'] is int
                  ? b['seconds'] as int
                  : _bad('"seconds" is not a number'),
              embeddable: b['embeddable'] is bool
                  ? b['embeddable'] as bool
                  : _bad('"embeddable" is not true/false'),
              series: b['series'] as String?,
              part: b['part'] as int?,
            ),
        ],
      );
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  Bana? byId(String id) => _byId[id];
  BanaSeries? seriesById(String id) => _seriesById[id];

  /// The series' parts that exist in the list, in part order.
  List<Bana> partsOf(String seriesId) {
    final s = _seriesById[seriesId];
    if (s == null) return const [];
    return [
      for (final id in s.parts)
        ?_byId[id],
    ];
  }

  static bool _topicOk(String? topicId, List<String> topics) =>
      topicId == null || topics.contains(topicId);

  /// Series cards first, then single bana, each in file order. A non-empty
  /// [query] instead lists the single bana and series parts whose title holds
  /// it (a part counts under its series' topics).
  List<BanaItem> filter({
    String? speakerId,
    String? topicId,
    String query = '',
  }) {
    bool speakerOk(String speaker) => speakerId == null || speaker == speakerId;
    final q = query.trim().toLowerCase();
    if (q.isNotEmpty) {
      return [
        for (final b in bana)
          if (speakerOk(b.speaker) &&
              _topicOk(
                topicId,
                b.series == null
                    ? b.topics
                    : _seriesById[b.series]?.topics ?? const [],
              ) &&
              b.title.toLowerCase().contains(q))
            SingleItem(b),
      ];
    }
    return [
      for (final s in series)
        if (speakerOk(s.speaker) && _topicOk(topicId, s.topics)) SeriesItem(s),
      for (final b in bana)
        if (b.series == null &&
            speakerOk(b.speaker) &&
            _topicOk(topicId, b.topics))
          SingleItem(b),
    ];
  }

  /// The topics that have a bana or series by [speakerId] (all if null).
  Set<String> topicsFor(String? speakerId) => {
        for (final s in series)
          if (speakerId == null || s.speaker == speakerId) ...s.topics,
        for (final b in bana)
          if (speakerId == null || b.speaker == speakerId) ...b.topics,
      };
}
