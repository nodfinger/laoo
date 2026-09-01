import 'package:flutter_test/flutter_test.dart';
import 'package:laoo_shared_admin/laoo_shared_admin.dart';

void main() {
  test('organization contract maps every owner scope to its menu and API', () {
    expect(OrganizationScreenContracts.support.menuCode, '12005');
    expect(
      OrganizationScreenContracts.support.apiPath,
      '/api/support/organization-structure',
    );
    expect(OrganizationScreenContracts.partner.menuCode, '11005');
    expect(
      OrganizationScreenContracts.partner.apiPath,
      '/api/partner/organization-structure',
    );
    expect(OrganizationScreenContracts.company.menuCode, '10005');
    expect(
      OrganizationScreenContracts.company.apiPath,
      '/api/company/organization-structure',
    );
  });

  test('organization repository uses scope and returns typed units', () async {
    final api = _FakeApi();
    final repository = OrganizationRepository(
      api,
      scope: LaooOwnerScope.company,
    );

    final snapshot = await repository.load();

    expect(api.lastPath, '/api/company/organization-structure');
    expect(snapshot.orgStructureType, 2);
    expect(snapshot.units, hasLength(1));
    expect(snapshot.units.single.orgUnitId, 17);
    expect(snapshot.units.single.unitType, OrganizationUnitTypes.division);
    expect(snapshot.units.single.unitCode, 'SALE');
  });

  test(
    'organization repository sends typed update to scoped endpoint',
    () async {
      final api = _FakeApi();
      final repository = OrganizationRepository(
        api,
        scope: LaooOwnerScope.partner,
      );
      const request = OrganizationUnitUpsertRequest(
        unitType: OrganizationUnitTypes.department,
        parentOrgUnitId: 17,
        unitCode: 'DOMESTIC',
        nameTh: 'Domestic Sales',
      );

      await repository.update(29, request);

      expect(api.lastPath, '/api/partner/organization-structure/29');
      expect(api.lastBody, request.toJson());
    },
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
    return {
      'orgStructureType': 2,
      'units': [
        {
          'orgUnitId': 17,
          'companyId': 9,
          'unitType': 'DIV',
          'parentOrgUnitId': null,
          'unitCode': 'SALE',
          'nameTh': 'Sales',
          'nameEn': 'Sales',
          'isActive': true,
          'companyName': 'LAOO',
        },
      ],
    };
  }

  @override
  Future<dynamic> post(
    String path, {
    Object? body,
    bool authenticated = true,
  }) async {
    lastPath = path;
    lastBody = body;
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
  Future<dynamic> delete(
    String path, {
    Object? body,
    Map<String, String>? query,
    bool authenticated = true,
  }) async {
    lastPath = path;
    lastBody = body;
  }
}
