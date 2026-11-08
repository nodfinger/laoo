import 'package:flutter/material.dart';

class ExternalHomeFrame extends StatelessWidget {
  const ExternalHomeFrame({super.key, required this.url});
  final Uri url;

  @override
  Widget build(BuildContext context) =>
      const Center(child: Text('เปิดเว็บไซต์ผ่านปุ่ม “เปิดเว็บไซต์” ด้านบน'));
}
