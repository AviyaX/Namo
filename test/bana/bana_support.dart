import 'dart:convert';

import 'package:buddhist_gatha/bana/bana_catalogue.dart';
import 'package:buddhist_gatha/bana/bana_repository.dart';
import 'package:flutter_riverpod/misc.dart';

/// Two monks: Alpha has a series (three parts, topic M) and a single on M;
/// Beta has one single on K.
String madeUpList() => jsonEncode({
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
        'embeddable': true,
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
  @override
  Future<BanaCatalogue> build() async => BanaCatalogue.parse(madeUpList())!;
}

List<Override> banaOverrides() => [
  banaCatalogueProvider.overrideWith(_Fixed.new),
];
