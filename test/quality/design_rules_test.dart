import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The standing design rules, checked on the source text under lib/.
///
/// These are read as text on purpose: a rule such as "no raw colour outside
/// the tokens" has to hold for code no test happens to draw.

class _Source {
  _Source(this.path, String raw)
    : text = _stripComments(raw);

  /// Forward slashes, relative to the project root: lib/design/tokens.dart.
  final String path;
  final String text;
}

/// Line comments blanked, so a rule is not tripped by a sentence that names
/// what it forbids. Strings are left alone.
String _stripComments(String s) =>
    s.split('\n').map((l) {
      final i = l.indexOf('//');
      if (i < 0) return l;
      // A '//' inside a string literal (a URL) is not a comment.
      final before = l.substring(0, i);
      final quotes = "'".allMatches(before).length + '"'.allMatches(before).length;
      return quotes.isOdd ? l : before;
    }).join('\n');

List<_Source> _sources() => [
  for (final f in Directory('lib').listSync(recursive: true))
    if (f is File && f.path.endsWith('.dart'))
      _Source(f.path.replaceAll(r'\', '/'), f.readAsStringSync()),
];

List<String> _hits(
  bool Function(_Source) where,
  RegExp pattern, {
  bool Function(_Source, RegExpMatch)? skip,
}) => [
  for (final s in _sources())
    if (where(s))
      for (final m in pattern.allMatches(s.text))
        if (skip == null || !skip(s, m))
          '${s.path}: ${m.group(0)}',
];

bool _anywhere(_Source s) => true;
bool _outsideTokens(_Source s) => s.path != 'lib/design/tokens.dart';

/// The text of the call whose opening bracket is at [open] in [s].
String _call(String s, int open) {
  var depth = 0;
  for (var i = open; i < s.length; i++) {
    if (s[i] == '(') depth++;
    if (s[i] == ')' && --depth == 0) return s.substring(open, i + 1);
  }
  return s.substring(open);
}

void main() {
  test('no raw colour value outside lib/design/tokens.dart', () {
    final found = _hits(
      _outsideTokens,
      RegExp(r'Color\(0x|Color\.fromARGB|Color\.fromRGBO|Colors\.(?!transparent\b)\w+'),
    );
    expect(found, isEmpty, reason: found.join('\n'));
  });

  test('textMuted is referenced only inside lib/design/', () {
    final found = _hits(
      (s) => !s.path.startsWith('lib/design/'),
      RegExp(r'\btextMuted\b'),
    );
    expect(found, isEmpty, reason: found.join('\n'));
  });

  test('the old palette names are gone', () {
    expect(_hits(_anywhere, RegExp(r'\bNamoColors\b')), isEmpty);
    final tokens = File('lib/design/tokens.dart').readAsStringSync();
    for (final name in ['divider', 'textQuiet', 'heading', 'accent', 'focus']) {
      expect(
        RegExp('Color get $name' r'\b').hasMatch(tokens),
        isFalse,
        reason: 'NamoPalette still has a getter called $name',
      );
    }
    // A palette is read as p.<role>, palette.<role> or NamoPalette.of(..).<role>.
    final found = _hits(
      _anywhere,
      RegExp(r'\b(?:p|palette|colors)\.(?:divider|textQuiet|heading|accent|focus)\b'
          r'|NamoPalette\.of\([^)]*\)\.(?:divider|textQuiet|heading|accent|focus)\b'),
    );
    expect(found, isEmpty, reason: found.join('\n'));
  });

  test("Material's default widgets are not used", () {
    final found = _hits(
      _anywhere,
      RegExp(
        r'\bCard\(|\bElevatedButton\b|\bDropdownButton\b|\bNavigationBar\(|'
        r'\bNavigationRail\(|\bSwitchListTile\b|\bListTile\(',
      ),
    );
    expect(found, isEmpty, reason: found.join('\n'));
  });

  test('type sizes come from NamoType: no size: for namoText, no fontSize below 12',
      () {
    // lib/design/typography.dart defines the scale: its NamoType entries and
    // the shared helper are the only places a size is written.
    final sizeArgs = <String>[];
    for (final s in _sources()) {
      if (s.path == 'lib/design/typography.dart') continue;
      for (final m in RegExp(r'\bnamoText\(').allMatches(s.text)) {
        final call = _call(s.text, m.end - 1);
        if (RegExp(r'\bsize:').hasMatch(call)) {
          sizeArgs.add('${s.path}: ${call.split('\n').first}');
        }
      }
    }
    expect(sizeArgs, isEmpty, reason: sizeArgs.join('\n'));

    final small = _hits(
      _anywhere,
      RegExp(r'\bfontSize:\s*(\d+(?:\.\d+)?)'),
      skip: (s, m) => double.parse(m.group(1)!) >= 12,
    );
    expect(small, isEmpty, reason: small.join('\n'));
  });

  test('every Duration(milliseconds: ...) outside the tokens is allow-listed',
      () {
    // Motion durations come from NamoMotion. These are not motion: they are
    // timers of behaviour, each with its reason.
    const allowed = {
      'lib/reader/auto_scroll.dart':
          'the longest step of the auto-scroll tick, so a stalled frame does '
              'not make the page jump',
      'lib/reader/reader_screen.dart':
          'the position-save debounce (400 ms) and the longest wait while '
              'moving (2500 ms); neither is drawn',
      'lib/tipitaka/tipitaka_reader_screen.dart':
          'the place-save throttle (400 ms) while scrolling; not drawn',
    };
    final found = _hits(
      (s) => _outsideTokens(s) && !allowed.containsKey(s.path),
      RegExp(r'Duration\(\s*milliseconds:'),
    );
    expect(found, isEmpty, reason: found.join('\n'));
    // An allow-list entry that no longer matches anything is removed.
    for (final path in allowed.keys) {
      expect(
        RegExp(r'Duration\(\s*milliseconds:')
            .hasMatch(File(path).readAsStringSync()),
        isTrue,
        reason: '$path no longer needs its allow-list entry',
      );
    }
  });
}
