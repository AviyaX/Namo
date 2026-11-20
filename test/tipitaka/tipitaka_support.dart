import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:buddhist_gatha/tipitaka/tipitaka_repository.dart';

/// Reads the real shipped files under the project folder (tests run with the
/// project root as the working directory).
AssetBytes diskAssets() =>
    (path) async => Uint8List.fromList(await File(path).readAsBytes());

/// Serves [jsonByPath] as asset bytes. Paths ending `.gz` are gzipped when
/// [gzip] is true; otherwise every value is served as plain JSON.
AssetBytes fakeAssets(Map<String, Object> jsonByPath, {bool gzip = true}) {
  return (path) async {
    final value = jsonByPath[path];
    if (value == null) throw StateError('no asset $path');
    final plain = Uint8List.fromList(utf8.encode(jsonEncode(value)));
    if (gzip && path.endsWith('.gz')) {
      return Uint8List.fromList(GZipEncoder().encodeBytes(plain));
    }
    return plain;
  };
}

const tinyManifestPath = 'assets/tipitaka/manifest.json';
const tinyTreePath = 'assets/tipitaka/tree.json.gz';
String tinyBookPath(String file) => 'assets/tipitaka/text/$file.json.gz';

Map<String, Object> _e(String type, String text, [int? level]) => {
  'type': type,
  'text': text,
  'level': ?level,
};

List<Object> _node(String name, int level, int page, int entry, String parent,
        String file) =>
    ['P $name', 'S $name', level, [page, entry], parent, file];

/// The made-up tree of [tinyTipitaka] (decoded tree.json).
Map<String, Object> tinyTree() => {
  // Inserted out of order on purpose: children sort by the trailing number.
  'vp-2-10': _node('ten', 1, 2, 2, 'vp-2', 'vp-a'),
  'vp': _node('vp', 7, 0, 1, 'root', 'vp-a'),
  'vp-1': _node('one', 3, 0, 2, 'vp', 'vp-a'),
  'vp-1-1': _node('one one', 1, 0, 3, 'vp-1', 'vp-a'),
  'vp-2': _node('two', 3, 1, 0, 'vp', 'vp-a'),
  'vp-2-1': _node('two one', 1, 1, 2, 'vp-2', 'vp-a'),
  'vp-2-2': _node('two two', 1, 2, 0, 'vp-2', 'vp-a'),
  'atta-vp-1': _node('atta', 1, 0, 3, 'vp', 'vp-a'),
  'anya-x': _node('anya', 1, 0, 0, 'root', 'vp-a'),
  'sp': _node('sp', 7, 0, 0, 'root', 'ap-b'),
  'sp-1': _node('sp one', 1, 0, 1, 'sp', 'ap-b'),
  'ap': _node('ap', 7, 1, 0, 'root', 'ap-b'),
  'ap-1': _node('ap one', 1, 1, 1, 'ap', 'ap-b'),
};

/// Book `vp-a`: Pali with Sinhala, footnotes, a blank Sinhala entry, an
/// unknown entry type and a page whose two lists differ in length.
Map<String, Object> tinyBookA() => {
  'filename': 'vp-a',
  'pages': [
    {
      'pageNum': 1,
      'pali': {
        'entries': [
          _e('centered', 'Title A', 2), // before the first node
          _e('heading', 'Root vp', 1), // vp
          _e('heading', 'Part one', 2), // vp-1
          _e('heading', 'Leaf one one', 3), // vp-1-1
          _e('paragraph', 'Leaf one text {1}'),
        ],
        'footnotes': [
          {'type': 'footnote', 'text': 'pali note one'},
        ],
      },
      'sinh': {
        'entries': [
          _e('centered', 's Title A', 2),
          _e('heading', 's Root vp', 1),
          _e('heading', 's Part one', 2),
          _e('heading', 's Leaf one one', 3),
          _e('paragraph', 's Leaf one text {1}'),
        ],
        'footnotes': ['sinh note one', 'sinh note two'],
      },
    },
    {
      'pageNum': 2,
      'pali': {
        'entries': [
          _e('heading', 'Part two', 2), // vp-2, a parent with text
          _e('paragraph', 'Part two intro'),
          _e('heading', 'Leaf two one', 3), // vp-2-1
          _e('gatha', 'verse line\nverse line'),
          _e('mystery', 'odd type'),
        ],
        'footnotes': [],
      },
      'sinh': {
        'entries': [
          _e('heading', 's Part two', 2),
          _e('paragraph', '   '),
          _e('heading', 's Leaf two one', 3),
          _e('gatha', 's verse'),
          _e('mystery', 's odd type'),
        ],
        'footnotes': [],
      },
    },
    {
      'pageNum': 3,
      'pali': {
        'entries': [
          _e('heading', 'Leaf two two', 3), // vp-2-2
          _e('paragraph', 'two two text'),
          _e('heading', 'Leaf two ten', 3), // vp-2-10
          _e('unindented', 'two ten text'),
        ],
        'footnotes': [],
      },
      'sinh': {
        'entries': [
          _e('heading', 's Leaf two two', 3),
        ],
        'footnotes': [],
      },
    },
  ],
};

/// Book `ap-b`: Pali only (empty Sinhala lists), two roots in one file.
Map<String, Object> tinyBookB() => {
  'filename': 'ap-b',
  'pages': [
    {
      'pageNum': 1,
      'pali': {
        'entries': [
          _e('heading', 'Root sp', 1), // sp
          _e('heading', 'Sp one', 3), // sp-1
          _e('paragraph', 'sp one text'),
        ],
        'footnotes': [],
      },
      'sinh': {'entries': [], 'footnotes': []},
    },
    {
      'pageNum': 2,
      'pali': {
        'entries': [
          _e('heading', 'Root ap', 1), // ap
          _e('heading', 'Ap one', 3), // ap-1
          _e('paragraph', 'ap one text'),
        ],
        'footnotes': [],
      },
      'sinh': {'entries': [], 'footnotes': []},
    },
  ],
};

const tinyParentsWithText = {'vp-2'};

/// A made-up Tipitaka: manifest, tree and two books, by asset path.
Map<String, Object> tinyTipitaka() => {
  tinyManifestPath: {
    'schema': 1,
    'source': 'https://example.invalid/tiny',
    'commit': 'abc123',
    'commitDate': '2026-01-02',
    'licence': 'test',
    'readings': 7,
    'parentsWithText': tinyParentsWithText.toList(),
    'files': <String, Object>{},
  },
  tinyTreePath: tinyTree(),
  tinyBookPath('vp-a'): tinyBookA(),
  tinyBookPath('ap-b'): tinyBookB(),
};
