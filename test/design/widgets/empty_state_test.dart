import 'package:buddhist_gatha/design/tokens.dart';
import 'package:buddhist_gatha/design/widgets/buttons.dart';
import 'package:buddhist_gatha/design/widgets/empty_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'widget_support.dart';

void main() {
  group('EmptyState', () {
    testWidgets('shows title, message and the action; the action fires', (t) async {
      var taps = 0;
      await pumpThemed(
        t,
        SizedBox(
          width: 390,
          child: EmptyState(
            icon: Symbols.bookmark_rounded,
            title: 'Title',
            message: 'Message',
            actionLabel: 'Act',
            onAction: () => taps++,
          ),
        ),
      );
      expect(find.text('Title'), findsOneWidget);
      expect(find.text('Message'), findsOneWidget);
      await t.tap(find.text('Act'));
      expect(taps, 1);
    });

    testWidgets('no action button when actionLabel is null', (t) async {
      await pumpThemed(
        t,
        const SizedBox(
          width: 390,
          child: EmptyState(icon: Symbols.bookmark_rounded, title: 'Title', message: 'Message'),
        ),
      );
      expect(find.byType(PrimaryButton), findsNothing);
    });

    testWidgets('a 64 disc of backgroundAlt holds an outline icon 24', (t) async {
      await pumpThemed(
        t,
        const SizedBox(
          width: 390,
          child: EmptyState(icon: Symbols.bookmark_rounded, title: 'Title', message: 'Message'),
        ),
      );
      final icon = t.widget<Icon>(find.byType(Icon));
      expect(icon.size, 24);
      expect(icon.fill, 0);
      expect(icon.color, NamoPalette.dark.textSecondary);
      final disc = find.ancestor(of: find.byType(Icon), matching: find.byType(Container)).first;
      expect(t.getSize(disc), const Size(64, 64));
      final d = t.widget<Container>(disc).decoration! as BoxDecoration;
      expect(d.shape, BoxShape.circle);
      expect(d.color, NamoPalette.dark.backgroundAlt);
    });

    testWidgets('is centred and at most 360 wide', (t) async {
      await pumpThemed(
        t,
        const SizedBox(
          width: 800,
          height: 600,
          child: EmptyState(icon: Symbols.bookmark_rounded, title: 'Title', message: 'A long message that needs many words to fill a line and then wrap onto the next line of text'),
        ),
        size: const Size(800, 600),
      );
      expect(t.getCenter(find.text('Title')).dx, 400);
      final cap = find.byWidgetPredicate(
          (w) => w is ConstrainedBox && w.constraints.maxWidth == 360);
      expect(t.getSize(cap).width, 360);
      expect(t.getSize(find.text('Title')).width, lessThanOrEqualTo(360 - 32));
    });
  });
}
