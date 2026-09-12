import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'package:laoo_time/core/config/app_config.dart';
import 'package:laoo_time/time_feature.dart';

void main() {
  test('Time reserves the approved project and screen contracts', () {
    expect(AppConfig.projectCode, 'LAOO_TIME');
    expect(AppConfig.apiBaseUrl, 'http://localhost:5080');
    expect(TimeMenuGroups.setup, '28');
    expect(TimeRoutes.all, hasLength(11));
    expect(TimeRoutes.shiftTemplates.menuCode, '27001');
    expect(TimeRoutes.scheduleGroups.menuCode, '27002');
    expect(TimeRoutes.rotationPatterns.menuCode, '27003');
    expect(TimeRoutes.employeeSchedules.menuCode, '27004');
    expect(TimeRoutes.employeeSettings.menuCode, '28001');
    expect(TimeRoutes.employeeSettings.screenType, 2);
    expect(TimeRoutes.systemSettings.menuCode, '28002');
    expect(TimeRoutes.systemSettings.screenType, 2);
    expect(TimeRoutes.timeCorrectionProxy.menuCode, '26001');
    expect(TimeRoutes.timeCorrectionProxy.screenType, 4);
    expect(TimeRoutes.timeApprovalInbox.menuCode, '26002');
    expect(TimeRoutes.timeApprovalInbox.screenType, 3);
    expect(TimeRoutes.onBehalfReasons.menuCode, '28003');
    expect(TimeRoutes.onBehalfReasons.screenType, 1);
    expect(TimeRoutes.adjustmentReasons.menuCode, '28004');
    expect(TimeRoutes.adjustmentReasons.screenType, 1);
    expect(TimeRoutes.myTimeCorrections.menuCode, '30001');
    expect(TimeRoutes.myTimeCorrections.screenType, 4);
    expect(TimeRoutes.implemented, hasLength(11));
    expect(buildTimeFeatureRoutes(), hasLength(11));
  });

  testWidgets('Time delegates workspace composition to the Center host', (
    tester,
  ) async {
    configureTimeFeatureHost(({
      required pageTitle,
      required activeMenu,
      required child,
    }) {
      return Directionality(
        textDirection: TextDirection.ltr,
        child: Column(children: [Text('$pageTitle:$activeMenu'), child]),
      );
    });

    await tester.pumpWidget(
      buildTimeWorkspaceShell(
        pageTitle: 'Time',
        activeMenu: 'timeSystemSettings',
        child: const Text('content'),
      ),
    );

    expect(find.text('Time:timeSystemSettings'), findsOneWidget);
    expect(find.text('content'), findsOneWidget);
  });

  test(
    'employee settings repository preserves paging and update contract',
    () async {
      final api = _FakeApi();
      final repository = EmployeeTimeSettingsRepository(api);

      final actions = await repository.actions();
      expect(actions.menuCode, '28001');
      expect(actions.screenType, 2);
      expect(actions.canEdit, isTrue);

      final page = await repository.list(
        search: 'EMP-01',
        isActive: true,
        requiresAttendance: false,
        page: 2,
        pageSize: 20,
      );
      expect(page.total, 1);
      expect(page.items.single.employeeCode, 'EMP-01');
      expect(page.items.single.deviceCode, 'A-100');
      expect(api.lastQuery?['requirementCode'], 'EXEMPT');

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
      expect(api.lastPath, '/api/time/employee-settings/10');
      expect((api.lastBody as Map)['effectiveFrom'], '2026-09-12');
    },
  );

  testWidgets('employee time settings opens the update-only action dialog', (
    tester,
  ) async {
    final api = _FakeApi();
    configureTimeFeatureHost(
      ({required pageTitle, required activeMenu, required child}) => child,
      apiClientFactory: () => api,
      messageBuilder: ({required message, required error, required onClose}) =>
          Text(message),
      pageSizeProvider: () => 20,
    );

    await tester.pumpWidget(
      const MaterialApp(home: EmployeeTimeSettingsPage()),
    );
    await tester.pumpAndSettle();

    expect(find.text('พนักงาน–ลงเวลาทำงาน'), findsOneWidget);
    expect(find.textContaining('EMP-01'), findsOneWidget);
    expect(find.textContaining('A-100'), findsOneWidget);

    await tester.tap(find.byTooltip('แก้ไข'));
    await tester.pumpAndSettle();
    expect(find.text('แก้ไขการลงเวลาทำงาน'), findsOneWidget);
    expect(find.text('เหตุผลในการแก้ไข *'), findsOneWidget);
    expect(find.text('ยกเลิก'), findsOneWidget);
    expect(find.text('บันทึก'), findsOneWidget);
  });
  test(
    'system settings repository preserves versioned policy contract',
    () async {
      final api = _FakeSystemApi();
      final repository = TimeSystemSettingsRepository(api);

      final actions = await repository.actions();
      expect(actions.menuCode, '28002');
      expect(actions.canManageApprovalProfile, isTrue);

      final settings = await repository.get(
        effectiveDate: DateTime(2026, 9, 12),
      );
      expect(settings.defaultProfileCode, 'OWNER_OPERATED');
      expect(settings.requestPolicies['TIME_CORRECTION'], 'PROXY_ONLY');
      expect(settings.employeeWithoutLoginCount, 2);

      await repository.update(
        TimeSystemSettingsUpdate(
          effectiveFrom: DateTime(2026, 9, 12),
          defaultProfileCode: 'SEGREGATED_WORKFLOW',
          processProfiles: const {
            'LEAVE': 'DEFAULT',
            'TIME': 'OWNER_OPERATED',
            'OT': 'DEFAULT',
            'ENTITLEMENT': 'DEFAULT',
            'PERIOD': 'DEFAULT',
          },
          requestPolicies: const {
            'LEAVE_REQUEST': 'SELF_SERVICE_AND_PROXY',
            'LEAVE_CANCELLATION': 'SELF_SERVICE_AND_PROXY',
            'TIME_CORRECTION': 'PROXY_ONLY',
            'RECONFIRMATION': 'PROXY_ONLY',
          },
          reason: 'policy update',
          stateToken: 'STATE-1',
        ),
      );
      expect(api.lastPath, '/api/time/system-settings');
      expect((api.lastBody as Map)['stateToken'], 'STATE-1');
    },
  );

  testWidgets('system settings renders update-only policy sections', (
    tester,
  ) async {
    configureTimeFeatureHost(
      ({required pageTitle, required activeMenu, required child}) => child,
      apiClientFactory: _FakeSystemApi.new,
      messageBuilder: ({required message, required error, required onClose}) =>
          Text(message),
    );

    await tester.pumpWidget(const MaterialApp(home: TimeSystemSettingsPage()));
    await tester.pumpAndSettle();

    expect(find.text('กำหนดค่าระบบเวลา'), findsWidgets);
    expect(find.text('รูปแบบการอนุมัติ'), findsOneWidget);
    expect(find.text('ผู้เริ่มคำขอ'), findsOneWidget);
    expect(find.textContaining('ไม่มี Active Login'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('บันทึก'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('บันทึก'), findsOneWidget);
  });
}

class _FakeApi implements JsonApiClient {
  String? lastPath;
  Map<String, String>? lastQuery;
  Object? lastBody;

  @override
  Future<dynamic> get(
    String path, {
    Map<String, String>? query,
    bool authenticated = true,
  }) async {
    lastPath = path;
    lastQuery = query;
    if (path.endsWith('/actions')) {
      return {
        'menuCode': '28001',
        'caption': 'พนักงาน–ลงเวลาทำงาน',
        'screenType': 2,
        'view': true,
        'edit': true,
      };
    }
    return {
      'total': 1,
      'page': 2,
      'pageSize': 20,
      'items': [
        {
          'employeeId': 10,
          'employeeCode': 'EMP-01',
          'fullName': 'พนักงานหนึ่ง',
          'isActive': true,
          'requiresAttendance': false,
          'deviceCode': 'A-100',
          'hasActiveLogin': true,
        },
      ],
    };
  }

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

class _FakeSystemApi implements JsonApiClient {
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
        'menuCode': '28002',
        'caption': 'กำหนดค่าระบบเวลา',
        'screenType': 2,
        'view': true,
        'edit': true,
        'manageApprovalProfile': true,
      };
    }
    return {
      'effectiveDate': '2026-09-12',
      'defaultProfileCode': 'OWNER_OPERATED',
      'processProfiles': {
        'LEAVE': 'DEFAULT',
        'TIME': 'OWNER_OPERATED',
        'OT': 'DEFAULT',
        'ENTITLEMENT': 'DEFAULT',
        'PERIOD': 'DEFAULT',
      },
      'requestPolicies': {
        'LEAVE_REQUEST': 'SELF_SERVICE_AND_PROXY',
        'LEAVE_CANCELLATION': 'SELF_SERVICE_AND_PROXY',
        'TIME_CORRECTION': 'PROXY_ONLY',
        'RECONFIRMATION': 'PROXY_ONLY',
      },
      'activeEmployeeCount': 10,
      'employeeWithoutLoginCount': 2,
      'selfServiceReady': false,
      'stateToken': 'STATE-1',
    };
  }

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
