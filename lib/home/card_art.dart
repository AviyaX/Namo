import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../design/tokens.dart';

/// Category id -> bundled asset path of its picture. This is the one place a
/// picture gets registered (and its file listed in pubspec.yaml and credited
/// in docs/pictures.md and on the Sources page).
const Map<String, String> cardPictures = {
  'cat-namaskaraya': 'assets/pictures/samadhi_buddha_anuradhapura.jpg',
};

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
          : LayoutBuilder(
              builder: (context, box) {
                // Decode at the size of the slot, not the full file.
                final pixels =
                    box.maxWidth * MediaQuery.devicePixelRatioOf(context);
                return Image.asset(
                  asset,
                  key: const ValueKey('card-art-picture'),
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  width: double.infinity,
                  height: double.infinity,
                  cacheWidth: pixels.isFinite
                      ? pixels.clamp(1, _maxDecodeWidth).round()
                      : _maxDecodeWidth,
                  // The gradient shows until the first frame is decoded.
                  // `sync` is true when the picture was already decoded
                  // (in the image cache): show it at once, with no
                  // one-frame flash of the gradient.
                  frameBuilder: (context, child, frame, sync) =>
                      frame == null && !sync
                      ? const _DrawnPanel(lotus: false)
                      : child,
                  errorBuilder: (context, error, stack) => const _DrawnPanel(),
                );
              },
            ),
    );
  }
}

/// Width of the bundled pictures; decoding never goes wider.
const int _maxDecodeWidth = 1600;

/// A soft gradient between two colours of the theme with one fine-line lotus
/// in the accent gold, centred. Nothing else. Without the lotus it is only the
/// gradient, shown while a picture decodes.
class _DrawnPanel extends StatelessWidget {
  const _DrawnPanel({this.lotus = true});

  final bool lotus;

  @override
  Widget build(BuildContext context) {
    final p = NamoPalette.of(context);
    return DecoratedBox(
      key: ValueKey(lotus ? 'card-art-panel' : 'card-art-loading'),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [p.surface, p.background],
        ),
      ),
      child: lotus
          ? LayoutBuilder(
              builder: (context, box) => Center(
                child: Icon(
                  Symbols.spa,
                  size: box.maxHeight * 0.4,
                  weight: 200,
                  color: p.accent,
                ),
              ),
            )
          : null,
    );
  }
}
