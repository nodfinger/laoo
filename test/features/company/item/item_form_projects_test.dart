import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:laoo/features/company/item/data/item_api.dart';
import 'package:laoo/features/company/item/pages/item_form_layout.dart';
import 'package:laoo/app/theme/laoo_typography.dart';

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
                {'code': '12', 'name': 'FIN | Finance'},
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

  testWidgets('master lookup buttons are available on the product form', (
    tester,
  ) async {
    await render(tester, FakeItemApi(), const Size(1100, 1400), existing: true);
    expect(find.byIcon(Icons.edit_note_outlined), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'searching for department selects it without changing product data',
    (tester) async {
      await render(
        tester,
        FakeItemApi(),
        const Size(1100, 1400),
        existing: true,
      );
      final button = find.byTooltip(
        '\u0e04\u0e49\u0e19\u0e2b\u0e32 \u0e41\u0e1c\u0e19\u0e01\u0e17\u0e35\u0e48\u0e23\u0e31\u0e1a\u0e1c\u0e34\u0e14\u0e0a\u0e2d\u0e1a',
      );
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Finance');
      await tester.pumpAndSettle();
      expect(find.text('FIN | Finance'), findsOneWidget);
      await tester.tap(find.text('FIN | Finance'));
      await tester.pumpAndSettle();
      expect(find.text('FIN | Finance'), findsOneWidget);
      expect(find.text('NEW1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final width in [390.0, 1100.0]) {
    testWidgets('popup fits $width with pinned footer', (tester) async {
      await render(tester, FakeItemApi(), Size(width, 850));
      expect(tester.takeException(), isNull);
      final before = tester.getCenter(
        find.widgetWithText(FilledButton, 'บันทึก'),
      );
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, -450),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getCenter(find.widgetWithText(FilledButton, 'บันทึก')),
        before,
      );
      expect(tester.takeException(), isNull);
    });
  }
  for (final existing in [false, true]) {
    testWidgets('usage help does not change selections, edit=$existing', (
      tester,
    ) async {
      await render(
        tester,
        FakeItemApi(),
        Size(existing ? 390 : 1100, 1400),
        existing: existing,
      );
      for (final label in ['ขาย', 'วัสดุ', 'อุปกรณ์', 'อะไหล่']) {
        final chip = find.widgetWithText(FilterChip, label);
        final selected = tester.widget<FilterChip>(chip).selected;
        final icon = find.byWidgetPredicate(
          (widget) =>
              widget is Icon && widget.semanticLabel == 'คำอธิบาย$label',
        );
        await tester.ensureVisible(icon);
        await tester.tap(icon);
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byType(Tooltip), findsWidgets);
        final tooltip = tester.widget<Tooltip>(
          find.ancestor(of: icon, matching: find.byType(Tooltip)).first,
        );
        expect(find.text(tooltip.message!), findsOneWidget);
        expect(tester.widget<FilterChip>(chip).selected, selected);
        await tester.pump(const Duration(seconds: 3));
      }
      final icon = find.byWidgetPredicate(
        (widget) => widget is Icon && widget.semanticLabel == 'คำอธิบายขาย',
      );
      await tester.ensureVisible(icon);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: tester.getCenter(icon));
      await tester.pump(const Duration(seconds: 2));
      final hoverTooltip = tester.widget<Tooltip>(
        find.ancestor(of: icon, matching: find.byType(Tooltip)).first,
      );
      expect(find.text(hoverTooltip.message!), findsOneWidget);
      await mouse.removePointer();
      await tester.pump(const Duration(seconds: 3));
      Focus.of(tester.element(icon)).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump(const Duration(milliseconds: 100));
      final tooltip = tester.widget<Tooltip>(
        find.ancestor(of: icon, matching: find.byType(Tooltip)).first,
      );
      expect(find.text(tooltip.message!), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('classification layout and warranty font use the standard', (
    tester,
  ) async {
    await render(tester, FakeItemApi(), const Size(1600, 1400), existing: true);
    Finder dropdown(String label) => find.byWidgetPredicate(
      (widget) =>
          widget is DropdownButtonFormField<String> &&
          widget.decoration?.labelText == label,
    );
    final group = tester.getTopLeft(dropdown('* กลุ่มสินค้า'));
    final type = tester.getTopLeft(dropdown('* ประเภทสินค้า'));
    final tracking = tester.getTopLeft(dropdown('* วิธีควบคุมสต็อก'));
    final department = tester.getTopLeft(dropdown('แผนกที่รับผิดชอบ'));
    final price = tester.getTopLeft(dropdown('* ราคาเริ่มต้นรับเข้าสต๊อก'));
    final sale = tester.getTopLeft(find.widgetWithText(FilterChip, 'ขาย'));
    final material = tester.getTopLeft(
      find.widgetWithText(FilterChip, 'วัสดุ'),
    );
    final equipment = tester.getTopLeft(
      find.widgetWithText(FilterChip, 'อุปกรณ์'),
    );
    final spare = tester.getTopLeft(find.widgetWithText(FilterChip, 'อะไหล่'));
    expect(group.dy, type.dy);
    expect(sale.dx, greaterThan(type.dx));
    expect(sale.dy, material.dy);
    expect(equipment.dy, spare.dy);
    expect(equipment.dy, greaterThan(sale.dy));
    final saleBounds = tester.getRect(find.widgetWithText(FilterChip, 'ขาย'));
    final equipmentBounds = tester.getRect(
      find.widgetWithText(FilterChip, 'อุปกรณ์'),
    );
    expect(equipmentBounds.top - saleBounds.bottom, greaterThanOrEqualTo(8));
    final usageBox = find.byWidgetPredicate(
      (widget) =>
          widget is InputDecorator &&
          widget.decoration.labelText == '* วัตถุประสงค์',
    );
    expect(
      tester.getSize(dropdown('* กลุ่มสินค้า')).width * 2 + 12,
      greaterThan(tester.getSize(usageBox).width),
    );
    expect(department.dy, greaterThan(tracking.dy));
    expect(price.dy, department.dy);
    expect(department.dx, group.dx);
    for (final label in [
      'ประกันผู้ขาย (เริ่มเมื่อรับเข้า)',
      'ประกันลูกค้า (เลือกเริ่มตอนส่งของ/ติดตั้ง)',
    ]) {
      expect(
        tester
            .widget<DropdownButton<String>>(
              find.descendant(
                of: dropdown(label),
                matching: find.byType(DropdownButton<String>),
              ),
            )
            .style
            ?.fontSize,
        LaooTypography.comboBox,
      );
    }
    expect(tester.takeException(), isNull);
  });
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
