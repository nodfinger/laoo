import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laoo_service/features/job_work_orders/pages/job_work_orders_page.dart';
import 'package:laoo_service/features/service_request/data/service_request_api.dart';
import 'package:laoo_service/features/support/presentation/widgets/support_workspace_shell.dart';

void main() {
  setUpAll(() {
    configureServiceWorkspaceShell(
      ({
        required String pageTitle,
        required String activeMenu,
        required Widget child,
      }) => Scaffold(body: child),
    );
  });

  testWidgets('17002 mobile load error has retry and does not pretend empty', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = _RetryWorkOrdersApi();
    await tester.pumpWidget(MaterialApp(home: JobWorkOrdersPage(api: api)));
    await tester.pumpAndSettle();
    expect(find.textContaining('ไม่สามารถโหลดทะเบียนใบงานได้'), findsOneWidget);
    expect(find.text('ไม่พบใบงาน'), findsNothing);
    expect(find.text('ลองอีกครั้ง'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('ลองอีกครั้ง'));
    await tester.pumpAndSettle();
    expect(api.listCalls, 2);
    expect(find.text('SR-17002-TEST'), findsOneWidget);
    expect(find.text('ไม่สามารถโหลดทะเบียนใบงานได้'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('17002 part picker fits mobile', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = _RetryWorkOrdersApi(canEdit: true);
    await tester.pumpWidget(MaterialApp(home: JobWorkOrdersPage(api: api)));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('เปิดรายละเอียด'));
    await tester.drag(find.byType(ListView).first, const Offset(0, -180));
    await tester.pumpAndSettle();
    await tester.tap(find.text('เปิดรายละเอียด'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('เพิ่มอะไหล่'));
    await tester.tap(find.text('เพิ่มอะไหล่'));
    await tester.pumpAndSettle();
    expect(find.textContaining('เพิ่มอะไหล่ที่ใช้ซ่อม'), findsOneWidget);
    final picker = tester.widget<AlertDialog>(find.byType(AlertDialog).last);
    expect(picker.backgroundColor, Colors.white);
    expect(find.byType(Divider), findsAtLeastNWidgets(2));
    await tester.tap(find.text('เพิ่มรายการ'));
    await tester.pumpAndSettle();
    expect(find.text('กรุณาเลือกคลังและอะไหล่'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _RetryWorkOrdersApi extends ServiceRequestApi {
  _RetryWorkOrdersApi({this.canEdit = false});
  final bool canEdit;
  int listCalls = 0;

  @override
  Future<Map<String, dynamic>> actions() async => {'workOrderEdit': canEdit};

  @override
  Future<Map<String, dynamic>> list({
    String search = '',
    String status = '',
    bool selfService = false,
    int page = 1,
    String? menuCode,
  }) async {
    listCalls++;
    if (listCalls == 1 && !canEdit) throw StateError('temporary failure');
    return {
      'total': 1,
      'items': [
        {
          'requestId': 42,
          'requestNo': 'SR-17002-TEST',
          'subject': 'หัวข้อทดสอบการตัดบรรทัดบนจอมือถือ',
          'statusCode': 'IN_PROGRESS',
          'requesterName': 'ผู้แจ้งทดสอบ',
          'locationSnapshot': 'อาคารทดสอบ ชั้นสอง ห้องสอง',
        },
      ],
    };
  }

  @override
  Future<Map<String, dynamic>> detail(int id, {String? menuCode}) async => {
    'requestId': id,
    'requestNo': 'SR-17002-TEST',
    'statusCode': 'IN_PROGRESS',
    'parts': <Map<String, dynamic>>[],
  };

  @override
  Future<List<Map<String, dynamic>>> attachments(
    int requestId, {
    String? menuCode,
  }) async => [];

  @override
  Future<Map<String, dynamic>> partsLookup() async => {
    'warehouses': [
      {
        'warehouseId': 1,
        'warehouseCode': 'TEST',
        'warehouseName': 'คลังทดสอบ',
        'isDefault': true,
      },
    ],
    'items': [
      {
        'warehouseId': 1,
        'itemId': 2,
        'itemCode': 'PART-TEST',
        'itemName': 'อะไหล่ทดสอบ',
        'availableQuantity': 2,
        'stockTrackingCode': 'NONE',
        'unitCode': 'PCS',
        'unitCost': 1,
      },
    ],
    'serials': <Map<String, dynamic>>[],
  };
}
