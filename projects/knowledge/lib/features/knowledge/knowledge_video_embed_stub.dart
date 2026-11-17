import 'package:flutter/material.dart';

class KnowledgeVideoEmbed extends StatelessWidget {
  const KnowledgeVideoEmbed({super.key, required this.url});
  final Uri url;
  @override
  Widget build(BuildContext context) =>
      const Center(child: Text('อุปกรณ์นี้ยังไม่รองรับการแสดงคลิปในหน้าจอ'));
}
