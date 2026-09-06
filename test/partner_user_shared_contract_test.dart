import 'package:flutter_test/flutter_test.dart';
import 'package:laoo_shared_admin/laoo_shared_admin.dart';

void main() {
  test('partner user contract uses TDADMainMenu identity', () {
    expect(PartnerUserScreenContracts.support.menuCode, '02002');
    expect(PartnerUserScreenContracts.support.routeName, 'partnerUser');
    expect(
      PartnerUserScreenContracts.support.apiPath,
      '/api/support/partner-users',
    );
    expect(PartnerUserScreenContracts.support.screenType, 1);
    expect(PartnerUserScreenContracts.support.legacyPermissionCodes, [
      'PARTNER',
    ]);
  });

  test('partner user repository returns typed records', () async {
    final api = _FakeApi();
    final repository = PartnerUserRepository(api);

    final users = await repository.list(7);

    expect(api.lastPath, '/api/support/partner-users');
    expect(api.lastQuery, {'partnerId': '7'});
    expect(users.single.partnerUserId, 12);
    expect(users.single.partnerId, 7);
    expect(users.single.isPartnerAdmin, isTrue);
  });

  test('partner user repository sends typed create request', () async {
    final api = _FakeApi();
    final repository = PartnerUserRepository(api);
    const request = PartnerUserUpsertRequest(
      username: 'partner.user',
      password: 'Password!',
      displayName: 'Partner User',
      isPartnerAdmin: false,
    );

    await repository.create(7, request);

    expect(api.lastPath, '/api/support/partner-users?partnerId=7');
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
    return [
      {
        'partnerUserId': 12,
        'partnerId': 7,
        'username': 'partner.user',
        'displayName': 'Partner User',
        'email': null,
        'mobileNumber': null,
        'isPartnerAdmin': true,
        'isActive': true,
      },
    ];
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
  }
}
