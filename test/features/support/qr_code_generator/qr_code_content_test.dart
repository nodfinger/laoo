import 'package:flutter_test/flutter_test.dart';
import 'package:laoo/features/support/qr_code_generator/qr_code_content.dart';

void main() {
  group('validateQrContent', () {
    test('accepts Thai text and trims surrounding whitespace', () {
      expect(validateQrContent(QrContentType.text, ' สวัสดีพ่อมนต์ '), isNull);
      expect(normalizeQrContent(' สวัสดีพ่อมนต์ '), 'สวัสดีพ่อมนต์');
    });

    test('rejects empty content', () {
      expect(validateQrContent(QrContentType.text, '   '), 'กรุณาระบุข้อความ');
    });

    test('accepts only absolute http or https URLs', () {
      expect(
        validateQrContent(QrContentType.link, 'https://laoo.co.th/path'),
        isNull,
      );
      expect(
        validateQrContent(QrContentType.imageUrl, 'http://img.test/a.jpg'),
        isNull,
      );
      expect(validateQrContent(QrContentType.link, 'laoo.co.th'), isNotNull);
      expect(
        validateQrContent(QrContentType.imageUrl, 'javascript:alert(1)'),
        isNotNull,
      );
    });

    test('rejects content beyond the QR byte limit', () {
      expect(
        validateQrContent(
          QrContentType.text,
          List.filled(qrContentMaxBytes + 1, 'a').join(),
        ),
        contains('$qrContentMaxBytes'),
      );
    });
  });
}
