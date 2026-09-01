import 'package:flutter_test/flutter_test.dart';
import 'package:laoo_shared_admin/laoo_shared_admin.dart';
import 'package:laoo_shared_admin_ui/laoo_shared_admin_ui.dart';

void main() {
  test('loads permission and paged employee records', () async {
    final api = _FakeApi();
    final controller = EmployeeListController(
      repository: EmployeeRepository(
        api,
        scope: EmployeeOwnerScope.partnerCustomer,
      ),
      pageSize: 20,
      screenType: 1,
    );
    addTearDown(controller.dispose);

    await controller.initialize();

    expect(controller.canCreate, isTrue);
    expect(controller.canEdit, isTrue);
    expect(controller.canDelete, isTrue);
    expect(controller.items.single.employeeCode, 'E001');
    expect(controller.totalCount, 25);
    expect(controller.firstRow, 1);
    expect(controller.lastRow, 20);

    await controller.nextPage();
    expect(controller.page, 2);
    expect(controller.firstRow, 21);
    expect(controller.lastRow, 25);
    expect(api.lastQuery?['page'], '2');
  });

  test('applies and clears every server filter', () async {
    final api = _FakeApi();
    final controller = EmployeeListController(
      repository: EmployeeRepository(api, scope: EmployeeOwnerScope.company),
      pageSize: 10,
      screenType: 3,
    );
    addTearDown(controller.dispose);

    await controller.initialize();
    await controller.applyFilters(
      searchText: '  Somchai ',
      division: 1,
      department: 2,
      company: 9,
      active: true,
    );

    expect(api.lastQuery?['search'], 'Somchai');
    expect(api.lastQuery?['divisionId'], '1');
    expect(api.lastQuery?['departmentId'], '2');
    expect(api.lastQuery?['companyId'], '9');
    expect(api.lastQuery?['isActive'], 'true');
    expect(controller.canCreate, isFalse);
    expect(controller.canEdit, isFalse);
    expect(controller.canDelete, isFalse);

    await controller.clearFilters();
    expect(controller.search, isEmpty);
    expect(controller.divisionId, isNull);
    expect(controller.departmentId, isNull);
    expect(controller.companyId, isNull);
    expect(controller.isActive, isNull);
  });
}

class _FakeApi implements JsonApiClient {
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
      return {'view': true, 'create': true, 'edit': true, 'delete': true};
    }
    final requestedPage = int.tryParse(query?['page'] ?? '') ?? 1;
    return {
      'items': [
        {
          'employeeId': requestedPage,
          'partnerId': 3,
          'companyId': 9,
          'employeeCode': 'E001',
          'fullName': 'Employee One',
          'isActive': true,
        },
      ],
      'totalCount': 25,
      'page': requestedPage,
      'pageSize': int.tryParse(query?['pageSize'] ?? '') ?? 20,
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
