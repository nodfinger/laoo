import 'dart:typed_data';
import 'package:flutter/material.dart';

class KnowledgeVideoPreview extends StatelessWidget {
  const KnowledgeVideoPreview({super.key, required this.bytes});
  final Uint8List bytes;
  @override
  Widget build(BuildContext context) =>
      const Center(child: Text('อุปกรณ์นี้ยังไม่รองรับการแสดงตัวอย่างคลิป'));
}
