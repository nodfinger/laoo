// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

class KnowledgeVideoEmbed extends StatefulWidget {
  const KnowledgeVideoEmbed({super.key, required this.url});
  final Uri url;
  @override
  State<KnowledgeVideoEmbed> createState() => _KnowledgeVideoEmbedState();
}

class _KnowledgeVideoEmbedState extends State<KnowledgeVideoEmbed> {
  static int _sequence = 0;
  late final String _type;
  late final html.IFrameElement _frame;
  @override
  void initState() {
    super.initState();
    _type = 'knowledge-video-embed-${_sequence++}';
    _frame = html.IFrameElement()
      ..src = widget.url.toString()
      ..allow =
          'accelerometer; autoplay; encrypted-media; picture-in-picture; fullscreen'
      ..setAttribute('allowfullscreen', 'true')
      ..style.border = '0'
      ..style.width = '100%'
      ..style.height = '100%';
    ui_web.platformViewRegistry.registerViewFactory(_type, (_) => _frame);
  }

  @override
  void dispose() {
    _frame.src = 'about:blank';
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => HtmlElementView(viewType: _type);
}
