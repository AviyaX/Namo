import 'package:flutter/material.dart';

import '../settings/settings.dart';

abstract final class NamoSizes {
  static const readingColumn = 680.0;
  static const wideBreakpoint = 840.0;

  /// The reading column of a phrased reading (a pirith): wide enough for a
  /// phrase and its meaning side by side.
  static const phraseColumn = 920.0;
  static const touchTarget = 48.0;
  static const homeColumn = 1040.0;
  static const iconSmall = 20.0;
  static const icon = 24.0;
  static const navBarHeight = 64.0;

  /// The widest the Bana player (or its offline panel) grows.
  static const playerColumn = 720.0;

  /// The width of a Bana thumbnail in a list row.
  static const banaThumbWidth = 120.0;

  /// The side margin of a page at [width].
  static double pageMargin(double width) => width < 360
      ? 16
      : width < wideBreakpoint
          ? 20
          : 32;
}

abstract final class NamoSpace {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 32.0;
  static const xxxl = 48.0;
}

abstract final class NamoRadius {
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 24.0;

  /// A book's cover.
  static const cover = 6.0;

  /// Cards (SurfaceCard).
  static const card = 20.0;

  /// Round ends at any height: a pill.
  static const pill = 999.0;
}

abstract final class NamoMotion {
  static const press = Duration(milliseconds: 120);
  static const quick = Duration(milliseconds: 200);
  static const open = Duration(milliseconds: 300);
  static const close = Duration(milliseconds: 200);

  /// A book's corner lifting and falling back, once, for a first-time
  /// reader.
  static const peel = Duration(milliseconds: 1200);

  static const curve = Curves.easeOutCubic;

  /// [d], or zero when the person has asked for no animation.
  static Duration of(BuildContext context, Duration d) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : d;
}

/// Semantic colour roles, one set per brightness.
@immutable
class NamoPalette extends ThemeExtension<NamoPalette> {
  const NamoPalette({
    required this.background,
    required this.backgroundAlt,
    required this.surface,
    required this.border,
    required this.text,
    required this.textSecondary,
    required this.textMuted,
    required this.sage,
    required this.gold,
    required this.frame,
    required this.onSage,
    required this.shadow,
    required this.error,
    required this.onError,
    required this.bookPaper,
    required this.bookInk,
    required this.bookInkSoft,
    required this.bookInkSecondary,
    required this.bookCover,
    required this.bookRule,
    required this.bookPaperDark,
    required this.bookInkDark,
    required this.bookCoverDark,
    required this.bookRuleDark,
    required this.bookFold,
    required this.bookFoldDark,
    required this.bookSpine,
    required this.bookSpineDark,
  });

  final Color background;
  final Color backgroundAlt;
  final Color surface;
  final Color border;
  final Color text;
  final Color textSecondary;
  final Color textMuted;
  final Color sage;
  final Color gold;

  /// The thin gold line round a featured or gatha card.
  final Color frame;
  final Color onSage;
  final Color shadow;
  final Color error;
  final Color onError;

  /// A book's cream paper, its ink, soft ink (page numbers), secondary ink
  /// (captions and footnotes, which must read at 4.5:1), cover and the gold
  /// rule. The same in both app themes: a book is the same book.
  final Color bookPaper;
  final Color bookInk;
  final Color bookInkSoft;
  final Color bookInkSecondary;
  final Color bookCover;
  final Color bookRule;

  /// The same, for a book printed on dark paper.
  final Color bookPaperDark;
  final Color bookInkDark;
  final Color bookCoverDark;
  final Color bookRuleDark;

  /// The underside of a page's lifted corner, on cream and on dark paper.
  final Color bookFold;
  final Color bookFoldDark;

  /// The shadow of the binding down a page's spine edge, on cream and on
  /// dark paper (at its darkest; it fades to nothing across the page).
  final Color bookSpine;
  final Color bookSpineDark;

  static const _bookPaper = Color(0xFFF7EFDC);
  static const _bookInk = Color(0xFF2A2A22);
  static const _bookInkSoft = Color(0xFF8A7A55);
  static const _bookInkSecondary = Color(0xFF6E6042);
  static const _bookCover = Color(0xFF5B3A22);
  static const _bookRule = Color(0xFFD2B26C);
  static const _bookPaperDark = Color(0xFF1A241C);
  static const _bookInkDark = Color(0xFFEFE9DA);
  static const _bookCoverDark = Color(0xFF3A2616);
  static const _bookRuleDark = Color(0x99D2B26C);
  static const _bookFold = Color(0xFFE4D3AC);
  static const _bookFoldDark = Color(0xFF2C3A2E);
  static const _bookSpine = Color(0x40000000);
  static const _bookSpineDark = Color(0x80000000);

