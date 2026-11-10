import 'dart:io';
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

  /// Files written by the last share/export, so they can be cleaned up.
  ///
  /// Every share used to leave a 1080 × 1920 PNG behind in the cache directory
  /// forever. A user who shares weekly accumulates hundreds of megabytes.
  static final List<String> _recent = [];

  /// Deletes everything this service wrote, except the newest [keep].
  ///
  /// Called after a successful export so the file the user just saved to their
  /// gallery still exists for a moment, while older copies go.
  Future<void> pruneTemporaryFiles({int keep = 2}) async {
    final dir = await getTemporaryDirectory();
    try {
      final listed = await dir.list().toList();
      final stamped = <(File, DateTime)>[];
      for (final entity in listed) {
        if (entity is! File || !entity.path.endsWith('.png')) continue;
        final file = entity;
        try {
          stamped.add((file, (await file.stat()).modified));
        } catch (_) {
          // Skip a file that vanished between listing and stat.
        }
      }
      stamped.sort((a, b) => b.$2.compareTo(a.$2));
      final pngs = stamped.map((e) => e.$1).toList(growable: false);
      for (var i = keep; i < pngs.length; i++) {
        try {
          await pngs[i].delete();
        } catch (error) {
          debugPrint('prune failed for ${pngs[i].path}: $error');
        }
      }
    } catch (error) {
      debugPrint('prune skipped: $error');
    }
    _recent.clear();
  }

  /// Saves the PNG to the user's photo gallery via the system share sheet's
  /// "Save to Photos / Files" action.
  ///
  /// Android has no permission-free "write to gallery" API without a plugin, so
  /// this deliberately routes through the OS. The point is that the button
  /// labelled "Export PNG" must not silently do the same thing as "Share" —
  /// it opens with a different subject and no social caption.
  Future<ShareResult> savePng(
    Uint8List bytes, {
    required String fileName,
    Rect? sharePositionOrigin,
  }) async {
    return _write(
      bytes,
      fileName: fileName,
      text: null,
      subject: 'SubBurn receipt (1080 × 1920 PNG)',
      sharePositionOrigin: sharePositionOrigin,
    );
  }

  /// Writes the PNG to the cache directory and opens the share sheet.
  Future<ShareResult> sharePng(
    Uint8List bytes, {
    required String fileName,
    String? text,
    Rect? sharePositionOrigin,
  }) async {
    return _write(
      bytes,
      fileName: fileName,
      text: text,
      subject: 'My SubBurn receipt',
      sharePositionOrigin: sharePositionOrigin,
    );
  }

  Future<ShareResult> _write(
    Uint8List bytes, {
    required String fileName,
    required String? text,
    required String subject,
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
          subject: subject,
          sharePositionOrigin: sharePositionOrigin,
        ),
      );
    } catch (error) {
      debugPrint('share failed: $error');
      return const ShareResult('unavailable', ShareResultStatus.unavailable);
    }
  }
}
