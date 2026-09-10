import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:laoo/features/company/vendor/data/vendor_api.dart';
import 'package:laoo/features/company/vendor/pages/vendor_page.dart';

class FakeVendorApi extends VendorApi {
  int creates = 0, updates = 0, loads = 0;
  bool edit = true, create = true, deleteAllowed = true;
  String search = '';
  final row = <String, dynamic>{
    'vendorID': 7,
    'vendorCode': 'V001',
    'vendorName': 'ผู้ขายทดสอบ',
    'entityTypeCode': 'ORGANIZATION',
    'isActive': true,
    'creditDays': 0,
    'rowVersion': 'AAAAAAAAAAE=',
  };
  @override
  Future<Map<String, bool>> actions() async => {
    'view': true,
    'create': create,
    'edit': edit,
    'delete': deleteAllowed,
  };
  @override
  Future<Map<String, dynamic>> list({
    String search = '',
    bool? isActive,
    String? entityTypeCode,
    int page = 1,
    int pageSize = 20,
  }) async {
    loads++;
    this.search = search;
    return {
      'items': [row],
      'total': 1,
    };
  }

  @override
  Future<Map<String, dynamic>> get(int id) async => row;
  @override
  Future<Map<String, dynamic>> save(
    Map<String, dynamic> body, {
    int? id,
  }) async {
    if (id == null) {
      creates++;
    } else {
      updates++;
    }
    return {...body, 'vendorID': 7, 'rowVersion': 'AAAAAAAAAAI='};
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Future<void> render(WidgetTester tester, Size size, Widget child) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
    await tester.pumpAndSettle();
  }

  for (final width in [390.0, 1100.0]) {
    testWidgets('Vendor list and popup fit $width', (tester) async {
      final api = FakeVendorApi();
      await render(
        tester,
        Size(width, 820),
        VendorWorkspace(caption: 'ผู้ขาย', api: api),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('ผู้ขายทดสอบ').hitTestable(), findsOneWidget);
      expect(find.text('1-1 จาก 1'), findsOneWidget);
      await tester.tap(find.text('เพิ่ม'));
      await tester.pumpAndSettle();
      expect(find.text('ผู้ขาย > เพิ่ม'), findsOneWidget);
      expect(find.text('บันทึก'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('ยกเลิก'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      api.dispose();
    });
  }
  testWidgets('Search only on submission and view-only permissions', (
    tester,
  ) async {
    final api = FakeVendorApi()
      ..edit = false
      ..create = false
      ..deleteAllowed = false;
    await render(
      tester,
      const Size(1100, 820),
      VendorWorkspace(caption: 'ผู้ขาย', api: api),
    );
    expect(find.text('เพิ่ม'), findsNothing);
    expect(find.byTooltip('ลบ'), findsNothing);
    final before = api.loads;
    await tester.enterText(find.byType(TextField), 'V001');
    await tester.pump();
    expect(api.loads, before);
    await tester.tap(find.text('ค้นหา'));
    await tester.pumpAndSettle();
    expect(api.search, 'V001');
    await tester.tap(find.byTooltip('แสดง').hitTestable());
    await tester.pumpAndSettle();
    expect(find.text('ผู้ขาย > แสดง'), findsOneWidget);
    expect(find.text('บันทึก'), findsNothing);
    await tester.tap(find.text('ปิด'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    api.dispose();
  });
  testWidgets('Create then save updates same vendor and stays open', (
    tester,
  ) async {
    final api = FakeVendorApi();
    await render(
      tester,
      const Size(390, 820),
      VendorForm(api: api, caption: 'ผู้ขาย', canEdit: true, onSaved: () {}),
    );
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'V001');
    await tester.enterText(fields.at(1), 'ผู้ขายใหม่');
    await tester.tap(find.text('บันทึก'));
    await tester.pumpAndSettle();
    expect(api.creates, 1);
    expect(find.text('ผู้ขาย > แก้ไข'), findsOneWidget);
    await tester.tap(find.text('บันทึก'));
    await tester.pumpAndSettle();
    expect(api.creates, 1);
    expect(api.updates, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 31));
    api.dispose();
  });
}
