import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../design/tokens.dart';

/// Category id -> bundled asset path of its picture. Empty until pictures
/// exist; this is the one place a picture gets registered (and its file
/// listed in pubspec.yaml).
const Map<String, String> cardPictures = {};

/// The picture slot of a reading card: the category's picture when one is
/// registered, otherwise (or if the file does not load) a drawn panel. It
/// fills whatever space it is given; the card gives it a 16:9 box.
///
/// The picture is decoration, so it is left out of the semantics tree.
class CardArt extends StatelessWidget {
  const CardArt({
    super.key,
    required this.categoryId,
    this.pictures = cardPictures,
  });

  final String categoryId;

  /// Replaces [cardPictures]; for tests.
  final Map<String, String> pictures;

  @override
  Widget build(BuildContext context) {
    final asset = pictures[categoryId];
    return ExcludeSemantics(
      child: asset == null
          ? const _DrawnPanel()
          : Image.asset(
              asset,
              key: const ValueKey('card-art-picture'),
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (context, error, stack) => const _DrawnPanel(),
            ),
    );
  }
}

/// A soft gradient between two colours of the theme with one fine-line lotus
/// in the accent gold, centred. Nothing else.
class _DrawnPanel extends StatelessWidget {
  const _DrawnPanel();

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    return DecoratedBox(
      key: const ValueKey('card-art-panel'),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [p.surface, p.background],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, box) => Center(
          child: Icon(
            Symbols.spa,
            size: box.maxHeight * 0.4,
            weight: 200,
            color: p.accent,
          ),
        ),
      ),
    );
  }
}
