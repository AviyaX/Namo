enum ReadingLanguage {
  sinhala('si', 'Sinhala'),
  english('en', 'English'),
  pali('pi', 'Pali');

  const ReadingLanguage(this.code, this.label);

  final String code;
  final String label;

  static ReadingLanguage? fromCode(String code) {
    for (final l in values) {
      if (l.code == code) return l;
    }
    return null;
  }
}
