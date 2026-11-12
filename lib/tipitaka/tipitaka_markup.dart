import 'package:flutter/foundation.dart';

/// Inline markup of the Tripitaka text: **bold** __underline__ ~~strike~~
/// $$editorial$$ ##highlight##, {footnote}, line breaks and <hr/>.
/// Ported from the source's shared/markup.ts and shared/footnote.ts.
enum MarkupKind { bold, underline, strike, highlight, editorial }

sealed class MarkupToken {
  const MarkupToken();
}

class TextToken extends MarkupToken {
  const TextToken(this.text);
  final String text;
}

class BreakToken extends MarkupToken {
  const BreakToken();
}

class RuleToken extends MarkupToken {
  const RuleToken();
}

class FootnoteRefToken extends MarkupToken {
  const FootnoteRefToken(this.ref);
  final String ref;
}

class SpanToken extends MarkupToken {
  const SpanToken(this.kind, this.children);
  final MarkupKind kind;
  final List<MarkupToken> children;
}

const _pairs = <String, MarkupKind>{
  '**': MarkupKind.bold,
  '__': MarkupKind.underline,
  '~~': MarkupKind.strike,
  '##': MarkupKind.highlight,
  r'$$': MarkupKind.editorial,
};

const _entities = <String, String>{'&gt;': '>', '&lt;': '<', '&amp;': '&'};

final _tagPattern = RegExp(r'^<(/?)(hr|b)\s*/?>', caseSensitive: false);
final _entityPattern = RegExp(r'^&(gt|lt|amp);');

/// Port of parseMarkup in the source's shared/markup.ts. Never throws.
List<MarkupToken> parseMarkup(String text) =>
    _parseRange(text, 0, text.length);

List<MarkupToken> _parseRange(String s, int start, int end) {
  final tokens = <MarkupToken>[];
  final buf = StringBuffer();
  void flush() {
    if (buf.isNotEmpty) {
      tokens.add(TextToken(buf.toString()));
      buf.clear();
    }
  }

  var i = start;
  while (i < end) {
    final two = s.substring(i, i + 2 > s.length ? s.length : i + 2);
    final kind = _pairs[two];
    if (kind != null) {
      final close = s.indexOf(two, i + 2);
      if (close >= 0 && close + 2 <= end) {
        flush();
        tokens.add(SpanToken(kind, _parseRange(s, i + 2, close)));
        i = close + 2;
      } else {
        buf.write(two); // unbalanced: literal
        i += 2;
      }
      continue;
    }
    final ch = s[i];
    if (ch == '{') {
      final close = s.indexOf('}', i + 1);
      if (close > i + 1 && close < end && !s.substring(i + 1, close).contains('\n')) {
        flush();
        tokens.add(FootnoteRefToken(s.substring(i + 1, close)));
        i = close + 1;
        continue;
      }
    } else if (ch == '\n' || ch == '↴') {
      flush();
      tokens.add(const BreakToken());
      i++;
      continue;
    } else if (ch == '<') {
      final m = _tagPattern
          .firstMatch(s.substring(i, i + 8 < end ? i + 8 : end));
      if (m != null) {
        if (m.group(2)!.toLowerCase() == 'hr') {
          flush();
          tokens.add(const RuleToken());
        }
        i += m.group(0)!.length; // <b> and </b> are dropped
        continue;
      }
    } else if (ch == '&') {
      final m = _entityPattern
          .firstMatch(s.substring(i, i + 5 < s.length ? i + 5 : s.length));
      if (m != null) {
        buf.write(_entities[m.group(0)]);
        i += m.group(0)!.length;
        continue;
      }
    }
    buf.write(ch);
    i++;
  }
  flush();
  return tokens;
}

String _escapeHtml(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

const _tags = <MarkupKind, (String, String)>{
  MarkupKind.bold: ('<b>', '</b>'),
  MarkupKind.underline: ('<u>', '</u>'),
  MarkupKind.strike: ('<s>', '</s>'),
  MarkupKind.highlight: ('<mark>', '</mark>'),
  MarkupKind.editorial: ('<span class="editorial">', '</span>'),
};

/// Port of tokensToHtml; exists so the port can be tested against the
/// source's vectors.
@visibleForTesting
String tokensToHtml(List<MarkupToken> tokens) {
  final out = StringBuffer();
  for (final tk in tokens) {
    switch (tk) {
      case TextToken():
        out.write(_escapeHtml(tk.text));
      case BreakToken():
        out.write('<br>');
      case RuleToken():
        out.write('<hr>');
      case FootnoteRefToken():
        out.write('<sup class="fn">${_escapeHtml(tk.ref)}</sup>');
      case SpanToken():
        final tag = _tags[tk.kind]!;
        out
          ..write(tag.$1)
          ..write(tokensToHtml(tk.children))
          ..write(tag.$2);
    }
  }
  return out.toString();
}

final _footnotePattern = RegExp(r'^([^\s.{}]+)[.\s]([\s\S]+)$');

/// Port of parseFootnote in shared/footnote.ts ('' and '' when it does not
/// match).
({String number, String content}) parseFootnote(String text) {
  final m = _footnotePattern.firstMatch(text);
  return m == null
      ? (number: '', content: '')
      : (number: m.group(1)!, content: m.group(2)!);
}

/// Index into [footnotes] of the one whose number equals [ref], or null.
int? matchFootnote(String ref, List<String> footnotes) {
  if (ref.isEmpty) return null;
  for (var i = 0; i < footnotes.length; i++) {
    if (parseFootnote(footnotes[i]).number == ref) return i;
  }
  return null;
}
