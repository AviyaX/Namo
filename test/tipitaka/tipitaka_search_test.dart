import 'package:buddhist_gatha/tipitaka/tipitaka_repository.dart';
import 'package:buddhist_gatha/tipitaka/tipitaka_search.dart';
import 'package:buddhist_gatha/tipitaka/tipitaka_tree.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'tipitaka_support.dart';

// Sinhala-script building blocks, as code points (made-up syllables only).
const _ka = 0x0D9A, _kha = 0x0D9B, _ga = 0x0D9C, _ca = 0x0DA0, _cha = 0x0DA1;
const _tta = 0x0DA7, _ta = 0x0DAD, _na = 0x0DB1, _nna = 0x0DAB;
const _ma = 0x0DB8, _ra = 0x0DBB, _lla = 0x0DC5;
const _hal = 0x0DCA, _aaSign = 0x0DCF, _iiSign = 0x0DD3, _uSign = 0x0DD4;
const _eSign = 0x0DD9, _anusvara = 0x0D82, _zwj = 0x200D, _zwnj = 0x200C;
const _indepA = 0x0D85, _indepI = 0x0D87;

String _s(List<int> codePoints) => String.fromCharCodes(codePoints);

void main() {
  group('foldName', () {
    test('drops joiners, spaces and punctuation, keeps letters and digits', () {
      final withJoiner = _s([_ka, _hal, _zwj, _ra, _aaSign, 0x20, 0x31, 0x2E]);
      expect(foldName(withJoiner), _s([_ka, _hal, _ra, _aaSign, 0x31]));
      expect(foldName(_s([_ka, _zwnj, _hal])), _s([_ka, _hal]));
      expect(foldName(' A-b, C.2 '), 'abc2');
      expect(foldName('   '), '');
      expect(foldName('...'), '');
    });
  });

  group('latinKey', () {
    test('consonants take a, hal removes it, vowel signs replace it', () {
      expect(latinKey(_s([_ka, _ta])), 'kata');
      expect(latinKey(_s([_ka, _hal, _ta])), 'kta');
      expect(latinKey(_s([_ka, _aaSign])), 'ka');
      expect(latinKey(_s([_ka, _iiSign, _ta, _uSign])), 'kitu');
      expect(latinKey(_s([_ka, _eSign])), 'ke');
      expect(latinKey(_s([_ka, _eSign, _aaSign])), 'ko');
    });

    test('aspirates, retroflex/dental and nasals fold', () {
      expect(latinKey(_s([_kha, _hal])), 'kh');
      expect(latinKey(_s([_ga, _cha])), 'gacha');
      expect(latinKey(_s([_ca])), 'ca');
      expect(latinKey(_s([_tta, _ta])), 'tata');
      expect(latinKey(_s([_nna, _na])), 'nana');
      expect(latinKey(_s([_lla])), 'la');
      expect(latinKey(_s([_ma, _anusvara])), 'mam');
    });

    test('independent vowels, joiners and unknown characters', () {
      expect(latinKey(_s([_indepA, _indepI])), 'ai');
      expect(latinKey(_s([_ka, _hal, _zwj, _ra])), 'kra');
      expect(latinKey('x 1.-'), '');
    });
  });

  group('foldLatinQuery', () {
    test('diacritics off, long vowels short, lower case, a-z only', () {
      expect(foldLatinQuery('Brahmajāla Sutta'), 'brahmajalasutta');
      expect(foldLatinQuery('SatipaṭṭhĀna'), 'satipatthana');
      expect(foldLatinQuery('Dhammacakkappavattana-sutta 1'),
          'dhammacakkappavattanasutta');
      expect(foldLatinQuery('Saṃyutta ñāṇa'), 'samyuttanana');
      expect(foldLatinQuery('jaala'), 'jala');
      expect(foldLatinQuery('  123 '), '');
    });
  });

  group('real data', () {
    final repo = TipitakaRepository(load: diskAssets());
    late TipitakaTree tree;
    late TipitakaSearchIndex index;

    setUpAll(() async {
      tree = await repo.tree();
      index = TipitakaSearchIndex(tree);
    });

    test('brahmajala finds dn-1-1 first or among the first five', () {
      final keys = index.find('brahmajala').map((n) => n.key).toList();
      expect(keys.take(5), contains('dn-1-1'));
    });

    test('typing the first 6 code units of a real Sinhala name finds it', () {
      final node = tree.node('dn-1-1')!;
      expect(node.sinhala.length, greaterThan(6));
      final found = index.find(node.sinhala.substring(0, 6), limit: 100000);
      expect(found.map((n) => n.key), contains('dn-1-1'));
    });

    test('a Pali name with joiners removed and with joiners added both find it',
        () {
      final node = tree.readings
          .map((k) => tree.node(k)!)
          .firstWhere((n) => n.pali.contains(_s([_hal])));
      final stripped = node.pali.replaceAll(_s([_zwj]), '');
      final added = node.pali.replaceAll(_s([_hal]), _s([_hal, _zwj]));
      expect(added, isNot(node.pali));
      for (final q in [stripped, added]) {
        final found = index.find(q, limit: 100000).map((n) => n.key);
        expect(found, contains(node.key));
      }
    });

    test('whole-name matches come before starts-with before contains', () {
      final node = tree.node('dn-1-1')!;
      final found = index.find(node.pali, limit: 100000);
      expect(found.first.pali, node.pali);
    });

    test('blank and punctuation-only queries give no results', () {
      expect(index.find('   '), isEmpty);
      expect(index.find('...'), isEmpty);
      expect(index.find(''), isEmpty);
    });

    test('a 500-letter query gives no results and does not throw', () {
      expect(index.find('sutta' * 100), isEmpty);
      expect(index.find(_s(List.filled(500, _ka))), isEmpty);
    });

    test('limit is honoured', () {
      expect(index.find('sutta', limit: 7), hasLength(7));
      expect(index.find('sutta', limit: 3), hasLength(3));
      expect(index.find('sutta', limit: 0), isEmpty);
    });

    test('results never include atta or anya nodes', () {
      for (final q in ['sutta', 'atthakatha', 'anya', 'a']) {
        for (final n in index.find(q, limit: 100000)) {
          expect(n.key.startsWith('atta') || n.key.startsWith('anya'), isFalse);
        }
      }
    });
  });

  group('provider', () {
    test('tipitakaSearchProvider builds an index from the tree', () async {
      final c = ProviderContainer(overrides: [
        tipitakaRepositoryProvider.overrideWithValue(
            TipitakaRepository(load: diskAssets())),
      ]);
      addTearDown(c.dispose);
      final index = await c.read(tipitakaSearchProvider.future);
      expect(index.find('brahmajala'), isNotEmpty);
    });
  });
}
