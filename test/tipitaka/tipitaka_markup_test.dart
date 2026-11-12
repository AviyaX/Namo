import 'dart:convert';
import 'dart:io';

import 'package:buddhist_gatha/tipitaka/tipitaka_markup.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every vector in markup_cases.json gives the source\'s html', () {
    final cases = jsonDecode(
            File('test/fixtures/tipitaka/markup_cases.json')
                .readAsStringSync()) as List;
    expect(cases, isNotEmpty);
    var passed = 0;
    for (final c in cases) {
      final input = c['input'] as String;
      expect(tokensToHtml(parseMarkup(input)), c['html'], reason: input);
      passed++;
    }
    expect(passed, cases.length);
  });

  test('unbalanced markers and a lone brace are literal text', () {
    for (final s in ['**open', 'a __ b', '{no close', '}x{', '{}', 'x ~~y']) {
      final tokens = parseMarkup(s);
      expect(tokens, hasLength(1), reason: s);
      expect((tokens.single as TextToken).text, s);
    }
  });

  test('parseMarkup of empty text is empty', () {
    expect(parseMarkup(''), isEmpty);
  });

  test('token shapes', () {
    final t = parseMarkup('a**b{1}**\n<hr/>');
    expect(t[0], isA<TextToken>());
    final span = t[1] as SpanToken;
    expect(span.kind, MarkupKind.bold);
    expect((span.children[1] as FootnoteRefToken).ref, '1');
    expect(t[2], isA<BreakToken>());
    expect(t[3], isA<RuleToken>());
  });

  test('parseFootnote', () {
    var f = parseFootnote('1. abc');
    expect((f.number, f.content), ('1', ' abc'));
    f = parseFootnote('a xyz');
    expect((f.number, f.content), ('a', 'xyz'));
    f = parseFootnote('nonumber');
    expect((f.number, f.content), ('', ''));
  });

  test('matchFootnote finds by number; null when absent', () {
    final notes = ['1. abc', '2 def', 'nonumber', '* star'];
    expect(matchFootnote('1', notes), 0);
    expect(matchFootnote('2', notes), 1);
    expect(matchFootnote('*', notes), 3);
    expect(matchFootnote('9', notes), isNull);
    expect(matchFootnote('', notes), isNull);
    expect(matchFootnote('1', const []), isNull);
  });
}
