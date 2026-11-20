// Draw-time text rules for the Tripitaka reader. The stored text is never
// changed; these work on copies.

const _zwj = '‍';
const _hal = '්';

/// Display substitutions for characters no bundled font draws. Keep in step
/// with DISPLAY_SUBSTITUTED in tools/check_tipitaka_glyphs.py.
const Map<String, String> _displaySubstitutions = {
  '״': '"', // Hebrew gershayim used as a closing quote in the source
};

/// Replaces characters no bundled font draws by their drawable stand-ins.
String tipitakaForDisplay(String text) {
  var out = text;
  _displaySubstitutions.forEach((from, to) => out = out.replaceAll(from, to));
  return out;
}

final _rakarYansa = RegExp('$_hal([යර])');

const _commonConjuncts = <(String, String)>[
  ('ක', 'ව'),
  ('ත', 'ථ'),
  ('ත', 'ව'),
  ('න', 'ථ'),
  ('න', 'ද'),
  ('න', 'ධ'),
];

/// Port of `beautifyText(text, 'pali', {bandiLetters: false,
/// specialLetters: false})` from the source's shared/beautify.ts.
String paliForDisplay(String text) {
  var out = text.replaceAllMapped(_rakarYansa, (m) => '$_hal$_zwj${m[1]}');
  for (final (a, b) in _commonConjuncts) {
    out = out.replaceAll('$a$_hal$b', '$a$_hal$_zwj$b');
  }
  return out;
}
