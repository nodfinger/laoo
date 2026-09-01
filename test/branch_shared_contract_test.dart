import 'package:flutter_test/flutter_test.dart';
import 'package:laoo_shared_admin/laoo_shared_admin.dart';

void main() {
  test('branch contract maps every owner scope to its own menu and API', () {
    expect(BranchScreenContracts.support.menuCode, '01003');
    expect(BranchScreenContracts.support.apiPath, '/api/support/branches');
    expect(BranchScreenContracts.partner.menuCode, '06002');
    expect(BranchScreenContracts.partner.apiPath, '/api/partner/branches');
    expect(BranchScreenContracts.company.menuCode, '09002');
    expect(BranchScreenContracts.company.apiPath, '/api/company/branches');
  });

  test('branch repository uses the scoped endpoint and typed model', () async {
    final api = _FakeApi();
    final repository = BranchRepository(api, scope: LaooOwnerScope.partner);

    final records = await repository.get(search: 'BKK', companyId: 9);

    expect(api.lastPath, '/api/partner/branches');
    expect(api.lastQuery, {'search': 'BKK', 'companyId': '9'});
    expect(records, hasLength(1));
    expect(records.single.branchId, 12);
    expect(records.single.branchNameTh, 'Bangkok');
    expect(records.single.isActive, isTrue);
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
    return [
      {
        'branchId': 12,
        'companyId': 9,
        'companyName': 'LAOO',
        'branchCode': 'BKK',
        'branchNameTh': 'Bangkok',
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
  }) async {}

  @override
  Future<dynamic> delete(
    String path, {
    Object? body,
    Map<String, String>? query,
    bool authenticated = true,
  }) async {}
}
