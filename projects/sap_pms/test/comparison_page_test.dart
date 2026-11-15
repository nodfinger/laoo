import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laoo_sap_pms/sap_pms_feature.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';

class _Api implements JsonApiClient {
  _Api(this.canExport);
  final bool canExport;
  @override
  Future<dynamic> get(
    String path, {
    Map<String, String>? query,
    bool authenticated = true,
  }) async => path.endsWith('/history')
      ? {
          'items': [
            {
              'comparedAt': '2026-11-15T10:00:00Z',
              'employeeName': 'ผู้ทดสอบ',
              'pmsFileName': 'PMS.xlsx',
              'pmsRecordCount': 3,
              'sapFileName': 'SAP.xlsx',
              'sapRecordCount': 2,
              'dateFrom': null,
              'dateTo': null,
              'totalCount': 3,
              'normalCount': 1,
              'problemCount': 1,
              'waitingCount': 1,
              'problemDocumentNumbers': 'PR001',
            },
          ],
          'total': 1,
        }
      : {'canExport': canExport};
  @override
  Future<dynamic> post(
    String path, {
    Object? body,
    bool authenticated = true,
  }) async => null;
  @override
  Future<dynamic> put(
    String path, {
    Object? body,
    bool authenticated = true,
  }) async => null;
  @override
  Future<dynamic> delete(
    String path, {
    Object? body,
    Map<String, String>? query,
    bool authenticated = true,
  }) async => null;
}

const _tokens = LaooWorkspaceUiTokens(
  contentMargin: EdgeInsets.all(10),
  cardPadding: EdgeInsets.all(10),
  sectionSpacing: 8,
  captionFilterSpacing: 8,
  itemSpacing: 8,
  radius: 4,
  compactBreakpoint: 600,
  paginationHeight: 56,
  captionStyle: TextStyle(fontSize: 18),
  sectionStyle: TextStyle(fontSize: 16),
  inputStyle: TextStyle(fontSize: 16),
  tableStyle: TextStyle(fontSize: 14),
  buttonStyle: TextStyle(fontSize: 13),
  buttonHeight: 48,
  primaryColor: Colors.teal,
  borderColor: Colors.grey,
  backgroundColor: Colors.white,
);

void main() {
  for (final allowed in [true, false]) {
    testWidgets('export action respects permission $allowed', (tester) async {
      configureSapPmsFeatureHost(
        ({required pageTitle, required activeMenu, required child}) =>
            Scaffold(body: child),
        apiClientFactory: () => _Api(allowed),
        apiClientDisposer: (_) {},
        uiTokensProvider: () => _tokens,
        menuTitleResolver: (_, __) async => 'PMS SAP',
        messagePresenter: (_, {required message, required error}) {},
      );
      await tester.pumpWidget(const MaterialApp(home: SapPmsComparisonPage()));
      await tester.pumpAndSettle();
      expect(find.text('PMS: เลือกไฟล์ Excel'), findsOneWidget);
      expect(find.text('SAP: เลือกไฟล์ Excel'), findsOneWidget);
      expect(
        find.text('ส่งออก Excel'),
        allowed ? findsOneWidget : findsNothing,
      );
      await tester.tap(find.text('ตรวจสอบประวัติ'));
      await tester.pumpAndSettle();
      expect(find.text('ประวัติการเปรียบเทียบ (แสดง 10 ครั้งล่าสุด)'), findsOneWidget);
      expect(find.textContaining('PR001'), findsOneWidget);
    });
  }
}
