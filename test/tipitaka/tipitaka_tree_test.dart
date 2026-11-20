import 'package:buddhist_gatha/tipitaka/tipitaka_tree.dart';
import 'package:flutter_test/flutter_test.dart';

import 'tipitaka_support.dart';

void main() {
  TipitakaTree tiny() =>
      TipitakaTree.parse(tinyTree(), parentsWithText: tinyParentsWithText);

  test('skips atta and anya keys', () {
    final tree = tiny();
    expect(tree.node('atta-vp-1'), isNull);
    expect(tree.node('anya-x'), isNull);
    expect(tree.children('vp').map((n) => n.key), ['vp-1', 'vp-2']);
  });

  test('reads the fields of a node', () {
    final n = tiny().node('vp-2-1')!;
    expect(n.key, 'vp-2-1');
    expect(n.pali, 'P two one');
    expect(n.sinhala, 'S two one');
    expect(n.level, 1);
    expect(n.page, 1);
    expect(n.entry, 2);
    expect(n.parent, 'vp-2');
    expect(n.file, 'vp-a');
  });

  test('children are ordered by the trailing number (2 before 10)', () {
    expect(tiny().children('vp-2').map((n) => n.key),
        ['vp-2-1', 'vp-2-2', 'vp-2-10']);
    expect(tiny().children('vp-1-1'), isEmpty);
    expect(tiny().children('nope'), isEmpty);
  });

  test('roots have no parent', () {
    final tree = tiny();
    for (final r in TipitakaTree.roots) {
      expect(tree.node(r)!.parent, isNull, reason: r);
    }
    expect(TipitakaTree.roots, ['vp', 'sp', 'ap']);
  });

  test('ancestors are root first', () {
    expect(tiny().ancestors('vp-2-10').map((n) => n.key), ['vp', 'vp-2']);
    expect(tiny().ancestors('vp'), isEmpty);
    expect(tiny().ancestors('nope'), isEmpty);
  });

  test('isReading is true for leaves and listed parents only', () {
    final tree = tiny();
    expect(tree.isLeaf('vp-1-1'), isTrue);
    expect(tree.isLeaf('vp-2'), isFalse);
    expect(tree.isReading('vp-1-1'), isTrue);
    expect(tree.isReading('vp-2'), isTrue);
    expect(tree.isReading('vp-1'), isFalse);
    expect(tree.isReading('vp'), isFalse);
    expect(tree.isReading('nope'), isFalse);
    expect(tree.isLeaf('nope'), isFalse);
  });

  test('readingCount sums the subtree', () {
    final tree = tiny();
    expect(tree.readingCount('vp'), 5);
    expect(tree.readingCount('vp-2'), 4);
    expect(tree.readingCount('vp-1'), 1);
    expect(tree.readingCount('vp-1-1'), 1);
    expect(tree.readingCount('sp'), 1);
    expect(tree.readingCount('nope'), 0);
  });

  test('readings are listed in tree order', () {
    expect(tiny().readings, [
      'vp-1-1', 'vp-2', 'vp-2-1', 'vp-2-2', 'vp-2-10', 'sp-1', 'ap-1', //
    ]);
  });

  test('previous and next reading follow tree order across files, null at the ends',
      () {
    final tree = tiny();
    expect(tree.previousReading('vp-1-1'), isNull);
    expect(tree.nextReading('vp-1-1'), 'vp-2');
    expect(tree.nextReading('vp-2-10'), 'sp-1');
    expect(tree.previousReading('sp-1'), 'vp-2-10');
    expect(tree.nextReading('ap-1'), isNull);
    expect(tree.nextReading('vp'), isNull);
    expect(tree.previousReading('nope'), isNull);
  });

  test('nodesInFile is in position order', () {
    expect(tiny().nodesInFile('vp-a').map((n) => n.key), [
      'vp', 'vp-1', 'vp-1-1', 'vp-2', 'vp-2-1', 'vp-2-2', 'vp-2-10', //
    ]);
    expect(tiny().nodesInFile('ap-b').map((n) => n.key),
        ['sp', 'sp-1', 'ap', 'ap-1']);
    expect(tiny().nodesInFile('none'), isEmpty);
  });

  test('bad shapes are skipped without throwing', () {
    expect(TipitakaTree.parse(null, parentsWithText: {}).readings, isEmpty);
    expect(TipitakaTree.parse([1, 2], parentsWithText: {}).readings, isEmpty);
    final tree = TipitakaTree.parse({
      'vp': ['a', 'b', 7, [0, 0], 'root', 'f'],
      'vp-1': ['a', 'b', 1], // three items
      'vp-2': ['a', 'b', 'x', [0, 1], 'vp', 'f'], // level not a number
      'vp-3': ['a', 'b', 1, [0], 'vp', 'f'], // position too short
      'vp-4': 'text',
      'vp-5': ['a', 'b', 1, [0, 2], 'vp', 'f'],
    }, parentsWithText: {'zz'});
    expect(tree.node('vp-1'), isNull);
    expect(tree.node('vp-2'), isNull);
    expect(tree.node('vp-3'), isNull);
    expect(tree.node('vp-4'), isNull);
    expect(tree.readings, ['vp-5']);
  });

  test('a parent cycle does not hang or throw', () {
    final tree = TipitakaTree.parse({
      'vp': ['a', 'b', 7, [0, 0], 'root', 'f'],
      'x-1': ['a', 'b', 1, [0, 1], 'x-2', 'f'],
      'x-2': ['a', 'b', 1, [0, 2], 'x-1', 'f'],
    }, parentsWithText: {});
    expect(tree.ancestors('x-1').length, lessThan(3));
    expect(tree.readings, ['vp']);
  });
}
