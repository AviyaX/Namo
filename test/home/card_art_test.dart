import 'dart:io';

import 'package:buddhist_gatha/design/theme.dart';
import 'package:buddhist_gatha/home/card_art.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('pictureDecodeWidth', () {
    test('rounds the shown width up to steps of 128 logical pixels', () {
      expect(pictureDecodeWidth(1, 1), 128);
      expect(pictureDecodeWidth(128, 1), 128);
      expect(pictureDecodeWidth(129, 1), 256);
      expect(pictureDecodeWidth(350, 1), 384);
    });

    test('a few pixels of resizing does not change the decode size', () {
      expect(pictureDecodeWidth(340, 2), pictureDecodeWidth(383, 2));
      expect(pictureDecodeWidth(340, 2), 768);
    });

    test('is capped, and survives an unbounded width', () {
      expect(pictureDecodeWidth(100000, 3), lessThanOrEqualTo(1600));
      expect(pictureDecodeWidth(double.infinity, 2), pictureDecodeWidth(100000, 2));
    });
  });

  group('pictures', () {
    test('the hero and header pictures are per-theme files', () {
      expect(heroPictures, {
        'cat-namaskaraya': (
          dark: 'assets/pictures/hero_dark.jpg',
          light: 'assets/pictures/hero_light.jpg',
        ),
      });
      expect(headerPictures, (
        dark: 'assets/pictures/header_dark.jpg',
        light: 'assets/pictures/header_light.jpg',
      ));
    });

    test('every bundled picture exists on disk and is listed in pubspec.yaml', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final paths = {
        ...cardPictures.values,
        for (final p in heroPictures.values) ...[p.dark, p.light],
        headerPictures.dark,
        headerPictures.light,
      };
      for (final path in paths) {
        expect(File(path).existsSync(), isTrue, reason: path);
        expect(pubspec, contains('- $path'), reason: path);
      }
    });

    test('home_banner.jpg is gone and nothing under lib/ names it', () {
      expect(File('assets/pictures/home_banner.jpg').existsSync(), isFalse);
      expect(File('pubspec.yaml').readAsStringSync(), isNot(contains('home_banner')));
      for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
        if (!f.path.endsWith('.dart')) continue;
        expect(f.readAsStringSync(), isNot(contains('home_banner')), reason: f.path);
      }
    });

    for (final brightness in Brightness.values) {
      testWidgets('hero: true picks the ${brightness.name} hero picture', (t) async {
        await t.pumpWidget(
          MaterialApp(
            theme: namoTheme(brightness),
            home: const SizedBox(
              width: 320,
              height: 180,
              child: TopicPicture(categoryId: 'cat-namaskaraya', hero: true),
            ),
          ),
        );
        final image = t.widget<Image>(find.byKey(const ValueKey('card-art-picture')));
        final asset = ((image.image as ResizeImage).imageProvider as AssetImage).assetName;
        expect(asset, 'assets/pictures/hero_${brightness.name}.jpg');
      });
    }

    testWidgets('a tall box decodes the 2 : 1 hero wide enough to cover it', (
      t,
    ) async {
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        MaterialApp(
          theme: namoTheme(Brightness.dark),
          home: const Center(
            child: SizedBox(
              width: 200,
              height: 400,
              child: TopicPicture(categoryId: 'cat-namaskaraya', hero: true),
            ),
          ),
        ),
      );
      final image = t.widget<Image>(find.byKey(const ValueKey('card-art-picture')));
      // Covering 400 tall, the 2 : 1 picture is shown 800 wide.
      expect((image.image as ResizeImage).width, pictureDecodeWidth(800, 1));
    });

    testWidgets('hero: true on a topic with no hero falls back to its card picture', (t) async {
      await t.pumpWidget(
        MaterialApp(
          theme: namoTheme(Brightness.light),
          home: const SizedBox(
            width: 320,
            height: 180,
            child: TopicPicture(categoryId: 'cat-pirith', hero: true),
          ),
        ),
      );
      final image = t.widget<Image>(find.byKey(const ValueKey('card-art-picture')));
      expect(
        ((image.image as ResizeImage).imageProvider as AssetImage).assetName,
        'assets/pictures/pirith.jpg',
      );
    });
  });
}
