import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laoo/core/api/api_client.dart';
import 'package:laoo/features/assistant/ai_chat_review_panel.dart';

class FakeReviewApi extends ApiClient {
  String status = 'PREPARING';
  int approvals = 0;
  Object? saved;
  bool testFails = false;

  @override
  Future<dynamic> get(
    String path, {
    Map<String, String>? query,
    bool authenticated = true,
  }) async {
    if (path.endsWith('/filters')) {
      return {'departments': <Object>[], 'branches': <Object>[]};
    }
    return {
      'rows': [
        {
          'id': 1,
          'text': 'คอมเสีย',
          'reviewText': 'คอมเสีย',
          'status': status,
          'capabilities': ['a', 'b'],
          'detected': 'a',
        },
      ],
      'total': 1,
    };
  }

  @override
  Future<dynamic> post(
    String path, {
    Object? body,
    bool authenticated = true,
    Duration? timeout,
  }) async {
    if (path.endsWith('/test')) {
      if (testFails) throw StateError('test failed');
      status = 'AWAITING_APPROVAL';
      return {
        'passed': true,
        'expected': ['a', 'b'],
        'matches': ['a', 'b'],
        'simulated': true,
      };
    }
    if (path.endsWith('/approve')) {
      approvals++;
      status = 'ACTIVE';
    }
    return null;
  }

  @override
  Future<dynamic> put(
    String path, {
    Object? body,
    bool authenticated = true,
  }) async {
    saved = body;
    status = 'PREPARING';
    return null;
  }
}

const abilities = <Map<String, dynamic>>[
  {'code': 'a', 'name': 'แจ้งซ่อม', 'agentId': 'service', 'isEnabled': true},
  {'code': 'b', 'name': 'ค้นสต๊อก', 'agentId': 'stock', 'isEnabled': true},
  {'code': 'c', 'name': 'รายการปิด', 'agentId': 'stock', 'isEnabled': false},
];

void main() {
  Future<void> showPanel(
    WidgetTester tester,
    FakeReviewApi api, {
    bool cards = false,
    Size size = const Size(1200, 1200),
    List<Map<String, dynamic>> items = abilities,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: AiChatReviewPanel(
                capabilities: items,
              canEdit: true,
              cards: cards,
              api: api,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'filter retains selected capabilities and disables inactive choices',
    (tester) async {
      final api = FakeReviewApi();
      await showPanel(tester, api);
      await tester.tap(find.text('กำลังจัดเตรียม').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('จัดเตรียม').last);
      await tester.pumpAndSettle();
      expect(find.text('แสดงเฉพาะรายการที่เลือก (2)'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'ค้นหาความสามารถหรือ Agent'),
        'สต๊อก',
      );
      await tester.pumpAndSettle();
      expect(find.text('ค้นสต๊อก'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.text('แจ้งซ่อม'),
        ),
        findsNothing,
      );
      expect(find.text('แสดงเฉพาะรายการที่เลือก (2)'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'ค้นหาความสามารถหรือ Agent'),
        '',
      );
      await tester.pumpAndSettle();
      final disabled = tester.widget<CheckboxListTile>(
        find.ancestor(
          of: find.text('รายการปิด'),
          matching: find.byType(CheckboxListTile),
        ),
      );
      expect(disabled.onChanged, isNull);
    },
  );

  for (final cards in [false, true]) {
    testWidgets(
      'test result and numbered approval confirmation: cards=$cards',
      (tester) async {
        final api = FakeReviewApi();
        await showPanel(tester, api, cards: cards);
        await tester.tap(find.text('กำลังจัดเตรียม').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('ทดลอง').last);
        await tester.pumpAndSettle();
        expect(find.text('ผลทดลองคำถาม'), findsOneWidget);
        expect(find.textContaining('จำลองการจับคู่'), findsOneWidget);
        await tester.tap(find.text('อนุมัติพร้อมกัน').last);
        await tester.pumpAndSettle();
        expect(find.text('ยืนยันอนุมัติพร้อมกัน'), findsOneWidget);
        expect(find.text('1. '), findsOneWidget);
        expect(find.text('2. '), findsOneWidget);
        await tester.tap(find.text('ยกเลิก').last);
        await tester.pumpAndSettle();
        expect(api.approvals, 0);
        await tester.tap(find.text('รออนุมัติ').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('อนุมัติ').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('ยืนยันอนุมัติ').last);
        await tester.pumpAndSettle();
        expect(api.approvals, 1);
      },
    );
  }

  testWidgets('saving keeps dialog open, tests and enables approval', (tester) async {
    final api = FakeReviewApi();
    await showPanel(tester, api);
    await tester.tap(find.text('กำลังจัดเตรียม').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('จัดเตรียม').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('บันทึก').last);
    await tester.tap(find.text('บันทึก').last);
    await tester.pumpAndSettle();
    expect(find.text('จัดเตรียมคำถาม'), findsOneWidget);
    expect(find.text('ทดลองผ่านแล้ว สามารถอนุมัติพร้อมกันได้'), findsOneWidget);
    final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'อนุมัติพร้อมกัน'));
    expect(button.onPressed, isNotNull);
    await tester.tap(find.text('อนุมัติพร้อมกัน').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('ยืนยันอนุมัติ').last);
    await tester.pumpAndSettle();
    expect(api.approvals, 1);
    expect(find.text('ใช้งานแล้ว'), findsOneWidget);
  });

  testWidgets('editing tested question disables approval until retested', (
    tester,
  ) async {
    final api = FakeReviewApi()..status = 'AWAITING_APPROVAL';
    await showPanel(tester, api);
    await tester.tap(find.text('รออนุมัติ').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('จัดเตรียม').last);
    await tester.pumpAndSettle();
    final approve = find.widgetWithText(FilledButton, 'อนุมัติพร้อมกัน');
    expect(tester.widget<FilledButton>(approve).onPressed, isNotNull);
    await tester.enterText(
      find.widgetWithText(TextField, 'คำถาม *'),
      'ข้อความแก้ไข',
    );
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(approve).onPressed, isNull);
    expect(api.approvals, 0);
  });

  testWidgets('failed test appears in popup and never approves', (
    tester,
  ) async {
    final api = FakeReviewApi()..testFails = true;
    await showPanel(tester, api);
    await tester.tap(find.text('กำลังจัดเตรียม').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('ทดลอง').last);
    await tester.pumpAndSettle();
    expect(find.text('ผลทดลองคำถาม'), findsOneWidget);
    expect(find.textContaining('ทำรายการไม่สำเร็จ'), findsOneWidget);
    expect(find.text('อนุมัติพร้อมกัน'), findsNothing);
    expect(api.approvals, 0);
  });

  testWidgets('small viewport supports scrolling many capability choices', (tester) async {
    final api = FakeReviewApi();
    final items = [...abilities, for (var i = 0; i < 30; i++) {'code': 'extra$i', 'name': 'Capability $i', 'agentId': 'stock', 'isEnabled': true}];
    await showPanel(tester, api, size: const Size(390, 844), items: items);
    await tester.tap(find.text('กำลังจัดเตรียม').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('จัดเตรียม').last);
    await tester.pumpAndSettle();
    expect(find.text('จัดเตรียมคำถาม'), findsOneWidget);
    expect(find.text('แสดงเฉพาะรายการที่เลือก (2)'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