  static const dark = NamoPalette(
    background: Color(0xFF0E1410),
    backgroundAlt: Color(0xFF141C16),
    surface: Color(0xFF1A241C),
    border: Color(0xFF3B4233),
    text: Color(0xFFEFE9DA),
    textSecondary: Color(0xFFB5B3A0),
    textMuted: Color(0xFF7F8273),
    sage: Color(0xFF8FB07F),
    gold: Color(0xFFD2B26C),
    frame: Color(0x8CD2B26C),
    onSage: Color(0xFF151714),
    shadow: Color(0x4D000000),
    error: Color(0xFFE08A7C),
    onError: Color(0xFF151714),
    bookPaper: _bookPaper,
    bookInk: _bookInk,
    bookInkSoft: _bookInkSoft,
    bookInkSecondary: _bookInkSecondary,
    bookCover: _bookCover,
    bookRule: _bookRule,
    bookPaperDark: _bookPaperDark,
    bookInkDark: _bookInkDark,
    bookCoverDark: _bookCoverDark,
    bookRuleDark: _bookRuleDark,
    bookFold: _bookFold,
    bookFoldDark: _bookFoldDark,
    bookSpine: _bookSpine,
    bookSpineDark: _bookSpineDark,
  );

  static const light = NamoPalette(
    background: Color(0xFFF8F4EA),
    backgroundAlt: Color(0xFFF0EBDD),
    surface: Color(0xFFFFFCF5),
    border: Color(0xFFD9D0BB),
    text: Color(0xFF1F2A20),
    textSecondary: Color(0xFF4C5646),
    textMuted: Color(0xFF72786A),
    sage: Color(0xFF4A6541),
    gold: Color(0xFF84652A),
    frame: Color(0x738A6A2C),
    onSage: Color(0xFFFDFBF6),
    shadow: Color(0x1F22251F),
    error: Color(0xFF9B3B2F),
    onError: Color(0xFFFDFBF6),
    bookPaper: _bookPaper,
    bookInk: _bookInk,
    bookInkSoft: _bookInkSoft,
    bookInkSecondary: _bookInkSecondary,
    bookCover: _bookCover,
    bookRule: _bookRule,
    bookPaperDark: _bookPaperDark,
    bookInkDark: _bookInkDark,
    bookCoverDark: _bookCoverDark,
    bookRuleDark: _bookRuleDark,
    bookFold: _bookFold,
    bookFoldDark: _bookFoldDark,
    bookSpine: _bookSpine,
    bookSpineDark: _bookSpineDark,
  );

  /// Text drawn over a picture, and the scrim colour it sits on.
  static const onPicture = Color(0xFFEAE6DC);
  static const pictureScrim = Color(0xFF151714);

  Color get pressed => text.withValues(alpha: 0.08);
  Color get hovered => text.withValues(alpha: 0.04);
  Color get sageTint => sage.withValues(alpha: 0.14);

  /// The background of the phrase being chanted, over [sageTint].
  Color get sageMark => sage.withValues(alpha: 0.30);

  /// The only shadow in the app.
  List<BoxShadow> get floatShadow =>
      [BoxShadow(color: shadow, blurRadius: 24, offset: const Offset(0, 8))];

  /// The shade a turning page casts along its fold: [shadow], stronger.
  Color get curlShadow =>
      shadow.withValues(alpha: (shadow.a * 2.5).clamp(0.0, 0.6));

  /// The light catching the bend of a turning page.
  Color get curlHighlight =>
      Color.lerp(surface, const Color(0xFFFFFFFF), 0.6)!
          .withValues(alpha: 0.35);

  static NamoPalette of(BuildContext context) =>
      Theme.of(context).extension<NamoPalette>()!;

