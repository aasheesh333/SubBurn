import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Turns the 360 × 640 receipt into a 1080 × 1920 PNG and hands it to the
/// system share sheet.
///
/// The capture is deliberately synchronous with the frame: callers pass the
/// [GlobalKey] that wraps the *export node only*, so UI chrome can never leak
/// into the image.
class ShareService {
  const ShareService();

  /// Captures the boundary at 3× and returns the encoded PNG bytes.
  Future<Uint8List> capturePng(GlobalKey key, {double pixelRatio = 3.0}) async {
    final object = key.currentContext?.findRenderObject();
    if (object is! RenderRepaintBoundary) {
      throw StateError('ShareService.capturePng: key is not a RepaintBoundary');
    }
    final image = await object.toImage(pixelRatio: pixelRatio);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (data == null) {
      throw StateError('ShareService.capturePng: PNG encoding returned null');
    }
    return data.buffer.asUint8List();
  }

  /// Writes the PNG to the cache directory and opens the share sheet.
  Future<ShareResult> sharePng(
    Uint8List bytes, {
    required String fileName,
    String? text,
    Rect? sharePositionOrigin,
  }) async {
    final dir = await getTemporaryDirectory();
    final file = XFile.fromData(
      bytes,
      mimeType: 'image/png',
      name: fileName,
    );
    // share_plus resolves names from the file path on Android, so keep both.
    final target = '${dir.path}/$fileName';
    await file.saveTo(target);

    try {
      return await SharePlus.instance.share(
        ShareParams(
          files: [XFile(target, mimeType: 'image/png')],
          text: text,
          subject: 'My SubBurn receipt',
          sharePositionOrigin: sharePositionOrigin,
        ),
      );
    } catch (error) {
      debugPrint('share failed: $error');
      return const ShareResult('unavailable', ShareResultStatus.unavailable);
    }
  }
}
