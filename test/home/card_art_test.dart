import 'package:buddhist_gatha/home/card_art.dart';
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
}
