import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:kabootar/core/media/media_codec.dart';

void main() {
  group('MediaCodec', () {
    test('chunk + join round-trips a base64 payload', () {
      final List<int> data = List<int>.generate(60000, (int i) => i % 256);
      final String b64 = base64Url.encode(data);
      final List<String> chunks = MediaCodec.chunk(b64);

      expect(chunks.length, greaterThan(1));
      for (final String c in chunks) {
        expect(c.length, lessThanOrEqualTo(MediaCodec.chunkChars));
      }
      expect(MediaCodec.join(chunks), b64);
      expect(base64Url.decode(MediaCodec.join(chunks)), data);
    });

    test('compressImage shrinks a large image to a decodable JPEG', () {
      final img.Image src = img.Image(width: 2000, height: 1500);
      img.fill(src, color: img.ColorRgb8(120, 60, 200));
      final Uint8List png = Uint8List.fromList(img.encodePng(src));

      final Uint8List out =
          MediaCodec.compressImage(png, maxDim: 800, quality: 70);
      final img.Image? decoded = img.decodeImage(out);

      // The longest side is clamped to maxDim, keeping aspect ratio.
      expect(decoded, isNotNull);
      expect(decoded!.width, 800);
      expect(decoded.height, 600);
    });

    test('thumbnail is small', () {
      final img.Image src = img.Image(width: 1200, height: 1200);
      img.fill(src, color: img.ColorRgb8(10, 200, 90));
      final Uint8List png = Uint8List.fromList(img.encodePng(src));

      final Uint8List thumb = MediaCodec.thumbnail(png, maxDim: 240);
      final img.Image? decoded = img.decodeImage(thumb);
      expect(decoded, isNotNull);
      expect(decoded!.width, lessThanOrEqualTo(240));
    });
  });
}