  @override
  NamoPalette copyWith({
    Color? background,
    Color? backgroundAlt,
    Color? surface,
    Color? border,
    Color? text,
    Color? textSecondary,
    Color? textMuted,
    Color? sage,
    Color? gold,
    Color? frame,
    Color? onSage,
    Color? shadow,
    Color? error,
    Color? onError,
    Color? bookPaper,
    Color? bookInk,
    Color? bookInkSoft,
    Color? bookInkSecondary,
    Color? bookCover,
    Color? bookRule,
    Color? bookPaperDark,
    Color? bookInkDark,
    Color? bookCoverDark,
    Color? bookRuleDark,
    Color? bookFold,
    Color? bookFoldDark,
    Color? bookSpine,
    Color? bookSpineDark,
  }) =>
      NamoPalette(
        background: background ?? this.background,
        backgroundAlt: backgroundAlt ?? this.backgroundAlt,
        surface: surface ?? this.surface,
        border: border ?? this.border,
        text: text ?? this.text,
        textSecondary: textSecondary ?? this.textSecondary,
        textMuted: textMuted ?? this.textMuted,
        sage: sage ?? this.sage,
        gold: gold ?? this.gold,
        frame: frame ?? this.frame,
        onSage: onSage ?? this.onSage,
        shadow: shadow ?? this.shadow,
        error: error ?? this.error,
        onError: onError ?? this.onError,
        bookPaper: bookPaper ?? this.bookPaper,
        bookInk: bookInk ?? this.bookInk,
        bookInkSoft: bookInkSoft ?? this.bookInkSoft,
        bookInkSecondary: bookInkSecondary ?? this.bookInkSecondary,
        bookCover: bookCover ?? this.bookCover,
        bookRule: bookRule ?? this.bookRule,
        bookPaperDark: bookPaperDark ?? this.bookPaperDark,
        bookInkDark: bookInkDark ?? this.bookInkDark,
        bookCoverDark: bookCoverDark ?? this.bookCoverDark,
        bookRuleDark: bookRuleDark ?? this.bookRuleDark,
        bookFold: bookFold ?? this.bookFold,
        bookFoldDark: bookFoldDark ?? this.bookFoldDark,
        bookSpine: bookSpine ?? this.bookSpine,
        bookSpineDark: bookSpineDark ?? this.bookSpineDark,
      );

  @override
  NamoPalette lerp(ThemeExtension<NamoPalette>? other, double t) {
    if (other is! NamoPalette) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return NamoPalette(
      background: mix(background, other.background),
      backgroundAlt: mix(backgroundAlt, other.backgroundAlt),
      surface: mix(surface, other.surface),
      border: mix(border, other.border),
      text: mix(text, other.text),
      textSecondary: mix(textSecondary, other.textSecondary),
      textMuted: mix(textMuted, other.textMuted),
      sage: mix(sage, other.sage),
      gold: mix(gold, other.gold),
      frame: mix(frame, other.frame),
      onSage: mix(onSage, other.onSage),
      shadow: mix(shadow, other.shadow),
      error: mix(error, other.error),
      onError: mix(onError, other.onError),
      bookPaper: mix(bookPaper, other.bookPaper),
      bookInk: mix(bookInk, other.bookInk),
      bookInkSoft: mix(bookInkSoft, other.bookInkSoft),
      bookInkSecondary: mix(bookInkSecondary, other.bookInkSecondary),
      bookCover: mix(bookCover, other.bookCover),
      bookRule: mix(bookRule, other.bookRule),
      bookPaperDark: mix(bookPaperDark, other.bookPaperDark),
      bookInkDark: mix(bookInkDark, other.bookInkDark),
      bookCoverDark: mix(bookCoverDark, other.bookCoverDark),
      bookRuleDark: mix(bookRuleDark, other.bookRuleDark),
      bookFold: mix(bookFold, other.bookFold),
      bookFoldDark: mix(bookFoldDark, other.bookFoldDark),
      bookSpine: mix(bookSpine, other.bookSpine),
      bookSpineDark: mix(bookSpineDark, other.bookSpineDark),
    );
  }
}

/// The colours a book page is drawn with on the chosen paper. Soft ink is
/// for the page number only; captions and footnotes take the secondary ink.
/// On dark paper both are the dark palette's secondary text, so they read in
/// either theme.
({
  Color paper,
  Color ink,
  Color inkSoft,
  Color inkSecondary,
  Color cover,
  Color rule,
  Color fold,
  Color spine,
}) bookColours(
  NamoPalette p,
  BookPaper paper,
) =>
    switch (paper) {
      BookPaper.cream => (
          paper: p.bookPaper,
          ink: p.bookInk,
          inkSoft: p.bookInkSoft,
          inkSecondary: p.bookInkSecondary,
          cover: p.bookCover,
          rule: p.bookRule,
          fold: p.bookFold,
          spine: p.bookSpine,
        ),
      BookPaper.dark => (
          paper: p.bookPaperDark,
          ink: p.bookInkDark,
          inkSoft: NamoPalette.dark.textSecondary,
          inkSecondary: NamoPalette.dark.textSecondary,
          cover: p.bookCoverDark,
          rule: p.bookRuleDark,
          fold: p.bookFoldDark,
          spine: p.bookSpineDark,
        ),
    };
