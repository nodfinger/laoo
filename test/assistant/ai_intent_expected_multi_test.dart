import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laoo/core/api/api_client.dart';
import 'package:laoo/features/assistant/ai_intent_test_page.dart';

class IntentApi extends ApiClient {
  Object? tested;
  Object? approved;
  bool duplicate = false;
  @override
  Future<dynamic> get(String path, {Map<String, String>? query, bool authenticated = true}) async {
    if (path == '/api/assistant/capabilities') return {'capabilities': ['repair.create_own', 'repair.serial_history']};
    if (path == '/api/assistant/registry') {
      return {'canEdit': true, 'rows': [
      {'code': 'repair.create_own', 'name': 'แจ้งงานซ่อมใหม่'},
      {'code': 'repair.serial_history', 'name': 'ประวัติซ่อมตาม Serial'},
    ]};
    }
    throw StateError('Unexpected request');
  }
  @override
  Future<dynamic> post(String path, {Object? body, bool authenticated = true, Duration? timeout}) async {
    if (path == '/api/assistant/intent-test') {
      tested = body;
      return {'intent': 'repair.serial_history', 'choices': [{'code': 'repair.serial_history', 'name': 'ประวัติซ่อมตาม Serial'}], 'duplicate': duplicate, 'approvalProof': duplicate ? null : 'proof'};
    }
    approved = body;
    return {'message': 'อนุมัติแล้ว'};
  }
}

void main() {
  testWidgets('admin selects two expected capabilities when AI finds one', (tester) async {
    final api = IntentApi();
    await tester.binding.setSurfaceSize(const Size(1200, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(home: AiIntentTestPage(api: api, captionLoader: () async => 'ทดลองคำถาม AI', wrapper: (child) => Scaffold(body: child))));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'sn');
    await tester.tap(find.text('แจ้งงานซ่อมใหม่').first);
    await tester.pumpAndSettle();
    expect(find.text('1. แจ้งงานซ่อมใหม่'), findsOneWidget);
    await tester.tap(find.text('2. ประวัติซ่อมตาม Serial'));
    await tester.tap(find.text('เลือก').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('ทดลอง').last);
    await tester.pumpAndSettle();
    expect(find.text('ผลไม่ตรงกับที่คาดหวัง'), findsOneWidget);
    expect((api.tested as Map)['expectedCapabilities'], containsAll(['repair.create_own', 'repair.serial_history']));
    await tester.ensureVisible(find.text('อนุมัติ').last);
    await tester.tap(find.text('อนุมัติ').last);
    await tester.pumpAndSettle();
    expect(find.text('1. แจ้งงานซ่อมใหม่'), findsWidgets);
    expect(find.text('2. ประวัติซ่อมตาม Serial'), findsWidgets);
    await tester.tap(find.text('ยืนยัน').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('อนุมัติแล้ว'), findsWidgets);
    expect((api.approved as Map)['capabilities'], containsAll(['repair.create_own', 'repair.serial_history']));
    expect((api.approved as Map)['approvalProof'], 'proof');
  });
  testWidgets('duplicate question cannot be approved', (tester) async {
    final api = IntentApi()..duplicate = true;
    await tester.binding.setSurfaceSize(const Size(1200, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(home: AiIntentTestPage(api: api, captionLoader: () async => 'ทดลองคำถาม AI', wrapper: (child) => Scaffold(body: child))));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'sn');
    await tester.tap(find.text('ทดลอง').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('ซ้ำ: คำถามนี้มีอยู่'), findsOneWidget);
    expect(find.text('อนุมัติ'), findsNothing);
    expect(api.approved, isNull);
  });
}
