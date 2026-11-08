import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

class ExternalHomeFrame extends StatefulWidget {
  const ExternalHomeFrame({super.key, required this.url});
  final Uri url;

  @override
  State<ExternalHomeFrame> createState() => _ExternalHomeFrameState();
}

class _ExternalHomeFrameState extends State<ExternalHomeFrame> {
  static int _nextId = 0;
  late final String _viewType;
  late final web.HTMLIFrameElement _frame;

  @override
  void initState() {
    super.initState();
    _viewType = 'external-home-${_nextId++}';
    _frame = web.HTMLIFrameElement()
      ..src = widget.url.toString()
      ..title = 'เว็บไซต์หน้าแรก'
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.border = '0';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (_) => _frame);
  }

  @override
  void didUpdateWidget(covariant ExternalHomeFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) _frame.src = widget.url.toString();
  }

  @override
  Widget build(BuildContext context) => HtmlElementView(viewType: _viewType);
}
