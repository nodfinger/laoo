import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;
import 'assistant_download.dart';

Future<void> exportAssistantReport(String format, String text) async {
  final bytes = await buildAssistantReport(format, text);
  final mime = switch (format) {
    'html' => 'text/html;charset=utf-8',
    'pdf' => 'application/pdf',
    'png' => 'image/png',
    _ => throw ArgumentError('Unsupported report format'),
  };
  await saveAssistantFile('assistant-report.$format', mime, bytes);
}

Future<Uint8List> buildAssistantReport(String format, String text) async {
  if (format == 'html') {
    final safe = const HtmlEscape().convert(text);
    return Uint8List.fromList(
      utf8.encode(
          '<!doctype html><html lang="th"><meta charset="utf-8"><title>รายงานผู้ช่วย AI</title><body><pre>$safe</pre></body></html>',
      ),
    );
  }
  if (format == 'pdf') {
    final bytes = await rootBundle.load(
      'assets/fonts/NotoSansThai-Variable.ttf',
    );
    final font = pw.Font.ttf(bytes);
    final document = pw.Document();
    document.addPage(
      pw.Page(
        theme: pw.ThemeData.withFont(base: font),
        build: (_) => pw.Text(text),
      ),
    );
    return document.save();
  }
  if (format == 'png') {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawColor(Colors.white, BlendMode.src);
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 22,
          fontFamily: 'NotoSansThai',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 900);
    painter.paint(canvas, const Offset(24, 24));
    final picture = recorder.endRecording();
    final image = await picture.toImage(948, (painter.height + 48).ceil());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    picture.dispose();
    painter.dispose();
    if (data == null) throw StateError('ไม่สามารถสร้างภาพได้');
    return data.buffer.asUint8List();
  }
  throw ArgumentError('Unsupported report format');
}
