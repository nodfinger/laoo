import 'dart:convert';

enum QrContentType { text, link, imageUrl }

extension QrContentTypeLabel on QrContentType {
  String get label => switch (this) {
    QrContentType.text => 'ข้อความ',
    QrContentType.link => 'ลิงก์เว็บไซต์',
    QrContentType.imageUrl => 'URL รูปภาพ',
  };

  String get fieldLabel => switch (this) {
    QrContentType.text => 'ข้อความ *',
    QrContentType.link => 'ลิงก์เว็บไซต์ *',
    QrContentType.imageUrl => 'URL รูปภาพ *',
  };

  String get hint => switch (this) {
    QrContentType.text => 'ระบุข้อความภาษาไทยหรือภาษาอังกฤษ',
    QrContentType.link => 'https://www.example.com',
    QrContentType.imageUrl => 'https://www.example.com/image.jpg',
  };
}

const int qrContentMaxBytes = 2000;

String? validateQrContent(QrContentType type, String rawValue) {
  final value = rawValue.trim();
  if (value.isEmpty) return 'กรุณาระบุ${type.label}';
  if (utf8.encode(value).length > qrContentMaxBytes) {
    return 'ข้อมูลยาวเกิน $qrContentMaxBytes ไบต์ กรุณาย่อข้อมูลก่อนสร้าง QR Code';
  }
  if (type == QrContentType.text) return null;

  final uri = Uri.tryParse(value);
  final isHttp = uri?.scheme == 'http' || uri?.scheme == 'https';
  if (uri == null || !isHttp || uri.host.trim().isEmpty) {
    return 'กรุณาระบุ URL ที่ขึ้นต้นด้วย http:// หรือ https://';
  }
  return null;
}

String normalizeQrContent(String rawValue) => rawValue.trim();
