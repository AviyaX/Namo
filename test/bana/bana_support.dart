import 'dart:convert';

import 'package:buddhist_gatha/bana/bana_catalogue.dart';
import 'package:buddhist_gatha/bana/bana_player.dart';
import 'package:buddhist_gatha/bana/bana_repository.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/misc.dart';

/// Two monks: Alpha has a series (three parts, topic M) and a single on M;
/// Beta has one single on K.
String madeUpList({Set<String> notEmbeddable = const {}}) => jsonEncode({
  'version': 1,
  'topics': [
    {'id': 'M', 'si': 'Topic M', 'en': 'Meditation'},
    {'id': 'K', 'si': 'Topic K', 'en': 'Karma'},
  ],
  'speakers': [
    {'id': 'a', 'name': 'Ven. Alpha'},
    {'id': 'b', 'name': 'Ven. Beta'},
  ],
  'channels': [
    {'id': 'c', 'name': 'Chan', 'url': 'https://example.org/c'},
  ],
  'series': [
    {
      'id': 's1',
      'title': 'Calm series',
      'speaker': 'a',
      'channel': 'c',
      'topics': ['M'],
      'parts': ['v1', 'v2', 'v3'],
    },
  ],
  'bana': [
    for (var i = 1; i <= 3; i++)
      {
        'id': 'v$i',
        'title': 'Calm part $i',
        'speaker': 'a',
        'channel': 'c',
        'topics': ['M'],
        'seconds': 600,
        'embeddable': !notEmbeddable.contains('v$i'),
        'series': 's1',
        'part': i,
      },
    {
      'id': 'x1',
      'title': 'Alpha single',
      'speaker': 'a',
      'channel': 'c',
      'topics': ['M'],
      'seconds': 3725,
      'embeddable': true,
    },
    {
      'id': 'x2',
      'title': 'Beta single',
      'speaker': 'b',
      'channel': 'c',
      'topics': ['K'],
      'seconds': 90,
      'embeddable': true,
    },
  ],
});

class _Fixed extends BanaCatalogueController {
  _Fixed([this.notEmbeddable = const {}]);
  final Set<String> notEmbeddable;
  @override
  Future<BanaCatalogue> build() async =>
      BanaCatalogue.parse(madeUpList(notEmbeddable: notEmbeddable))!;
}

/// The made-up list with [id] (one of v1..v3) not allowed to be embedded.
Override banaNotEmbeddableOverride(String id) =>
    banaCatalogueProvider.overrideWith(() => _Fixed({id}));

List<Override> banaOverrides() => [
  banaCatalogueProvider.overrideWith(_Fixed.new),
];

/// A stand-in for YouTube's player: a plain box that counts how many times it
/// was created and holds the callbacks the page gave it.
class FakePlayers {
  int created = 0;
  int disposed = 0;
  String? lastVideoId;
  VoidCallback? onReady;
  VoidCallback? onError;
  bool active = true;
  int paused = 0;

  void ready() => onReady!();
  void fail() => onError!();

  Override get override => banaPlayerBuilderProvider.overrideWithValue((
    context,
    bana, {
    required onReady,
    required onError,
    required active,
  }) {
    if (this.active && !active) paused++;
    this.active = active;
    lastVideoId = bana.id;
    this.onReady = onReady;
    this.onError = onError;
    return _Probe(this);
  });
}

class _Probe extends StatefulWidget {
  const _Probe(this.owner);
  final FakePlayers owner;
  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  void initState() {
    super.initState();
    widget.owner.created++;
  }

  @override
  void dispose() {
    widget.owner.disposed++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      const SizedBox.expand(key: ValueKey('fake-player'));
}
