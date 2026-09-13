import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:laoo/features/company/item/data/item_api.dart';
import 'package:laoo/features/company/item/pages/item_form_layout.dart';

class FakeItemApi extends ItemApi {
  int created = 0, updated = 0, defaultsRead = 0;
  Map<String, dynamic>? saved;
  @override
  Future<List<Map<String, dynamic>>> projectOptions() async => [
    {'projectId': 1, 'projectName': 'งานขาย'},
    {'projectId': 2, 'projectName': 'ห้องประชุม'},
  ];
  @override
  Future<Map<String, dynamic>> classificationDefaults(
    String? group,
    String? type,
  ) async {
    defaultsRead++;
    return {
      'found': true,
      'itemKindCode': 'GOODS',
      'stockTrackingCode': 'SERIAL',
      'usageCodes': ['EQUIPMENT'],
    };
  }

  @override
  Future<Map<String, dynamic>> create(Map<String, dynamic> body) async {
    created++;
    saved = body;
    return {'itemID': 17, 'itemCode': 'NEW1'};
  }

  @override
  Future<void> update(int id, Map<String, dynamic> body) async {
    updated++;
    saved = body;
  }

  @override
  void dispose() {}
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Future<void> render(
    WidgetTester tester,
    FakeItemApi api,
    Size size, {
    bool existing = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Dialog(
            insetPadding: const EdgeInsets.all(24),
            child: ItemFormLayout(
              initial: {
                'itemCode': 'NEW1',
                'itemName': 'โปรเจกเตอร์',
                'itemGroupCode': 'G',
                'itemTypeCode': 'T',
                'unitCode': 'U',
                if (existing) 'itemID': 17,
                if (existing) 'usageCodes': ['SALE'],
                if (existing)
                  'projectAccess': {
                    'accessModeCode': 'SELECTED',
                    'projectIds': [2],
                  },
                if (existing) 'responsibleDepartmentOrgUnitID': 11,
              },
              groups: const [
                {'code': 'G', 'name': 'กลุ่ม'},
              ],
              types: const [
                {'code': 'T', 'name': 'ประเภท'},
              ],
              units: const [
                {'code': 'U', 'name': 'เครื่อง'},
              ],
              responsibleDepartments: const [
                {'code': '11', 'name': 'IT | เทคโนโลยีสารสนเทศ'},
              ],
              codeSettings: const {'runItem': '0'},
              maxItemImageSizeMB: 1,
              onCancel: () {},
              onSaved: () {},
              apiFactory: () => api,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final width in [390.0, 1100.0]) {
    testWidgets('popup fits $width with pinned footer', (tester) async {
      await render(tester, FakeItemApi(), Size(width, 850));
      expect(tester.takeException(), isNull);
      final before = tester.getCenter(
        find.widgetWithText(FilledButton, 'บันทึก'),
      );
      await tester.drag(find.byType(ListView).first, const Offset(0, -450));
      await tester.pumpAndSettle();
      expect(
        tester.getCenter(find.widgetWithText(FilledButton, 'บันทึก')),
        before,
      );
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('new item applies defaults and keeps the form in add mode', (
    tester,
  ) async {
    final api = FakeItemApi();
    await render(tester, api, const Size(1100, 1400));
    expect(
      tester
          .widget<FilterChip>(find.widgetWithText(FilterChip, 'อุปกรณ์'))
          .selected,
      isTrue,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'บันทึก'));
    await tester.pumpAndSettle();
    expect(api.created, 1);
    expect(api.saved?['projectAccess'], {
      'accessModeCode': 'ALL',
      'projectIds': [],
    });
    expect(find.text('โปรเจกเตอร์'), findsNothing);
    expect(find.text('NEW1'), findsNothing);
    await tester.tap(find.widgetWithText(FilledButton, 'บันทึก'));
    await tester.pumpAndSettle();
    expect(api.created, 1);
    expect(api.updated, 0);
    await tester.enterText(find.byType(TextFormField).at(0), 'NEW2');
    await tester.enterText(find.byType(TextFormField).at(1), 'รายการสอง');
    await tester.tap(find.widgetWithText(FilledButton, 'บันทึก'));
    await tester.pumpAndSettle();
    expect(api.created, 2);
    expect(api.updated, 0);
  });
  testWidgets('editing preserves classification and selected projects', (
    tester,
  ) async {
    final api = FakeItemApi();
    await render(tester, api, const Size(1100, 1400), existing: true);
    expect(api.defaultsRead, 0);
    expect(
      tester
          .widget<FilterChip>(find.widgetWithText(FilterChip, 'ขาย'))
          .selected,
      isTrue,
    );
    expect(
      tester
          .widget<CheckboxListTile>(
            find.widgetWithText(CheckboxListTile, 'ห้องประชุม'),
          )
          .value,
      isTrue,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'บันทึก'));
    await tester.pumpAndSettle();
    expect(api.saved?['projectAccess'], {
      'accessModeCode': 'SELECTED',
      'projectIds': [2],
    });
    expect(api.saved?['responsibleDepartmentOrgUnitID'], 11);
    expect(find.text('แผนกที่รับผิดชอบ'), findsOneWidget);
    expect(find.text('ค่าเริ่มต้นสำหรับสินค้าใหม่'), findsNothing);
  });
}
