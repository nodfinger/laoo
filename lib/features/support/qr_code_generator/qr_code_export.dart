import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

Future<Uint8List> createQrPng(String data, {int size = 1200}) async {
  final painter = QrPainter(
    data: data,
    version: QrVersions.auto,
    errorCorrectionLevel: QrErrorCorrectLevel.M,
    gapless: true,
    eyeStyle: const QrEyeStyle(
      eyeShape: QrEyeShape.square,
      color: Color(0xFF000000),
    ),
    dataModuleStyle: const QrDataModuleStyle(
      dataModuleShape: QrDataModuleShape.square,
      color: Color(0xFF000000),
    ),
  );
  final side = size.toDouble();
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, side, side),
    Paint()..color = Colors.white,
  );
  painter.paint(canvas, Size(side, side));
  final exportedImage = await recorder.endRecording().toImage(size, size);
  final bytes = await exportedImage.toByteData(format: ui.ImageByteFormat.png);
  exportedImage.dispose();
  if (bytes == null) {
    throw StateError('ไม่สามารถสร้างไฟล์รูป QR Code ได้');
  }
  return bytes.buffer.asUint8List();
}
