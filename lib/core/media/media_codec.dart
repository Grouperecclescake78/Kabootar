import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Pure-Dart image handling for the mesh: shrink a picked photo to something a
/// Bluetooth link can actually carry, make a tiny preview thumbnail, and split
/// a base64 payload into transport-sized chunks (and reassemble them).
///
/// The transport caps a single payload at roughly 32 KB, so media travels as a
/// sequence of small chunk envelopes that flood and are reassembled by the
/// recipient - the same store-and-forward path as text.
abstract class MediaCodec {
  /// Base64 characters per chunk (~12 KB of raw bytes), comfortably under the
  /// transport's per-payload ceiling once envelope overhead is added.
  static const int chunkChars = 16000;

  /// Re-encode a photo as a modest JPEG (longest side [maxDim], [quality]) so it
  /// is small enough to ferry. Falls back to the original bytes if it cannot be
  /// decoded.
  static Uint8List compressImage(
    Uint8List input, {
    int maxDim = 1600,
    int quality = 80,
  }) =>
      _resizeJpeg(input, maxDim, quality) ?? input;

  /// A small preview (longest side [maxDim]) shown immediately while the full
  /// image is still arriving.
  static Uint8List thumbnail(
    Uint8List input, {
    int maxDim = 240,
    int quality = 55,
  }) =>
      _resizeJpeg(input, maxDim, quality) ?? input;

  /// Compress the image and make its thumbnail in one call, so the whole job
  /// can run in a background isolate via `compute()` (decoding a large photo is
  /// CPU-heavy and would otherwise jank the UI). Returns `[full, thumbnail]`.
  static List<Uint8List> imageAndThumb(Uint8List input) =>
      <Uint8List>[compressImage(input), thumbnail(input)];

  static Uint8List? _resizeJpeg(Uint8List input, int maxDim, int quality) {
    final img.Image? decoded = img.decodeImage(input);
    if (decoded == null) return null;
    final bool landscape = decoded.width >= decoded.height;
    final bool tooBig = decoded.width > maxDim || decoded.height > maxDim;
    final img.Image sized = tooBig
        ? img.copyResize(
            decoded,
            width: landscape ? maxDim : null,
            height: landscape ? null : maxDim,
          )
        : decoded;
    return img.encodeJpg(sized, quality: quality);
  }

  /// Split a base64 string into transport-sized chunks.
  static List<String> chunk(String base64Payload) {
    final List<String> out = <String>[];
    for (int i = 0; i < base64Payload.length; i += chunkChars) {
      out.add(base64Payload.substring(
        i,
        math.min(i + chunkChars, base64Payload.length),
      ));
    }
    return out;
  }

  /// Reassemble ordered chunks back into the base64 payload.
  static String join(List<String> chunks) => chunks.join();
}
