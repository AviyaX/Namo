import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../content/model.dart';
import '../reader/position_controller.dart';
import '../storage/key_value_store.dart';

const flowsKey = 'namo.flows.v1';
const flowIdPrefix = 'flow-';
const flowNameMax = 40;
const defaultFlowName = 'My flow';

bool isFlowId(String id) => id.startsWith(flowIdPrefix);

final _flowIdPattern = RegExp(r'^flow-([1-9][0-9]*)$');

@immutable
class FlowRef {
  const FlowRef({required this.readingId, required this.sectionId});

  final String readingId, sectionId;

  Map<String, dynamic> toJson() => {
    'readingId': readingId,
    'sectionId': sectionId,
  };

  static FlowRef? fromJson(Object? json) {
    if (json is! Map) return null;
    final readingId = json['readingId'], sectionId = json['sectionId'];
    if (readingId is! String || sectionId is! String) return null;
    return FlowRef(readingId: readingId, sectionId: sectionId);
  }

  @override
  bool operator ==(Object other) =>
      other is FlowRef &&
      other.readingId == readingId &&
      other.sectionId == sectionId;

  @override
  int get hashCode => Object.hash(readingId, sectionId);
}

@immutable
class Flow {
  const Flow({required this.id, required this.name, this.sections = const []});

  final String id, name;

  /// No repeats.
  final List<FlowRef> sections;

  @override
  bool operator ==(Object other) =>
      other is Flow &&
      other.id == id &&
      other.name == name &&
      listEquals(other.sections, sections);

  @override
  int get hashCode => Object.hash(id, name, Object.hashAll(sections));

  Flow _with({String? name, List<FlowRef>? sections}) => Flow(
    id: id,
    name: name ?? this.name,
    sections: List.unmodifiable(sections ?? this.sections),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'sections': [for (final s in sections) s.toJson()],
  };

  /// Null when the flow cannot be read; a section that cannot be read (or
  /// repeats an earlier one) is dropped alone.
  static Flow? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'], name = json['name'], raw = json['sections'];
    if (id is! String || name is! String) return null;
    final sections = <FlowRef>[];
    if (raw is List) {
      for (final r in raw) {
        final ref = FlowRef.fromJson(r);
        if (ref != null && !sections.contains(ref)) sections.add(ref);
      }
    }
    return Flow(id: id, name: name, sections: List.unmodifiable(sections));
  }
}

/// The user's flows in the order they were made, and the number the next one
/// gets (ids are never reused).
class FlowsState {
  const FlowsState({this.flows = const [], this.nextNumber = 1});

  final List<Flow> flows;
  final int nextNumber;

  Flow? flow(String id) {
    for (final f in flows) {
      if (f.id == id) return f;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
    'nextNumber': nextNumber,
    'flows': [for (final f in flows) f.toJson()],
  };

  /// Damaged data gives the empty state; within it, a flow that cannot be
  /// read, has an odd id or repeats an earlier id is dropped alone.
  factory FlowsState.fromJson(Object? json) {
    if (json is! Map) return const FlowsState();
    final raw = json['flows'], stored = json['nextNumber'];
    final flows = <Flow>[];
    final seen = <String>{};
    var next = stored is int && stored >= 1 ? stored : 1;
    if (raw is List) {
      for (final r in raw) {
        final f = Flow.fromJson(r);
        if (f == null) continue;
        final m = _flowIdPattern.firstMatch(f.id);
        if (m == null || !seen.add(f.id)) continue;
        flows.add(f);
        final n = int.tryParse(m.group(1)!);
        if (n != null && n >= next) next = n + 1;
      }
    }
    return FlowsState(flows: List.unmodifiable(flows), nextNumber: next);
  }
}

/// Trimmed, line breaks turned to spaces, cut to 40; empty gives "My flow",
/// "My flow 2" … (first not in [taken]).
String flowName(String raw, Iterable<String> taken) {
  var name = raw.trim().replaceAll(RegExp(r'\r\n|\r|\n'), ' ');
  if (name.length > flowNameMax) name = name.substring(0, flowNameMax);
  name = name.trim();
  if (name.isNotEmpty) return name;
  final used = taken.toSet();
  var candidate = defaultFlowName;
  for (var n = 2; used.contains(candidate); n++) {
    candidate = '$defaultFlowName $n';
  }
  return candidate;
}

/// "0 sections", "1 section", "N sections".
String sectionCount(int n) => n == 1 ? '1 section' : '$n sections';

class FlowsController extends Notifier<FlowsState> {
  @override
  FlowsState build() {
    final text = ref.read(keyValueStoreProvider).read(flowsKey);
    if (text == null) return const FlowsState();
    try {
      return FlowsState.fromJson(jsonDecode(text));
    } on FormatException {
      return const FlowsState();
    }
  }

  void _set(FlowsState next) {
    state = next;
    ref.read(keyValueStoreProvider).save(flowsKey, jsonEncode(next.toJson()));
  }

  void _change(Flow flow, Flow next) {
    _set(
      FlowsState(
        flows: List.unmodifiable([
          for (final f in state.flows) f.id == flow.id ? next : f,
        ]),
        nextNumber: state.nextNumber,
      ),
    );
  }

  Flow create(String rawName, {Reading? from}) {
    final flow = Flow(
      id: '$flowIdPrefix${state.nextNumber}',
      name: flowName(rawName, state.flows.map((f) => f.name)),
      sections: List.unmodifiable([
        if (from != null)
          for (final s in from.sections)
            FlowRef(readingId: from.id, sectionId: s.id),
      ]),
    );
    _set(
      FlowsState(
        flows: List.unmodifiable([...state.flows, flow]),
        nextNumber: state.nextNumber + 1,
      ),
    );
    return flow;
  }

  void rename(String id, String rawName) {
    final f = state.flow(id);
    if (f == null) return;
    final taken = state.flows.where((o) => o.id != id).map((o) => o.name);
    _change(f, f._with(name: flowName(rawName, taken)));
  }

  void delete(String id) {
    if (state.flow(id) == null) return;
    _set(
      FlowsState(
        flows: List.unmodifiable(state.flows.where((f) => f.id != id)),
        nextNumber: state.nextNumber,
      ),
    );
    ref.read(positionProvider.notifier).clear(id);
  }

  void add(String id, FlowRef ref) {
    final f = state.flow(id);
    if (f == null || f.sections.contains(ref)) return;
    _change(f, f._with(sections: [...f.sections, ref]));
  }

  void remove(String id, FlowRef ref) {
    final f = state.flow(id);
    if (f == null || !f.sections.contains(ref)) return;
    _change(f, f._with(sections: f.sections.where((s) => s != ref).toList()));
  }

  void insert(String id, int index, FlowRef ref) {
    final f = state.flow(id);
    if (f == null || f.sections.contains(ref)) return;
    final list = [...f.sections]
      ..insert(index.clamp(0, f.sections.length), ref);
    _change(f, f._with(sections: list));
  }

  /// [to] is the index the section ends up at.
  void move(String id, int from, int to) {
    final f = state.flow(id);
    if (f == null) return;
    final n = f.sections.length;
    if (from < 0 || from >= n || to < 0 || to >= n || from == to) return;
    final list = [...f.sections];
    list.insert(to, list.removeAt(from));
    _change(f, f._with(sections: list));
  }
}

final flowsProvider = NotifierProvider<FlowsController, FlowsState>(
  FlowsController.new,
);
