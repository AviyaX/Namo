import '../content/model.dart';
import 'flows.dart';

/// Joins a reading id to a section or verse id inside a flow's reading, so
/// that ids repeated across readings (every pirith's section is `p`) stay
/// apart. No content id contains it.
const flowIdSeparator = '~';

/// `<readingId>~<sectionId>`.
String flowSectionId(FlowRef ref) =>
    '${ref.readingId}$flowIdSeparator${ref.sectionId}';

/// The inverse of [flowSectionId]; null without a separator.
FlowRef? refOfFlowSection(String flowSectionId) {
  final at = flowSectionId.indexOf(flowIdSeparator);
  if (at < 0) return null;
  return FlowRef(
    readingId: flowSectionId.substring(0, at),
    sectionId: flowSectionId.substring(at + flowIdSeparator.length),
  );
}

Section? _sectionOf(FlowRef ref, Library library) {
  final reading = library.reading(ref.readingId);
  if (reading == null) return null;
  for (final s in reading.sections) {
    if (s.id == ref.sectionId) return s;
  }
  return null;
}

/// The refs of [flow] whose section the library still has, in flow order.
List<FlowRef> liveRefs(Flow flow, Library library) => [
  for (final ref in flow.sections)
    if (_sectionOf(ref, library) != null) ref,
];

/// The flow as a reading: id = flow.id, title = flow.name, no audio, no Roman
/// title; one Section per live ref — id flowSectionId(ref), number 1, 2, 3 …,
/// the original's heading, source, check and corrections, and its verses with
/// ids `<readingId>~<verseId>`.
Reading flowReading(Flow flow, Library library) {
  final sections = <Section>[];
  for (final ref in flow.sections) {
    final original = _sectionOf(ref, library);
    if (original == null) continue;
    sections.add(
      Section(
        id: flowSectionId(ref),
        number: sections.length + 1,
        heading: original.heading,
        source: original.source,
        check: original.check,
        corrections: original.corrections,
        verses: List.unmodifiable([
          for (final v in original.verses)
            v.withId('${ref.readingId}$flowIdSeparator${v.id}'),
        ]),
      ),
    );
  }
  return Reading(
    id: flow.id,
    title: flow.name,
    sections: List.unmodifiable(sections),
  );
}

/// A content reading, or a flow as a reading; null when neither exists. A
/// flow with no live sections is still a reading, with no sections.
Reading? resolveReading(Library library, FlowsState flows, String id) {
  if (isFlowId(id)) {
    final flow = flows.flow(id);
    return flow == null ? null : flowReading(flow, library);
  }
  return library.reading(id);
}
