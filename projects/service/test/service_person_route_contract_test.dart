import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laoo_service/features/company/person/data/service_person_api.dart';
import 'package:laoo_service/service_feature.dart';

void main() {
  test('menus 14005 and 14006 are Service-owned CRUD routes', () {
    final customer = ServiceRoutes.byMenuCode('14005');
    final resident = ServiceRoutes.byMenuCode('14006');

    expect(customer.projectCode, ServiceProject.code);
    expect(customer.screenType, 1);
    expect(customer.routeName, 'serviceCustomers');
    expect(customer.routePath, '/service/customers');
    expect(resident.projectCode, ServiceProject.code);
    expect(resident.screenType, 1);
    expect(resident.routeName, 'serviceResidents');
    expect(resident.routePath, '/service/residents');
  });

  test('Service routes remain unique', () {
    final names = ServiceRoutes.all.map((route) => route.routeName).toList();
    final paths = ServiceRoutes.all.map((route) => route.routePath).toList();

    expect(names.toSet(), hasLength(names.length));
    expect(paths.toSet(), hasLength(paths.length));
  });

  for (final size in const [Size(1200, 700), Size(390, 700)]) {
    testWidgets('Service Person renders without overflow at $size', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = _FakeServicePersonApi();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ServicePersonWorkspace(
              caption: 'Service Person',
              role: ServicePersonRole.customer,
              api: api,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Somchai', skipOffstage: false), findsWidgets);
      expect(find.text('บทบาท', skipOffstage: false), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Service Person popup follows the narrow-screen contract', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ServicePersonWorkspace(
            caption: 'Service Person',
            role: ServicePersonRole.customer,
            api: _FakeServicePersonApi(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('\u0e40\u0e1e\u0e34\u0e48\u0e21'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('สร้างบุคคลใหม่'), findsNothing);
    expect(find.text('เลือกบุคคลเดิม'), findsNothing);
    expect(
      find.text(
        '\u0e1a\u0e17\u0e1a\u0e32\u0e17\u0e43\u0e19\u0e23\u0e30\u0e1a\u0e1a Service',
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Resident registration never offers an existing-person picker', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ServicePersonWorkspace(
            caption: 'Resident Registry',
            role: ServicePersonRole.resident,
            api: _FakeServicePersonApi(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('\u0e40\u0e1e\u0e34\u0e48\u0e21'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        '\u0e40\u0e25\u0e37\u0e2d\u0e01\u0e1a\u0e38\u0e04\u0e04\u0e25\u0e40\u0e14\u0e34\u0e21',
      ),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}

class _FakeServicePersonApi extends ServicePersonApi {
  @override
  Future<Map<String, bool>> actions() async => {
    'view': true,
    'create': true,
    'edit': true,
    'delete': false,
    'personEdit': true,
  };

  @override
  Future<Map<String, dynamic>> list({
    String search = '',
    bool? isActive,
    int page = 1,
    int pageSize = 20,
  }) async => {
    'items': [
      {
        'personID': 10,
        'fullName': 'Somchai',
        'nickName': 'Chai',
        'mobile': '0200000000',
        'email': 'chai@example.test',
        'isActive': true,
        'serviceRoles': ['SERVICE_CUSTOMER', 'RESIDENT'],
      },
    ],
    'total': 1,
  };

  @override
  Future<Map<String, dynamic>> lookup({int? personId, int? roomId}) async => {
    'businessTypeCode': 'DORMITORY',
    'persons': const [],
    'buildings': const [],
    'floors': const [],
    'rooms': const [
      {'id': 1, 'code': 'A101', 'name': 'Room 101'},
    ],
  };

  @override
  void dispose() {}
}
