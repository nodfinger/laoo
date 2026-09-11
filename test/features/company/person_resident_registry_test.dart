import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laoo/app/router/app_menu_route_registry.dart';
import 'package:laoo/features/company/person/data/person_registry_api.dart';
import 'package:laoo/features/company/person/pages/person_registry_page.dart';
import 'package:laoo/features/company/resident/data/resident_registry_api.dart';
import 'package:laoo/features/company/resident/pages/resident_registry_page.dart';

void main() {
  test('Person and Resident menus are registered as Core CRUD routes', () {
    final person = AppMenuRouteRegistry.byMenuCode('13002');
    final resident = AppMenuRouteRegistry.byMenuCode('14004');

    expect(person, isNotNull);
    expect(person!.path, '/company/persons');
    expect(person.scope, AppMenuScope.company);
    expect(resident, isNotNull);
    expect(resident!.path, '/asset/residents');
    expect(resident.scope, AppMenuScope.company);
  });

  testWidgets('Person add form remains usable on a narrow screen', (
    tester,
  ) async {
    final api = PersonRegistryApi();
    addTearDown(api.dispose);
    await tester.binding.setSurfaceSize(const Size(390, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PersonRegistryForm(
            api: api,
            caption: 'ทะเบียนบุคคล',
            onSaved: () {},
          ),
        ),
      ),
    );

    expect(find.text('ทะเบียนบุคคล > เพิ่ม'), findsOneWidget);
    expect(find.text('สถานะ'), findsOneWidget);
    expect(find.text('บันทึก'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Resident form adapts fields to a narrow screen', (tester) async {
    final api = ResidentRegistryApi();
    addTearDown(api.dispose);
    await tester.binding.setSurfaceSize(const Size(390, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final lookup = <String, dynamic>{
      'persons': [
        {'id': 1, 'name': 'มนต์'},
      ],
      'buildings': [
        {'id': 10, 'code': 'B1', 'name': 'อาคาร 1'},
      ],
      'floors': [
        {'id': 20, 'parentId': 10, 'code': 'F1', 'name': 'ชั้น 1'},
      ],
      'rooms': [
        {
          'id': 30,
          'buildingId': 10,
          'parentId': 20,
          'code': 'R101',
          'name': 'ห้อง 101',
        },
      ],
    };

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ResidentRegistryForm(
            api: api,
            caption: 'ทะเบียนผู้พักอาศัย',
            lookup: lookup,
            onSaved: () {},
          ),
        ),
      ),
    );

    expect(find.text('ทะเบียนผู้พักอาศัย > เพิ่ม'), findsOneWidget);
    expect(find.text('บุคคล *'), findsOneWidget);
    expect(find.text('วันที่เข้า *'), findsOneWidget);
    expect(find.text('วันที่ออก'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
