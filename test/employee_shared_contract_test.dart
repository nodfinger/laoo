import 'package:flutter_test/flutter_test.dart';
import 'package:laoo_shared_admin/laoo_shared_admin.dart';

void main() {
  test('employee contract maps all three data ownership scopes', () {
    expect(EmployeeScreenContracts.company.menuCode, '10001');
    expect(EmployeeScreenContracts.company.apiPath, '/api/company/employees');
    expect(EmployeeScreenContracts.partner.menuCode, '11001');
    expect(EmployeeScreenContracts.partner.apiPath, '/api/partner/employees');
    expect(EmployeeScreenContracts.partnerCustomer.menuCode, '12001');
    expect(
      EmployeeScreenContracts.partnerCustomer.routeName,
      'customerEmployees',
    );
    expect(
      EmployeeScreenContracts.partnerCustomer.apiPath,
      '/api/partner/customer-employees',
    );
  });

  test('employee repository uses fixed scope and typed list result', () async {
    final api = _FakeApi();
    final repository = EmployeeRepository(
      api,
      scope: EmployeeOwnerScope.partnerCustomer,
    );

    final result = await repository.list(companyId: 9, page: 2, pageSize: 10);

    expect(api.lastPath, '/api/partner/customer-employees');
    expect(api.lastQuery?['companyId'], '9');
    expect(result.totalCount, 1);
    expect(result.page, 2);
    expect(result.items.single.employeeId, 17);
    expect(result.items.single.employeeCode, 'E001');
    expect(result.items.single.departmentName, 'Service');
    expect(result.items.single.notifyByEmail, isTrue);
    expect(result.items.single.notifyInSystem, isFalse);
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
    return {
      'items': [
        {
          'employeeId': 17,
          'partnerId': 3,
          'companyId': 9,
          'employeeCode': 'E001',
          'fullName': 'Employee One',
          'departmentName': 'Service',
          'notifyByEmail': true,
          'notifyInSystem': false,
          'isActive': true,
        },
      ],
      'totalCount': 1,
      'page': 2,
      'pageSize': 10,
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
