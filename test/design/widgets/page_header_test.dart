import 'package:buddhist_gatha/design/tokens.dart';
import 'package:buddhist_gatha/design/widgets/page_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'widget_support.dart';

void main() {
  group('PageHeader', () {
    testWidgets('the title is a header; the caption is quiet', (t) async {
      final handle = t.ensureSemantics();
      await pumpThemed(t, const PageHeader(title: 'Title', caption: 'Caption'));
      final data = t.getSemantics(find.text('Title')).getSemanticsData();
      expect(data.flagsCollection.isHeader, isTrue);
      expect(t.widget<Text>(find.text('Title')).style!.color, NamoPalette.dark.text);
      expect(t.widget<Text>(find.text('Title')).style!.fontSize, 26);
      expect(t.widget<Text>(find.text('Caption')).style!.color, NamoPalette.dark.textSecondary);
      handle.dispose();
    });

    testWidgets('no caption when null; trailing shows', (t) async {
      await pumpThemed(
        t,
        const SizedBox(
          width: 390,
          child: PageHeader(title: 'Title', trailing: Icon(Icons.add, key: ValueKey('tr'))),
        ),
      );
      expect(find.byType(Text), findsOneWidget);
      expect(find.byKey(const ValueKey('tr')), findsOneWidget);
    });
  });

  group('Overline', () {
    testWidgets('shown as written, secondary by default', (t) async {
      await pumpThemed(t, const Overline('Mixed Case'));
      final text = t.widget<Text>(find.text('Mixed Case'));
      expect(text.style!.color, NamoPalette.dark.textSecondary);
      expect(text.style!.fontSize, 12);
    });

    testWidgets('accent is gold, upper-case, spaced, labelled as written', (t) async {
      final handle = t.ensureSemantics();
      await pumpThemed(t, const Overline("Today's gatha", accent: true));
      final text = t.widget<Text>(find.text("TODAY'S GATHA"));
      expect(text.style!.color, NamoPalette.dark.gold);
      expect(text.style!.letterSpacing, 2.0);
      expect(find.bySemanticsLabel("Today's gatha"), findsOneWidget);
      handle.dispose();
    });

    testWidgets('takes a colour', (t) async {
      await pumpThemed(t, Overline('Label', color: NamoPalette.dark.gold));
      expect(t.widget<Text>(find.text('Label')).style!.color, NamoPalette.dark.gold);
    });
  });
}
