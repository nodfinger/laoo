import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'package:laoo_time/core/config/app_config.dart';
import 'package:laoo_time/time_feature.dart';

void main() {
  test('Time exposes 28001 and keeps 28002 as preview', () {
    expect(AppConfig.projectCode, 'LAOO_TIME');
    expect(TimeRoutes.all, hasLength(2));
    expect(TimeRoutes.employeeSettings.menuCode, '28001');
    expect(TimeRoutes.employeeSettings.screenType, 2);
    expect(TimeRoutes.employeeSettings.isImplemented, isTrue);
    expect(TimeRoutes.systemSettings.menuCode, '28002');
    expect(TimeRoutes.systemSettings.isImplemented, isFalse);
    expect(TimeRoutes.implemented, [TimeRoutes.employeeSettings]);
    expect(buildTimeFeatureRoutes(), hasLength(1));
  });

  test(
    'employee settings repository reads detail and sends row versions',
    () async {
      final api = _FakeApi();
      final repository = EmployeeTimeSettingsRepository(api);

      final page = await repository.list(page: 1, pageSize: 20);
      expect(page.items.single.personId, 101);
      expect(page.items.single.divisionName, 'ฝ่ายขาย');
      expect(page.items.single.departmentName, 'ขายในประเทศ');

      final detail = await repository.detail(10);
      expect(api.lastPath, '/api/time/employee-settings/10');
      expect(detail.requirementHistory, hasLength(1));
      expect(detail.auditHistory.single.actorName, 'ผู้ดูแลเวลา');

      await repository.update(
        10,
        EmployeeTimeSettingsUpdate(
          requiresAttendance: true,
          deviceCode: 'A-101',
          effectiveFrom: DateTime(2026, 9, 12),
          reason: 'ปรับตามหน้าที่งาน',
          requirementRowVersion: '0001',
          deviceCodeRowVersion: '0002',
        ),
      );
      expect((api.lastBody as Map)['requirementRowVersion'], '0001');
      expect((api.lastBody as Map)['deviceCodeRowVersion'], '0002');
    },
  );

  testWidgets('28001 uses an inline edit panel and loads employee history', (
    tester,
  ) async {
    final api = _FakeApi();
    _configureHost(api);

    await tester.pumpWidget(
      const MaterialApp(home: EmployeeTimeSettingsPage()),
    );
    await tester.pumpAndSettle();
    expect(find.text('เลือกพนักงานเพื่อดูรายละเอียดและแก้ไข'), findsOneWidget);

    await tester.tap(find.text('EMP-01').first);
    await tester.pumpAndSettle();
    expect(find.text('แก้ไขการลงเวลาทำงาน'), findsOneWidget);
    expect(find.text('ประวัติการกำหนดค่า'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('PersonID'), findsOneWidget);
    expect(find.text('ฝ่ายขาย'), findsWidgets);
  });
}

void _configureHost(JsonApiClient api) {
  configureTimeFeatureHost(
    ({required pageTitle, required activeMenu, required child}) => child,
    apiClientFactory: () => api,
    messageBuilder: ({required message, required error, required onClose}) =>
        Text(message),
    pageSizeProvider: () => 20,
    uiTokens: const TimeUiTokens(
      contentMargin: 10,
      cardPadding: 10,
      cardSpacing: 10,
      formSpacing: 12,
      radius: 4,
      paginationHeight: 56,
      buttonHeight: 48,
      backgroundColor: Color(0xFFF8F9FB),
      pageCaptionStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      sectionTitleStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      inputStyle: TextStyle(fontSize: 14),
      tableStyle: TextStyle(fontSize: 14),
      buttonStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
    ),
  );
}

class _FakeApi implements JsonApiClient {
  String? lastPath;
  Object? lastBody;

  @override
  Future<dynamic> get(
    String path, {
    Map<String, String>? query,
    bool authenticated = true,
  }) async {
    lastPath = path;
    if (path.endsWith('/actions')) {
      return {
        'menuCode': '28001',
        'caption': 'พนักงาน–ลงเวลาทำงาน',
        'screenType': 2,
        'view': true,
        'edit': true,
      };
    }
    if (path.endsWith('/10')) return _detail;
    return {
      'total': 1,
      'page': 1,
      'pageSize': 20,
      'items': [_employee],
    };
  }

  static const _employee = {
    'employeeId': 10,
    'personId': 101,
    'employeeCode': 'EMP-01',
    'fullName': 'พนักงานหนึ่ง',
    'isActive': true,
    'divisionOrgUnitId': 20,
    'divisionName': 'ฝ่ายขาย',
    'departmentOrgUnitId': 21,
    'departmentName': 'ขายในประเทศ',
    'requiresAttendance': false,
    'requirementRowVersion': '0001',
    'deviceCode': 'A-100',
    'deviceCodeRowVersion': '0002',
    'hasActiveLogin': true,
    'businessDate': '2026-09-11',
  };

  static const _detail = {
    'employee': _employee,
    'requirementHistory': [
      {
        'requirementCode': 'EXEMPT',
        'effectiveFrom': '2026-09-11',
        'reason': 'กำหนดครั้งแรก',
      },
    ],
    'deviceCodeHistory': [
      {'deviceCode': 'A-100', 'effectiveFrom': '2026-09-11T00:00:00'},
    ],
    'auditHistory': [
      {
        'reason': 'กำหนดครั้งแรก',
        'actorUserId': 1,
        'actorName': 'ผู้ดูแลเวลา',
        'occurredDateUtc': '2026-09-11T02:00:00Z',
      },
    ],
  };

  @override
  Future<dynamic> put(
    String path, {
    Object? body,
    bool authenticated = true,
  }) async {
    lastPath = path;
    lastBody = body;
  }

  @override
  Future<dynamic> post(
    String path, {
    Object? body,
    bool authenticated = true,
  }) => throw UnimplementedError();

  @override
  Future<dynamic> delete(
    String path, {
    Object? body,
    Map<String, String>? query,
    bool authenticated = true,
  }) => throw UnimplementedError();
}
