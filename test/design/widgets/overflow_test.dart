import 'package:buddhist_gatha/design/widgets/buttons.dart';
import 'package:buddhist_gatha/design/widgets/empty_state.dart';
import 'package:buddhist_gatha/design/widgets/floating_bar.dart';
import 'package:buddhist_gatha/design/widgets/list_row.dart';
import 'package:buddhist_gatha/design/widgets/namo_page.dart';
import 'package:buddhist_gatha/design/widgets/page_header.dart';
import 'package:buddhist_gatha/design/widgets/progress_line.dart';
import 'package:buddhist_gatha/design/widgets/surface_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'widget_support.dart';

const _long = 'A fairly long label that has to wrap';

void main() {
  final cases = <String, Widget Function()>{
    'NamoIconButton': () => NamoIconButton(
        icon: Symbols.arrow_back_rounded, tooltip: 'Back', onPressed: () {}),
    'PrimaryButton': () =>
        PrimaryButton(label: _long, icon: Symbols.play_arrow_rounded, onPressed: () {}),
    'QuietButton': () => QuietButton(label: _long, onPressed: () {}),
    'TextAction': () =>
        TextAction(label: _long, icon: Symbols.arrow_forward_rounded, onPressed: () {}),
    'PageHeader': () => const PageHeader(
        title: _long, caption: _long, trailing: Icon(Icons.add)),
    'Overline': () => const Overline(_long),
    'SurfaceCard': () => SurfaceCard(
        onTap: () {}, leadingLine: Colors.transparent, child: const Text(_long)),
    'ProgressLine': () => const ProgressLine(value: 0.5),
    'EmptyState': () => EmptyState(
        icon: Symbols.bookmark_rounded,
        title: _long,
        message: _long,
        actionLabel: _long,
        onAction: () {}),
    'FloatingBar': () => const FloatingBar(child: Text(_long)),
    'ListRow': () => ListRow(
        title: _long,
        subtitle: _long,
        caption: _long,
        number: 12,
        leading: const Icon(Icons.add),
        trailing: const Icon(Icons.add),
        onTap: () {}),
    'NamoPage': () => const NamoPage(children: [Text(_long), PageHeader(title: _long)]),
  };

  for (final b in Brightness.values) {
    for (final e in cases.entries) {
      testWidgets('${e.key} fits 320 wide at 2x text ($b)', (t) async {
        await pumpThemed(
          t,
          e.key == 'NamoPage'
              ? SizedBox(width: 320, height: 800, child: e.value())
              : SizedBox(
                  width: 320,
                  height: 800,
                  child: SingleChildScrollView(child: e.value()),
                ),
          brightness: b,
          size: const Size(320, 800),
          textScale: 2,
        );
        expect(t.takeException(), isNull);
      });
    }
  }
}
