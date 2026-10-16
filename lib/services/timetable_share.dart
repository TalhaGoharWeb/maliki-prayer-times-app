import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

/// Renders the [RepaintBoundary] identified by [boundaryKey] to PNG bytes.
///
/// The capture target on the monthly screen is the timetable grid wrapped
/// in a [RepaintBoundary] keyed with the same [GlobalKey]; the image
/// inherits the screen's styling automatically.
///
/// Returns `null` (never throws) when anything needed for the capture is
/// missing: no attached context, no repaint boundary under the key, or a
/// failure while producing the PNG.
Future<Uint8List?> renderTimetablePng(GlobalKey boundaryKey,
    {double pixelRatio = 2.0}) async {
  try {
    final context = boundaryKey.currentContext;
    if (context == null) return null;
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) return null;
    final image = await renderObject.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ImageByteFormat.png);
    if (byteData == null) return null;
    return byteData.buffer.asUint8List();
  } catch (_) {
    return null;
  }
}

/// Writes [pngBytes] to a temp file named [fileName] and hands it to the
/// platform share sheet with [subject] as the share subject.
///
/// [shareFn] is an injection point for tests; when omitted, the share
/// goes through share_plus's [SharePlus.instance].
Future<void> shareTimetable({
  required Uint8List pngBytes,
  required String fileName,
  required String subject,
  Future<void> Function(XFile file, String subject)? shareFn,
}) async {
  final file = File('${Directory.systemTemp.path}/$fileName');
  await file.writeAsBytes(pngBytes, flush: true);
  await (shareFn ?? _defaultShare)(XFile(file.path), subject);
}

Future<void> _defaultShare(XFile file, String subject) {
  return SharePlus.instance.share(ShareParams(files: [file], subject: subject));
}
