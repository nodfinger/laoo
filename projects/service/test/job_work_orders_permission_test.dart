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

  for (final canEdit in [false, true]) {
    testWidgets(
      '17002 ${canEdit ? 'EDIT' : 'VIEW'} shows correct work actions',
      (tester) async {
        final api = _FakeWorkOrdersApi(canEdit: canEdit);
        await tester.binding.setSurfaceSize(const Size(600, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(MaterialApp(home: JobWorkOrdersPage(api: api)));
        await tester.pumpAndSettle();
        expect(api.requestedMenuCode, '17002');
        await tester.tap(find.text('เปิดรายละเอียด'));
        await tester.pumpAndSettle();
        expect(
          find.text('เริ่มดำเนินการ'),
          canEdit ? findsOneWidget : findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}

class _FakeWorkOrdersApi extends ServiceRequestApi {
  _FakeWorkOrdersApi({required this.canEdit});

  final bool canEdit;
  String? requestedMenuCode;

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
    requestedMenuCode = menuCode;
    return {
      'items': [
        {
          'requestId': 42,
          'requestNo': 'SR42',
          'subject': 'ทดสอบใบงาน',
          'statusCode': 'RECEIVED',
        },
      ],
      'total': 1,
    };
  }

  @override
  Future<Map<String, dynamic>> detail(int id, {String? menuCode}) async => {
    'requestId': id,
    'requestNo': 'SR42',
    'statusCode': 'RECEIVED',
    'parts': <Map<String, dynamic>>[],
  };

  @override
  Future<List<Map<String, dynamic>>> attachments(
    int requestId, {
    String? menuCode,
  }) async => [];
}
