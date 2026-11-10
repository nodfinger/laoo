import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:laoo/features/assistant/assistant_report.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('HTML report escapes content', () async {
    final report = utf8.decode(
      await buildAssistantReport('html', 'รายงาน <script>'),
    );
    expect(report, contains('รายงาน &lt;script&gt;'));
    expect(report, isNot(contains('<script>')));
  });
  test('PDF report produces a PDF with Thai text', () async {
    final report = await buildAssistantReport('pdf', 'ต้นทุนอะไหล่ 100 บาท');
    expect(ascii.decode(report.take(5).toList()), '%PDF-');
  });
  testWidgets('PNG report produces an image', (tester) async {
    final report = await tester.runAsync(
      () => buildAssistantReport('png', 'ต้นทุนอะไหล่ 100 บาท'),
    );
    expect(report!.take(8).toList(), [137, 80, 78, 71, 13, 10, 26, 10]);
  });
}
