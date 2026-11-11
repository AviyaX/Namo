import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every passage (one language of one block) that is built.
final Finder passages = find.byWidgetPredicate(
  (w) =>
      w.key is ValueKey<String> &&
      (w.key! as ValueKey<String>).value.startsWith('passage-'),
);

/// The passage of [verseId] in [language] (`pali`, `sinhala`, `english`).
Finder passage(String verseId, String language) =>
    find.byKey(ValueKey('passage-$verseId-$language'));

/// The phrase spans of a passage, in order (the separators between them, a
/// single space in a pirith and a line break in a unit, left out).
List<TextSpan> phraseSpans(WidgetTester t, Finder passage) {
  final text = t.widget<Text>(passage);
  final children = (text.textSpan! as TextSpan).children!.cast<TextSpan>();
  return [for (final c in children) if (c.text != ' ' && c.text != '\n') c];
}

/// The whole text of a passage.
String passageText(WidgetTester t, Finder passage) =>
    (t.widget<Text>(passage).textSpan! as TextSpan).toPlainText();

bool isMarked(TextSpan s) =>
    s.style?.backgroundColor != null &&
    s.style?.decoration == TextDecoration.underline;

/// The positions (among the phrase spans) of the marked spans of a passage.
List<int> markedIn(WidgetTester t, Finder passage) {
  final spans = phraseSpans(t, passage);
  return [for (var i = 0; i < spans.length; i++) if (isMarked(spans[i])) i];
}

/// How many spans are marked in the passages found inside [scope] (all
/// built passages when null).
int markCount(WidgetTester t, [Finder? scope]) {
  final inside = scope == null
      ? passages
      : find.descendant(of: scope, matching: passages);
  var n = 0;
  for (final e in inside.evaluate()) {
    n += markedIn(t, find.byElementPredicate((x) => x == e)).length;
  }
  return n;
}

/// The global top of the line the first marked span of the first marked
/// passage in [scope] starts on; null when nothing is marked.
double? markTop(WidgetTester t, Finder scope) {
  for (final e in find.descendant(of: scope, matching: passages).evaluate()) {
    final spans = (e.widget as Text).textSpan! as TextSpan;
    var at = 0;
    for (final c in spans.children!.cast<TextSpan>()) {
      final len = c.text!.length;
      if (isMarked(c)) {
        final paragraph = _paragraph(e);
        final box = paragraph
            .getBoxesForSelection(
              TextSelection(baseOffset: at, extentOffset: at + len),
            )
            .first;
        return paragraph.localToGlobal(Offset(0, box.top)).dy;
      }
      at += len;
    }
  }
  return null;
}

RenderParagraph _paragraph(Element e) {
  RenderParagraph? found;
  void visit(Element x) {
    if (found != null) return;
    final r = x.renderObject;
    if (r is RenderParagraph) {
      found = r;
      return;
    }
    x.visitChildren(visit);
  }

  visit(e);
  return found!;
}
