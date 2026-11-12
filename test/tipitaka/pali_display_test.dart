import 'dart:convert';
import 'dart:io';

import 'package:buddhist_gatha/tipitaka/pali_display.dart';
import 'package:flutter_test/flutter_test.dart';

List<Map<String, dynamic>> _cases(String lang) {
  final all = jsonDecode(
          File('test/fixtures/tipitaka/beautify_cases.json').readAsStringSync())
      as List;
  return [
    for (final c in all)
      if (c['lang'] == lang) c as Map<String, dynamic>
  ];
}

String _noZwj(String s) => s.replaceAll('‍', '');

void main() {
  test('every pali vector in beautify_cases.json gives the source\'s output',
      () {
    final cases = _cases('pali');
    expect(cases, isNotEmpty);
    for (final c in cases) {
      expect(paliForDisplay(c['text'] as String), c['out'], reason: c['text']);
    }
  });

  test('sinh vectors show the source leaves Sinhala unchanged', () {
    final cases = _cases('sinh');
    expect(cases, isNotEmpty);
    for (final c in cases) {
      expect(c['out'], c['text']);
    }
  });

  test('paliForDisplay removes nothing', () {
    for (final c in _cases('pali')) {
      expect(_noZwj(paliForDisplay(c['text'] as String)),
          _noZwj(c['text'] as String));
    }
  });

  test('paliForDisplay joins hal+ya and hal+ra and the common pairs', () {
    const hal = '්';
    const zwj = '‍';
    const ya = 'ය';
    const ra = 'ර';
    expect(paliForDisplay('ක$hal$ya'), 'ක$hal$zwj$ya');
    expect(paliForDisplay('ක$hal$ra'), 'ක$hal$zwj$ra');
    expect(paliForDisplay('ත$halථ'), 'ත$hal$zwjථ');
    expect(paliForDisplay('abc'), 'abc');
  });

  test('tipitakaForDisplay maps U+05F4 to a plain quote and nothing else', () {
    const g = '״';
    expect(tipitakaForDisplay('a${g}b$g'), 'a"b"');
    final sinhala = 'ක්‍ර$gත';
    expect(tipitakaForDisplay(sinhala), 'ක්‍ර"ත');
    const ascii = 'plain "text" 123 ‍';
    expect(tipitakaForDisplay(ascii), ascii);
    expect(tipitakaForDisplay(''), '');
  });
}
