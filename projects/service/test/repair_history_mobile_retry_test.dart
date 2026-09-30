import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laoo_service/features/repair_history/pages/repair_history_page.dart';
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

  testWidgets('19002 mobile error retry then read-only detail popup', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = _RepairHistoryApi();
    await tester.pumpWidget(MaterialApp(home: RepairHistoryPage(api: api)));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('ไม่สามารถโหลดประวัติการซ่อมได้'),
      findsOneWidget,
    );
    expect(find.text('ไม่พบประวัติการซ่อมที่ปิดงานแล้ว'), findsNothing);
    expect(find.text('ลองอีกครั้ง'), findsOneWidget);
    expect(find.text('0-0 จาก 0'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('ลองอีกครั้ง'));
    await tester.pumpAndSettle();
    expect(api.listCalls, 2);
    expect(find.text('SR-HISTORY-TEST'), findsOneWidget);
    expect(find.text('1-1 จาก 1'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('ดูรายละเอียด'));
    await tester.pumpAndSettle();
    final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
    expect(dialog.backgroundColor, Colors.white);
    expect(
      find.textContaining('ประวัติการซ่อมและค่าใช้จ่าย > SR-HISTORY-TEST'),
      findsOneWidget,
    );
    expect(find.byType(Divider), findsAtLeastNWidgets(2));
    expect(find.text('ไม่มีการตัดอะไหล่ในงานนี้'), findsOneWidget);
    expect(find.text('บันทึก'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _RepairHistoryApi extends ServiceRequestApi {
  int listCalls = 0;

  @override
  Future<Map<String, dynamic>> repairHistory({
    String search = '',
    int page = 1,
  }) async {
    listCalls++;
    if (listCalls == 1) throw StateError('simulated history outage');
    return {
      'total': 1,
      'items': [
        {
          'requestId': 901,
          'requestNo': 'SR-HISTORY-TEST',
          'requesterName': 'ผู้ทดสอบ',
          'locationSnapshot': 'อาคารทดสอบ',
          'equipmentName': 'เครื่องทดสอบ',
          'subject': 'ซ่อมอุปกรณ์',
          'assignedEmployeeName': 'ช่างทดสอบ',
          'completedDate': '2026-09-30T10:00:00',
          'partsTotal': 0,
        },
      ],
    };
  }

  @override
  Future<Map<String, dynamic>> detail(int id, {String? menuCode}) async => {
    'requestId': id,
    'requestNo': 'SR-HISTORY-TEST',
    'requesterName': 'ผู้ทดสอบ',
    'parts': <Map<String, dynamic>>[],
    'partsTotal': 0,
  };

  @override
  Future<List<Map<String, dynamic>>> attachments(
    int requestId, {
    String? menuCode,
  }) async => [];
}
