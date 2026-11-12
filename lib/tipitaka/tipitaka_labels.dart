/// English interface labels for the top two levels (not source text).
const tipitakaEnglishLabels = {
  'vp': 'Vinaya Pitaka', 'sp': 'Sutta Pitaka', 'ap': 'Abhidhamma Pitaka',
  'dn': 'Digha Nikaya', 'mn': 'Majjhima Nikaya', 'sn': 'Samyutta Nikaya',
  'an': 'Anguttara Nikaya', 'kn': 'Khuddaka Nikaya',
};

String textsLabel(int count) => count == 1 ? '1 text' : '$count texts';

/// The Tripitaka tab's page title (an interface label, as the design gives
/// it) and the caption under it.
const tipitakaPageTitle = 'ත්‍රිපිටකය';
const tipitakaPageCaption = 'Tripitaka';

/// Between the names of a path.
const tipitakaPathSeparator = ' › ';
