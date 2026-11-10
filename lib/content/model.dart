class Section {
  const Section({required this.id, required this.number, required this.heading});

  factory Section.fromJson(Map<String, dynamic> json) => Section(
        id: json['id'] as String,
        number: json['number'] as int,
        heading: json['heading'] as String,
      );

  final String id;
  final int number;
  final String heading;
}

class Reading {
  const Reading({required this.id, required this.title, required this.sections});

  factory Reading.fromJson(Map<String, dynamic> json) => Reading(
        id: json['id'] as String,
        title: json['title'] as String,
        sections: [
          for (final s in json['sections'] as List)
            Section.fromJson(s as Map<String, dynamic>),
        ],
      );

  final String id;
  final String title;
  final List<Section> sections;
}

class Category {
  const Category({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.readings,
  });

  factory Category.fromJson(Map<String, dynamic> json) => Category(
        id: json['id'] as String,
        title: json['title'] as String,
        subtitle: json['subtitle'] as String,
        readings: [
          for (final r in json['readings'] as List)
            Reading.fromJson(r as Map<String, dynamic>),
        ],
      );

  final String id;
  final String title;
  final String subtitle;
  final List<Reading> readings;
}

class Library {
  const Library({required this.categories});

  factory Library.fromJson(Map<String, dynamic> json) => Library(
        categories: [
          for (final c in json['categories'] as List)
            Category.fromJson(c as Map<String, dynamic>),
        ],
      );

  final List<Category> categories;

  Reading? reading(String id) {
    for (final c in categories) {
      for (final r in c.readings) {
        if (r.id == id) return r;
      }
    }
    return null;
  }

  Category? categoryOf(String readingId) {
    for (final c in categories) {
      if (c.readings.any((r) => r.id == readingId)) return c;
    }
    return null;
  }

  Category? category(String id) {
    for (final c in categories) {
      if (c.id == id) return c;
    }
    return null;
  }
}
