import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'package:laoo_time/features/payroll_exports/payroll_export_page.dart';
import 'package:laoo_time/features/payroll_exports/payroll_export_repository.dart';
import 'package:laoo_time/features/time/time_feature_host.dart';

void main() {
  test(
    'payroll export uses active lookup without master profile access',
    () async {
      final api = _FakePayrollApi();
      final repository = PayrollExportRepository(api);

      final actions = await repository.actions('25003');
      expect(actions['create'], isTrue);
      expect(api.lastQuery, {'menuCode': '25003'});

      final profiles = await repository.activeProfileLookup();
      expect(api.lastPath, '/api/time/payroll-exports/profiles/lookup');
      expect(profiles.single['profileCode'], 'ACTIVE');
    },
  );

  test('profile deletion carries the selected row version', () async {
    final api = _FakePayrollApi();
    final repository = PayrollExportRepository(api);

    await repository.deleteProfile({
      'profileId': 7,
      'rowVersion': '0011223344556677',
    });

    expect(api.lastPath, '/api/time/payroll-exports/profiles/7');
    expect(api.lastQuery, {'rowVersion': '0011223344556677'});
  });

  testWidgets(
    'profile actions follow login permissions and require confirmation',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1100, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = _FakePayrollWidgetApi();
      configureTimeFeatureHost(
        ({required pageTitle, required activeMenu, required child}) =>
            Scaffold(body: child),
        apiClientFactory: () => api,
        messageBuilder:
            ({required message, required error, required onClose}) =>
                Text(message),
        uiTokens: _testTokens,
      );
      await tester.pumpWidget(
        const MaterialApp(
          home: PayrollExportPage(mode: PayrollExportMode.profiles),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('แก้ไขรูปแบบ Export'), findsNothing);
      expect(find.byTooltip('ลบรูปแบบ Export'), findsNothing);
      expect(find.text('เพิ่ม'), findsNothing);

      api.canEdit = true;
      api.canDelete = true;
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        const MaterialApp(
          home: PayrollExportPage(mode: PayrollExportMode.profiles),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('แก้ไขรูปแบบ Export'), findsOneWidget);
      expect(find.byTooltip('ลบรูปแบบ Export'), findsOneWidget);
      await tester.binding.setSurfaceSize(const Size(390, 700));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.byTooltip('ลบรูปแบบ Export'));
      await tester.pumpAndSettle();
      expect(find.textContaining('ไม่สามารถเรียกคืนได้'), findsOneWidget);
      await tester.tap(find.text('ยกเลิก'));
      await tester.pumpAndSettle();
      expect(api.deletes, 0);

      await tester.tap(find.byTooltip('ลบรูปแบบ Export'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ลบ'));
      await tester.pumpAndSettle();
      expect(api.deletes, 1);
      expect(find.byTooltip('ลบรูปแบบ Export'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

final _testTokens = TimeUiTokens(
  contentMargin: const EdgeInsets.all(10),
  cardPadding: const EdgeInsets.all(10),
  cardSpacing: 10,
  itemSpacing: 6,
  radius: 4,
  compactBreakpoint: 900,
  paginationHeight: 56,
  captionStyle: const TextStyle(fontSize: 18),
  sectionStyle: const TextStyle(fontSize: 16),
  inputStyle: const TextStyle(fontSize: 14),
  inputLabelStyle: const TextStyle(fontSize: 16),
  tableStyle: const TextStyle(fontSize: 14),
  buttonStyle: const TextStyle(fontSize: 13),
  buttonHeight: 48,
  primaryColor: Colors.teal,
  borderColor: Colors.grey,
  backgroundColor: Colors.white,
  businessDate: DateTime(2026, 9, 29),
);

class _FakePayrollWidgetApi extends _FakePayrollApi {
  bool canEdit = false;
  bool canDelete = false;
  bool active = true;
  bool exists = true;
  int deletes = 0;

  @override
  Future<dynamic> get(
    String path, {
    Map<String, String>? query,
    bool authenticated = true,
  }) async {
    if (path == '/api/user-favorites') return <dynamic>[];
    if (path.endsWith('/actions')) {
      return {
        'menuCode': '28013',
        'caption': 'รูปแบบ Export Payroll',
        'screenType': 1,
        'view': true,
        'create': false,
        'edit': canEdit,
        'delete': canDelete,
      };
    }
    return {
      'items': exists
          ? [
              {
                'profileId': 7,
                'profileCode': 'ACTIVE',
                'profileName': 'Active',
                'formatCode': 'TEXT',
                'encoding': 'UTF8',
                'isActive': active,
                'rowVersion': '0011223344556677',
              },
            ]
          : <Map<String, dynamic>>[],
    };
  }

  @override
  Future<void> delete(
    String path, {
    Object? body,
    Map<String, String>? query,
    bool authenticated = true,
  }) async {
    deletes++;
    exists = false;
  }
}

class _FakePayrollApi implements JsonApiClient {
  String? lastPath;
  Map<String, String>? lastQuery;

  @override
  Future<dynamic> get(
    String path, {
    Map<String, String>? query,
    bool authenticated = true,
  }) async {
    lastPath = path;
    lastQuery = query;
    if (path.endsWith('/actions')) {
      return {'menuCode': '25003', 'view': true, 'create': true};
    }
    return {
      'items': [
        {'profileId': 7, 'profileCode': 'ACTIVE', 'profileName': 'Active'},
      ],
    };
  }

  @override
  Future<void> delete(
    String path, {
    Object? body,
    Map<String, String>? query,
    bool authenticated = true,
  }) async {
    lastPath = path;
    lastQuery = query;
  }

  @override
  Future<void> post(String path, {Object? body, bool authenticated = true}) =>
      throw UnimplementedError();

  @override
  Future<void> put(String path, {Object? body, bool authenticated = true}) =>
      throw UnimplementedError();
}
