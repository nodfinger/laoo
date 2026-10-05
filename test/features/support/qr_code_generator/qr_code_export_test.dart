import 'package:flutter_test/flutter_test.dart';
import 'package:laoo/features/support/qr_code_generator/qr_code_export.dart';

void main() {
  testWidgets('creates a PNG payload for Thai QR content', (tester) async {
    final bytes = await tester.runAsync(
      () => createQrPng('ข้อความทดสอบ QR ภาษาไทย', size: 320),
    );

    expect(bytes, isNotNull);
    expect(bytes!.length, greaterThan(100));
    expect(bytes.take(8).toList(), <int>[137, 80, 78, 71, 13, 10, 26, 10]);
  });
}
