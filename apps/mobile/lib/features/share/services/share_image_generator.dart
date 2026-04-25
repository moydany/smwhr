import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Captures a `RepaintBoundary` as a PNG byte buffer.
///
/// Used by Pantalla 11 (Share). Story dimensions are Instagram-friendly
/// 1080 × 1920 — pass `pixelRatio: 1080 / boundary.size.width` so the
/// resulting PNG matches that target regardless of the on-screen size.
class ShareImageGenerator {
  ShareImageGenerator._();

  static Future<Uint8List?> capture(
    GlobalKey boundaryKey, {
    double targetWidth = 1080,
  }) async {
    final ctx = boundaryKey.currentContext;
    if (ctx == null) return null;
    final renderObject = ctx.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) return null;

    final ratio = targetWidth / renderObject.size.width;
    final image = await renderObject.toImage(pixelRatio: ratio);
    final byteData =
        await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }
}
