/// The Tripitaka tree: every in-scope node of the source's tree.json, its
/// children, and which nodes are readings (see the design's "What a reading
/// is").
library;

/// One node of the tree, as the source gives it.
class TipitakaNode {
  const TipitakaNode({
    required this.key,
    required this.pali,
    required this.sinhala,
    required this.file,
    required this.level,
    required this.page,
    required this.entry,
    required this.parent,
  });

  final String key, pali, sinhala, file;

  /// [page] and [entry] are indexes into the book file, from the tree.
  final int level, page, entry;

  /// Null for the roots.
  final String? parent;
}

class TipitakaTree {
  TipitakaTree._(
    this._nodes,
    this._children,
    this._readings,
    this._readingIndex,
    this._readingCounts,
    this._byFile,
  );

  /// [json] is the decoded tree.json. Skips keys starting 'atta' or 'anya'
  /// and any value of the wrong shape. Never throws on bad data.
  factory TipitakaTree.parse(Object? json,
      {required Set<String> parentsWithText}) {
    final raw = <String, _Raw>{};
    if (json is Map) {
      for (final MapEntry(:key, :value) in json.entries) {
        if (key is! String || key.startsWith('atta') || key.startsWith('anya')) {
          continue;
        }
        final parsed = _Raw.parse(key, value);
        if (parsed != null) raw[key] = parsed;
      }
    }

    // Insertion index keeps sorting stable for equal trailing numbers.
    final insertion = <String, int>{};
    for (final key in raw.keys) {
      insertion[key] = insertion.length;
    }

    final nodes = <String, TipitakaNode>{};
    final children = <String, List<String>>{};
    final orphans = <String>[];
    for (final r in raw.values) {
      final parent = raw.containsKey(r.parent) && r.parent != r.key
          ? r.parent
          : null;
      nodes[r.key] = TipitakaNode(
        key: r.key,
        pali: r.pali,
        sinhala: r.sinhala,
        file: r.file,
        level: r.level,
        page: r.page,
        entry: r.entry,
        parent: parent,
      );
      if (parent == null) {
        orphans.add(r.key);
      } else {
        (children[parent] ??= []).add(r.key);
      }
    }
    int byNumber(String a, String b) {
      final c = _childOrder(a).compareTo(_childOrder(b));
      return c != 0 ? c : insertion[a]!.compareTo(insertion[b]!);
    }

    for (final list in children.values) {
      list.sort(byNumber);
    }

    // Roots: the three pitakas first, then any other node without a parent.
    final rootKeys = [
      for (final r in roots)
        if (nodes.containsKey(r) && nodes[r]!.parent == null) r,
      for (final k in orphans)
        if (!roots.contains(k)) k,
    ];

    // Depth-first walk: tree order, readings and reading counts.
    final order = <String>[];
    final readings = <String>[];
    final counts = <String, int>{};
    final visited = <String>{};
    int walk(String key) {
      visited.add(key);
      order.add(key);
      final kids = children[key];
      final isLeaf = kids == null;
      var count = 0;
      if (isLeaf || parentsWithText.contains(key)) {
        readings.add(key);
        count = 1;
      }
      if (kids != null) {
        for (final kid in kids) {
          if (!visited.contains(kid)) count += walk(kid);
        }
      }
      counts[key] = count;
      return count;
    }

    for (final root in rootKeys) {
      walk(root);
    }

    final rank = {for (var i = 0; i < order.length; i++) order[i]: i};
    final byFile = <String, List<TipitakaNode>>{};
    for (final key in order) {
      final node = nodes[key]!;
      (byFile[node.file] ??= []).add(node);
    }
    for (final list in byFile.values) {
      list.sort((a, b) {
        var c = a.page.compareTo(b.page);
        if (c == 0) c = a.entry.compareTo(b.entry);
        if (c == 0) c = rank[a.key]!.compareTo(rank[b.key]!);
        return c;
      });
    }

    return TipitakaTree._(
      nodes,
      children,
      readings,
      {for (var i = 0; i < readings.length; i++) readings[i]: i},
      counts,
      byFile,
    );
  }

  static const roots = ['vp', 'sp', 'ap'];

  final Map<String, TipitakaNode> _nodes;
  final Map<String, List<String>> _children;
  final List<String> _readings;
  final Map<String, int> _readingIndex;
  final Map<String, int> _readingCounts;
  final Map<String, List<TipitakaNode>> _byFile;

  TipitakaNode? node(String key) => _nodes[key];

  /// Ordered by the number ending the key.
  List<TipitakaNode> children(String key) =>
      [for (final k in _children[key] ?? const <String>[]) _nodes[k]!];

  bool isLeaf(String key) =>
      _nodes.containsKey(key) && !_children.containsKey(key);

  /// A leaf, or a parent listed as having text of its own (and reachable
  /// from a root).
  bool isReading(String key) => _readingIndex.containsKey(key);

  /// Readings at or under the node.
  int readingCount(String key) => _readingCounts[key] ?? 0;

  /// Root first, the node itself excluded.
  List<TipitakaNode> ancestors(String key) {
    final out = <TipitakaNode>[];
    final seen = <String>{key};
    var parent = _nodes[key]?.parent;
    while (parent != null && seen.add(parent)) {
      final node = _nodes[parent];
      if (node == null) break;
      out.add(node);
      parent = node.parent;
    }
    return out.reversed.toList();
  }

  /// Every reading, in tree order.
  List<String> get readings => List.unmodifiable(_readings);

  String? previousReading(String key) {
    final i = _readingIndex[key];
    return i == null || i == 0 ? null : _readings[i - 1];
  }

  String? nextReading(String key) {
    final i = _readingIndex[key];
    return i == null || i + 1 >= _readings.length ? null : _readings[i + 1];
  }

  /// The nodes whose text is in [file], by position (page, entry), ties in
  /// tree order.
  List<TipitakaNode> nodesInFile(String file) =>
      List.unmodifiable(_byFile[file] ?? const <TipitakaNode>[]);
}

int _childOrder(String key) {
  final tail = key.substring(key.lastIndexOf('-') + 1);
  return _digits.hasMatch(tail) ? int.parse(tail) : 0;
}

final _digits = RegExp(r'^[0-9]{1,15}$');

class _Raw {
  _Raw(this.key, this.pali, this.sinhala, this.level, this.page, this.entry,
      this.parent, this.file);

  final String key, pali, sinhala, parent, file;
  final int level, page, entry;

  /// `[paliName, sinhalaName, level, [pageIndex, entryIndex], parentKey,
  /// fileName]`, or null when [value] has another shape.
  static _Raw? parse(String key, Object? value) {
    if (value is! List || value.length < 6) return null;
    final [pali, sinhala, level, position, parent, file, ...] = value;
    if (pali is! String ||
        sinhala is! String ||
        level is! int ||
        position is! List ||
        position.length < 2 ||
        parent is! String ||
        file is! String) {
      return null;
    }
    final [page, entry, ...] = position;
    if (page is! int || entry is! int) return null;
    return _Raw(key, pali, sinhala, level, page, entry, parent, file);
  }
}
