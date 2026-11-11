import 'dart:convert';

import 'package:buddhist_gatha/content/model.dart';
import 'package:buddhist_gatha/flows/flows.dart';
import 'package:buddhist_gatha/router.dart';
import 'package:buddhist_gatha/storage/key_value_store.dart';
import 'package:flutter/material.dart' hide Flow;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../quality/quality_support.dart';
import '../support/test_content.dart';

FlowRef ref(String readingId, String sectionId) =>
    FlowRef(readingId: readingId, sectionId: sectionId);

/// [testLibrary]'s category, then a second with a reading of two sections
/// and a reading of one section that has a Roman title. Placeholder text.
Library flowTestLibrary() => Library(
  categories: [
    testLibrary().categories.single,
    const Category(
      id: 'c2',
      title: 'category 2',
      subtitle: 'subtitle 2',
      readings: [
        Reading(
          id: 'r2',
          title: 'reading 2',
          sections: [
            Section(
              id: 's01',
              number: 1,
              heading: 'heading 2.1',
              verses: [Verse(id: 'r2-v1', paliSi: 'p1', sinhala: 's1')],
            ),
            Section(
              id: 's02',
              number: 2,
              heading: 'heading 2.2',
              verses: [Verse(id: 'r2-v2', paliSi: 'p2', sinhala: 's2')],
            ),
          ],
        ),
        Reading(
          id: 'r3',
          title: 'reading 3',
          titleRoman: 'roman 3',
          sections: [
            Section(
              id: 'p',
              number: 1,
              heading: 'heading 3',
              verses: [Verse(id: 'r3-v1', paliSi: 'p3', sinhala: 's3')],
            ),
          ],
        ),
      ],
    ),
  ],
);

/// The stored value of [flows] (id → sections), each named "Flow" and its number.
String storedFlows(Map<String, List<FlowRef>> flows) => jsonEncode(
  FlowsState(
    flows: [
      for (final e in flows.entries)
        Flow(id: e.key, name: 'Flow ${e.key.substring(5)}', sections: e.value),
    ],
    nextNumber: flows.length + 1,
  ).toJson(),
);

/// Opens the app at [location] with [flows] saved.
Future<ProviderContainer> openFlows(
  WidgetTester t,
  String location,
  Map<String, List<FlowRef>> flows, {
  Library? library,
  Size size = const Size(390, 844),
  double deviceTextScale = 1.0,
  bool? dark,
  Map<String, String> extras = const {},
  List<Override> overrides = const [],
}) async {
  await openReal(
    t,
    location,
    library: library ?? flowTestLibrary(),
    size: size,
    deviceTextScale: deviceTextScale,
    dark: dark,
    overrides: overrides,
    storeExtras: {flowsKey: storedFlows(flows), ...extras},
  );
  return ProviderScope.containerOf(t.element(find.byType(MaterialApp)));
}

String location(ProviderContainer c) =>
    c.read(routerProvider).routeInformationProvider.value.uri.toString();

/// The flow as the app holds it now.
Flow? heldFlow(ProviderContainer c, String id) => c.read(flowsProvider).flow(id);

/// The flow as it is written in storage now.
Flow? savedFlow(ProviderContainer c, String id) => FlowsState.fromJson(
  jsonDecode(c.read(keyValueStoreProvider).read(flowsKey)!),
).flow(id);
