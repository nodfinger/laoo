import 'package:flutter_test/flutter_test.dart';
import 'package:laoo_shared_admin/laoo_shared_admin.dart';

void main() {
  test('company user contract follows TDADMainMenu 07001', () {
    expect(CompanyUserScreenContracts.partner.menuCode, '07001');
    expect(CompanyUserScreenContracts.partner.routeName, 'partnerUsers');
    expect(
      CompanyUserScreenContracts.partner.apiPath,
      '/api/partner/company-users',
    );
    expect(CompanyUserScreenContracts.partner.screenType, 2);
  });

  test('company user repository returns owner-scoped typed records', () async {
    final api = _FakeApi();
    final repository = CompanyUserRepository(api);

    final users = await repository.list(
      search: 'customer',
      companyId: 12,
      isActive: true,
    );

    expect(api.lastPath, '/api/partner/company-users');
    expect(api.lastQuery, {
      'search': 'customer',
      'companyId': '12',
      'isActive': 'true',
    });
    expect(users.single.userId, 20);
    expect(users.single.companyId, 12);
    expect(users.single.companyName, 'ลูกค้าทดสอบ');
  });

  test('company user repository sends update-only request', () async {
    final api = _FakeApi();
    final repository = CompanyUserRepository(api);
    const request = CompanyUserUpdateRequest(
      username: 'customer.user',
      password: 'Password!',
      displayName: 'Customer User',
      isActive: true,
    );

    await repository.update(20, request);

    expect(api.lastPath, '/api/partner/company-users/20');
    expect(api.lastBody, request.toJson());
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
      return {'view': true, 'create': false, 'edit': true, 'delete': false};
    }
    return [
      {
        'userId': 20,
        'companyId': 12,
        'companyCode': 'C012',
        'companyName': 'ลูกค้าทดสอบ',
        'username': 'customer.user',
        'displayName': 'Customer User',
        'email': null,
        'mobile': null,
        'isCompanyAdmin': false,
        'isActive': true,
      },
    ];
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
  }) async {
    lastPath = path;
    lastBody = body;
  }

  @override
  Future<dynamic> delete(
    String path, {
    Object? body,
    Map<String, String>? query,
    bool authenticated = true,
  }) async {}
}
