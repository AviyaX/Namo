import 'package:buddhist_gatha/design/theme.dart';
import 'package:buddhist_gatha/flows/flow_name_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

final _field = find.byKey(const ValueKey('flow-name-field'));
final _confirm = find.byKey(const ValueKey('flow-name-confirm'));

/// A page with one button that opens the sheet; what the sheet gives back
/// is in [results] (null for a dismissal).
Future<List<String?>> _pump(
  WidgetTester t, {
  String initial = 'p1',
  Size size = const Size(390, 844),
  double textScale = 1.0,
  Brightness brightness = Brightness.light,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final results = <String?>[];
  await t.pumpWidget(
    MaterialApp(
      theme: namoTheme(brightness),
      builder: (context, c) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
        ),
        child: c!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () async => results.add(
                await showFlowNameSheet(
                  context,
                  title: 'Rename flow',
                  initial: initial,
                  action: 'Save',
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await t.tap(find.text('open'));
  await t.pumpAndSettle();
  return results;
}

void main() {
  testWidgets('shows the title, the field labelled "Name" with the name, and '
      'the action', (t) async {
    await _pump(t, initial: 'Morning');
    expect(find.text('Rename flow'), findsOneWidget);
    expect(find.text('Name'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    final field = t.widget<TextField>(_field);
    expect(field.controller!.text, 'Morning');
    expect(field.maxLength, 40);
    expect(field.maxLines, 1);
    expect(
      field.inputFormatters!.whereType<LengthLimitingTextInputFormatter>().single.maxLength,
      40,
    );
    // It has focus, with the whole name chosen to type over.
    expect(field.focusNode!.hasFocus, isTrue);
    expect(field.controller!.selection.start, 0);
    expect(field.controller!.selection.end, 'Morning'.length);
  });

  testWidgets('the action gives back the text as typed', (t) async {
    final results = await _pump(t);
    await t.enterText(_field, '  Evening  ');
    await t.tap(_confirm);
    await t.pumpAndSettle();
    expect(results, ['  Evening  ']);
    expect(find.text('Rename flow'), findsNothing);
  });

  testWidgets('Done on the keyboard gives it back too', (t) async {
    final results = await _pump(t);
    await t.enterText(_field, 'Evening');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pumpAndSettle();
    expect(results, ['Evening']);
  });

  testWidgets('a tap above the sheet dismisses it and gives back null',
      (t) async {
    final results = await _pump(t);
    await t.enterText(_field, 'Evening');
    await t.tapAt(const Offset(195, 20));
    await t.pumpAndSettle();
    expect(results, [null]);
  });

  testWidgets('a 500-character paste with line breaks leaves one line of at '
      'most 40 characters', (t) async {
    final results = await _pump(t);
    final long = List.filled(50, 'p1 p2 p3\n').join().padRight(500, 'x');
    expect(long.length, 500);
    await t.enterText(_field, long);
    await t.pump();
    final text = t.widget<TextField>(_field).controller!.text;
    expect(text.length, lessThanOrEqualTo(40));
    expect(text, isNot(contains('\n')));
    await t.tap(_confirm);
    await t.pumpAndSettle();
    expect(results.single!.length, lessThanOrEqualTo(40));
  });

  for (final b in Brightness.values) {
    testWidgets('does not overflow at 320 wide with text 2.0, with the '
        'longest name ($b)', (t) async {
      await _pump(
        t,
        initial: 'W' * 40,
        size: const Size(320, 568),
        textScale: 2.0,
        brightness: b,
      );
      expect(t.takeException(), isNull);
      expect(t.getSize(_confirm).height, greaterThanOrEqualTo(48));
    });
  }
}
