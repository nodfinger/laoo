// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

class KnowledgeVideoPreview extends StatefulWidget {
  const KnowledgeVideoPreview({super.key, required this.bytes});
  final Uint8List bytes;
  @override
  State<KnowledgeVideoPreview> createState() => _KnowledgeVideoPreviewState();
}

class _KnowledgeVideoPreviewState extends State<KnowledgeVideoPreview> {
  late final String url;
  late final String viewType;
  late final html.VideoElement video;
  static int nextId = 0;

  @override
  void initState() {
    super.initState();
    url = html.Url.createObjectUrlFromBlob(
      html.Blob([widget.bytes], 'video/mp4'),
    );
    video = html.VideoElement()
      ..src = url
      ..controls = true
      ..preload = 'metadata';
    video.style
      ..width = '100%'
      ..height = '100%'
      ..objectFit = 'contain'
      ..backgroundColor = 'black';
    viewType = 'knowledge-video-preview-${nextId++}';
    ui_web.platformViewRegistry.registerViewFactory(viewType, (_) => video);
  }

  @override
  void dispose() {
    video.pause();
    video.removeAttribute('src');
    video.load();
    html.Url.revokeObjectUrl(url);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => HtmlElementView(viewType: viewType);
}
