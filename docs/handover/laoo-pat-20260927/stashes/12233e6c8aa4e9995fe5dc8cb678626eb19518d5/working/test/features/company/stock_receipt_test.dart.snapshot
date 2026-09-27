import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:laoo_service/core/company_setup/company_date_formatter.dart';
import 'package:laoo_service/features/inventory/data/inventory_api.dart';
import 'package:laoo_service/features/inventory/pages/stock_receipt_page.dart';

class ReceiptFakeApi extends InventoryApi {
  ReceiptFakeApi({this.includePackUnit = false});
  final bool includePackUnit;
  int creates = 0, updates = 0;
  bool allowCreate = true, fail = false;
  Map<String, dynamic>? last;
  String? listSearch;
  int? listVendorId;
  int? listWarehouseId;
  @override
  Future<Map<String, bool>> actions(String resource) async => {
    'view': true,
    'create': allowCreate,
    'edit': true,
    'delete': false,
  };
  @override
  Future<List<Map<String, dynamic>>> receipts({
    String? search,
    int? vendorId,
    int? warehouseId,
  }) async {
    listSearch = search;
    listVendorId = vendorId;
    listWarehouseId = warehouseId;
    return [];
  }

  @override
  Future<Map<String, dynamic>> receiptLookup() async => {
    'warehouses': [
      {'warehouseID': 1, 'warehouseCode': 'W1', 'warehouseName': 'คลังหลัก'},
    ],
    'vendors': [
      {'vendorID': 2, 'vendorCode': 'V1', 'vendorName': 'ผู้ขายทดสอบ'},
    ],
    'items': [
      {
        'itemID': 3,
        'itemCode': 'HDD',
        'itemName': 'ฮาร์ดดิสก์',
        'unitCode': 'ชิ้น',
        'stockTrackingCode': 'SERIAL',
        'itemTypeCode': '01',
        'itemTypeName': 'อุปกรณ์',
        if (includePackUnit)
          'receiptUnits': [
            {
              'unitCode': 'ชิ้น',
              'unitName': 'ชิ้น',
              'conversionFactor': 1,
              'isBaseUnit': true,
            },
            {
              'unitCode': 'BOX',
              'unitName': 'กล่อง',
              'conversionFactor': 5,
              'isBaseUnit': false,
            },
          ],
        'coverImageBase64':
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScL3OwAAAABJRU5ErkJggg==',
      },
    ],
    'canCreateVendor': false,
  };
  @override
  Future<Map<String, dynamic>> saveReceipt(
    Map<String, dynamic> body, {
    int? id,
  }) async {
    last = body;
    if (fail) throw Exception('เครือข่ายขัดข้อง');
    if (id == null) {
      creates++;
    } else {
      updates++;
    }
    return {
      'stockReceiptID': 7,
      'receiptCode': 'SR000007',
      'items': [
        for (var i = 0; i < (body['items'] as List).length; i++)
          {
            'lineNo': i + 1,
            'serials': [
              for (
                var j = 0;
                j < ((body['items'][i]['quantity']) as num).toInt();
                j++
              )
                body['items'][i]['serialSourceCode'] == 'INTERNAL'
                    ? 'IS-TEST-$j'
                    : body['items'][i]['serials'][j]['serialNo'],
            ],
          },
      ],
    };
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('receipt package unit converts to base stock quantity', () {
    final line = ReceiptDraftLine({
      'itemID': 3,
      'itemCode': 'HDD',
      'itemName': 'Hard disk',
      'unitCode': 'PIECE',
      'unitName': 'ชิ้น',
      'stockTrackingCode': 'SERIAL',
      'receiptUnits': [
        {
          'unitCode': 'PIECE',
          'unitName': 'ชิ้น',
          'conversionFactor': 1,
          'isBaseUnit': true,
        },
        {
          'unitCode': 'BOX',
          'unitName': 'กล่อง',
          'conversionFactor': 5,
          'isBaseUnit': false,
        },
      ],
    });
    line.quantity.text = '2';
    line.selectUnit('BOX');

    expect(line.unit, 'BOX');
    expect(line.baseQty, 10);
    expect(line.baseQtyText, '10');
    expect(line.body['quantity'], 2);
    expect(line.body['unitCode'], 'BOX');
    line.dispose();
  });

  test('receipt date display follows the configured year format', () {
    final date = DateTime(2026, 9, 10);

    expect(
      CompanyDateFormatter.formatDateByYearFormat(date, 'AD'),
      '10/09/2026',
    );
    expect(
      CompanyDateFormatter.formatDateByYearFormat(date, 'BE'),
      '10/09/2569',
    );
  });

  Future<void> render(WidgetTester t, double width, Widget child) async {
    t.view.physicalSize = Size(width, 1000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(MaterialApp(home: Scaffold(body: child)));
    await t.pumpAndSettle();
  }

  Future<void> tap(WidgetTester t, String label) async {
    final f = find.text(label).last;
    await t.ensureVisible(f);
    await t.tap(f);
    await t.pumpAndSettle();
  }

  testWidgets('item lookup filters by type and previews cover image', (
    t,
  ) async {
    final row = {
      'itemID': 3,
      'itemCode': 'HDD',
      'itemName': 'ฮาร์ดดิสก์',
      'unitCode': 'ชิ้น',
      'itemTypeCode': '01',
      'itemTypeName': 'อุปกรณ์',
      'coverImageBase64':
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScL3OwAAAABJRU5ErkJggg==',
    };
    await render(
      t,
      900,
      ReceiptLookupDialog(label: 'สินค้า *', rows: [row], prefix: 'item'),
    );

    expect(find.text('รูปภาพ'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('item-lookup-type-filter')),
      findsOneWidget,
    );
    expect(find.byTooltip('ดูรูปภาพ'), findsOneWidget);
    await t.tap(find.byTooltip('ดูรูปภาพ'));
    await t.pumpAndSettle();
    expect(find.text('HDD | ฮาร์ดดิสก์'), findsNWidgets(2));
  });

  testWidgets('receipt list filters by vendor and extended search fields', (
    t,
  ) async {
    final api = ReceiptFakeApi();
    await render(
      t,
      1100,
      StockReceiptWorkspace(caption: 'รับสินค้าเข้าคลัง', api: api),
    );
    await t.enterText(
      find.byKey(const ValueKey('stock-receipt-search-filter')),
      'ผู้ส่งมอบ',
    );
    await tap(t, 'ค้นหา');
    expect(api.listSearch, 'ผู้ส่งมอบ');
    expect(api.listVendorId, isNull);

    await t.tap(find.byTooltip('ค้นหาผู้ขาย'));
    await t.pumpAndSettle();
    expect(find.byType(ReceiptLookupDialog), findsOneWidget);
    await tap(t, 'V1 | ผู้ขายทดสอบ');
    await tap(t, 'ค้นหา');
    expect(api.listVendorId, 2);

    await t.tap(
      find.byKey(const ValueKey('stock-receipt-warehouse-filter-null')),
    );
    await t.pumpAndSettle();
    await t.tap(find.textContaining('W1 |').last);
    await t.pumpAndSettle();
    await tap(t, 'ค้นหา');
    expect(api.listWarehouseId, 1);
  });

  testWidgets('receipt line selects configured package unit', (t) async {
    final api = ReceiptFakeApi(includePackUnit: true);
    await render(
      t,
      1100,
      StockReceiptWorkspace(caption: 'รับสินค้าเข้าคลัง', api: api),
    );
    await tap(t, 'เพิ่ม');
    await tap(t, 'เพิ่มรายการ');

    final unit = find.byKey(const ValueKey('receipt-unit-3-ชิ้น'));
    await t.ensureVisible(unit);
    await t.tap(unit);
    await t.pumpAndSettle();
    await tap(t, 'กล่อง');

    expect(find.text('เข้าสต๊อก 5 ชิ้น'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  for (final width in [390.0, 1100.0]) {
    testWidgets('receipt form fits $width; first save does not write', (
      t,
    ) async {
      final api = ReceiptFakeApi();
      await render(
        t,
        width,
        StockReceiptWorkspace(caption: 'รับสินค้าเข้าคลัง', api: api),
      );
      await tap(t, 'เพิ่ม');
      await tap(t, 'เพิ่มรายการ');
      expect(
        find.byKey(const ValueKey('stock-receipt-detail-section-header')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('stock-receipt-detail-footer')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('stock-receipt-detail-table-header')),
        width >= 900 ? findsOneWidget : findsNothing,
      );
      expect(
        find.byKey(const ValueKey('stock-receipt-detail-row-0')),
        findsOneWidget,
      );
      final vendor = find.byWidgetPredicate(
        (w) =>
            w is DropdownButtonFormField<int> &&
            w.decoration.labelText == 'ผู้ขาย *',
      );
      await t.ensureVisible(vendor);
      await t.tap(vendor);
      await t.pumpAndSettle();
      await tap(t, 'V1 | ผู้ขายทดสอบ');
      if (find.text('บันทึก').evaluate().isEmpty) {
        await t.drag(find.byType(ListView).first, const Offset(0, 900));
        await t.pumpAndSettle();
      }
      await tap(t, 'บันทึก');
      expect(find.byType(ReceiptSerialDialog), findsOneWidget);
      expect(api.creates, 0);
      expect(t.takeException(), isNull);
      await tap(t, 'กลับไปแก้ไข');
      expect(api.creates, 0);
      expect(find.text('V1 | ผู้ขายทดสอบ'), findsWidgets);
    });
  }
  testWidgets('confirmed line serials save without reopening dialog', (
    t,
  ) async {
    final api = ReceiptFakeApi();
    await render(
      t,
      1100,
      StockReceiptWorkspace(caption: 'รับสินค้าเข้าคลัง', api: api),
    );
    await tap(t, 'เพิ่ม');
    await tap(t, 'เพิ่มรายการ');
    final vendor = find.byWidgetPredicate(
      (w) =>
          w is DropdownButtonFormField<int> &&
          w.decoration.labelText == 'ผู้ขาย *',
    );
    await t.ensureVisible(vendor);
    await t.tap(vendor);
    await t.pumpAndSettle();
    await tap(t, 'V1 | ผู้ขายทดสอบ');
    await tap(t, '0/1');
    final serial = find.byKey(const ValueKey('receipt-serial-0-0'));
    await t.enterText(serial, 'SN-CONFIRMED');
    await tap(t, 'ยืนยัน');
    expect(find.byType(ReceiptSerialDialog), findsNothing);
    await tap(t, 'บันทึก');
    expect(api.creates, 1);
    expect(find.byType(ReceiptSerialDialog), findsNothing);
  });
  testWidgets('internal serials returned; second save updates same document', (
    t,
  ) async {
    final api = ReceiptFakeApi();
    await render(
      t,
      1100,
      StockReceiptWorkspace(caption: 'รับสินค้าเข้าคลัง', api: api),
    );
    await tap(t, 'เพิ่ม');
    await tap(t, 'รับสินค้า');
    await tap(t, 'ยอดยกมา');
    await tap(t, 'เพิ่มรายการ');
    await tap(t, 'บันทึก');
    await tap(t, 'Serial จากโรงงาน');
    await tap(t, 'สร้างเลขภายใน');
    expect(api.creates, 0);
    await tap(t, 'ยืนยัน');
    expect(api.creates, 1);
    expect(find.text('IS-TEST-0'), findsOneWidget);
    await tap(t, 'ปิด');
    await t.pump(const Duration(seconds: 30));
    await tap(t, 'บันทึก');
    expect(api.creates, 1);
    expect(api.updates, 1);
    expect(find.byType(ReceiptSerialDialog), findsNothing);
    expect(t.takeException(), isNull);
    await t.pump(const Duration(seconds: 30));
  });
  testWidgets('duplicate factory serials prevent write and preserve input', (
    t,
  ) async {
    final l = ReceiptDraftLine({
      'itemID': 3,
      'itemCode': 'HDD',
      'itemName': 'ฮาร์ดดิสก์',
      'stockTrackingCode': 'SERIAL',
      'unitCode': 'ชิ้น',
    })..quantity.text = '2';
    l.setSerials(['SN1', ' sn1 ']);
    var saves = 0;
    await render(
      t,
      390,
      ReceiptSerialDialog(
        lines: [l],
        onSave: () async {
          saves++;
          return true;
        },
      ),
    );
    expect(
      find.byKey(const ValueKey('receipt-serial-item-header-0')),
      findsOneWidget,
    );
    expect(find.text('Serial ซ้ำในเอกสาร'), findsNWidgets(2));
    await tap(t, 'ยืนยัน');
    expect(saves, 0);
    expect(find.text('Serial ซ้ำในเอกสาร'), findsNWidgets(2));
    expect(l.serialValues, ['SN1', 'sn1']);
    await t.pumpWidget(const SizedBox());
    l.dispose();
  });
  testWidgets('no CREATE hides add', (t) async {
    await render(
      t,
      390,
      StockReceiptWorkspace(
        caption: 'รับสินค้าเข้าคลัง',
        api: ReceiptFakeApi()..allowCreate = false,
      ),
    );
    expect(find.text('เพิ่ม'), findsNothing);
  });

  testWidgets('list structural cards stretch to one content width', (t) async {
    await render(
      t,
      1100,
      StockReceiptWorkspace(
        caption: 'รับสินค้าเข้าคลัง',
        api: ReceiptFakeApi(),
      ),
    );

    final caption = t.getRect(
      find.byKey(const ValueKey('stock-receipt-caption-card')),
    );
    final filter = t.getRect(
      find.byKey(const ValueKey('stock-receipt-filter-card')),
    );
    final empty = t.getRect(
      find.byKey(const ValueKey('stock-receipt-empty-card')),
    );
    final pagination = t.getRect(
      find.byKey(const ValueKey('stock-receipt-pagination-card')),
    );

    expect(filter.left, caption.left);
    expect(filter.right, caption.right);
    expect(empty.left, caption.left);
    expect(empty.right, caption.right);
    expect(pagination.left, caption.left);
    expect(pagination.right, caption.right);
  });
}
