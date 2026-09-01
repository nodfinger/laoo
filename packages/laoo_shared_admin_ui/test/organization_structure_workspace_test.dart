import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laoo_shared_admin/laoo_shared_admin.dart';
import 'package:laoo_shared_admin_ui/laoo_shared_admin_ui.dart';

void main() {
  SharedAdminUiTokens tokens() => const SharedAdminUiTokens(
    contentMargin: EdgeInsets.all(10),
    cardPadding: EdgeInsets.all(10),
    cardSpacing: 10,
    itemSpacing: 6,
    radius: 4,
    compactBreakpoint: 900,
    paginationHeight: 56,
    captionStyle: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      color: Colors.black,
    ),
  );

  Widget app({_FakeApi? api, int screenType = 1}) => MaterialApp(
    home: Scaffold(
      body: OrganizationStructureWorkspace(
        caption: 'โครงสร้างองค์กร',
        repository: OrganizationRepository(
          api ?? _FakeApi(),
          scope: LaooOwnerScope.support,
        ),
        errorText: (error) => error.toString(),
        titleBuilder: (_, title, _) => Text(title),
        messageBuilder: (_, message, error, onClose) =>
            Material(child: Text(message)),
        tokens: tokens(),
        screenType: screenType,
      ),
    ),
  );

  testWidgets('shows permission actions and opens inline division form', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();

    expect(find.text('HQ - ฝ่ายสำนักงานใหญ่'), findsOneWidget);
    expect(find.text('SERVICE - แผนกบริการ'), findsOneWidget);
    expect(find.byTooltip('แก้ไข'), findsNWidgets(2));
    expect(find.byTooltip('ลบ'), findsNWidgets(2));

    await tester.tap(find.widgetWithText(FilledButton, 'เพิ่มฝ่าย'));
    await tester.pumpAndSettle();

    expect(find.text('โครงสร้างองค์กร > เพิ่มฝ่าย'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('รหัสฝ่าย *'), findsOneWidget);
  });

  testWidgets('screen type blocks CRUD actions', (tester) async {
    await tester.pumpWidget(app(screenType: 3));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, 'เพิ่มฝ่าย'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'เพิ่มแผนก'), findsNothing);
    expect(find.byTooltip('แก้ไข'), findsNothing);
    expect(find.byTooltip('ลบ'), findsNothing);
  });

  testWidgets('mobile master detail and inline form do not overflow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.widgetWithText(FilledButton, 'เพิ่มฝ่าย'));
    await tester.pumpAndSettle();

    expect(find.text('โครงสร้างองค์กร > เพิ่มฝ่าย'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakeApi implements JsonApiClient {
  final Map<String, bool> actions = const {
    'view': true,
    'create': true,
    'edit': true,
    'delete': true,
  };

  @override
  Future<dynamic> get(
    String path, {
    Map<String, String>? query,
    bool authenticated = true,
  }) async {
    if (path.endsWith('/actions')) return actions;
    return {
      'orgStructureType': 2,
      'units': [
        {
          'orgUnitId': 1,
          'companyId': 7,
          'unitType': 'DIV',
          'parentOrgUnitId': null,
          'unitCode': 'HQ',
          'nameTh': 'ฝ่ายสำนักงานใหญ่',
          'nameEn': 'Headquarters',
          'isActive': true,
        },
        {
          'orgUnitId': 2,
          'companyId': 7,
          'unitType': 'DEP',
          'parentOrgUnitId': 1,
          'unitCode': 'SERVICE',
          'nameTh': 'แผนกบริการ',
          'nameEn': 'Service',
          'isActive': true,
        },
      ],
    };
  }

  @override
  Future<dynamic> post(
    String path, {
    Object? body,
    bool authenticated = true,
  }) async {}

  @override
  Future<dynamic> put(
    String path, {
    Object? body,
    bool authenticated = true,
  }) async {}

  @override
  Future<dynamic> delete(
    String path, {
    Object? body,
    Map<String, String>? query,
    bool authenticated = true,
  }) async {}
}
