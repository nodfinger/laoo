import '../models/partner.dart';
import 'partner_api_client.dart';
import 'partner_repository.dart';

class ApiPartnerRepository implements PartnerRepository {
  ApiPartnerRepository(this._apiClient);

  final PartnerApiClient _apiClient;

  @override
  Future<List<Partner>> getPartners({String? search, bool? isActive}) async {
    final result = await _apiClient.get(
      '/api/support/partners',
      query: {
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        if (isActive != null) 'isActive': isActive.toString(),
      },
    );

    final data = result as List<dynamic>;

    return data
        .map((item) => Partner.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<Partner> getPartner(int partnerId) async {
    final result = await _apiClient.get('/api/support/partners/$partnerId');

    return Partner.fromJson(result as Map<String, dynamic>);
  }

  @override
  Future<Partner> createPartner(PartnerUpsertInput input) async {
    final result = await _apiClient.post(
      '/api/support/partners',
      body: input.toJson(),
    );

    return Partner.fromJson(result as Map<String, dynamic>);
  }

  @override
  Future<void> updatePartner(int partnerId, PartnerUpsertInput input) async {
    await _apiClient.put(
      '/api/support/partners/$partnerId',
      body: input.toJson(),
    );
  }

  @override
  Future<void> changeStatus(int partnerId, bool isActive) async {
    await _apiClient.put(
      '/api/support/partners/$partnerId/status',
      body: {'isActive': isActive},
    );
  }
  @override
  Future<void> deletePartner(int partnerId) async {
    await _apiClient.delete('/api/support/partners/$partnerId');
  }

  Future<void> createPartnerAdmin(int partnerId, {
    required String username,
    required String password,
  }) async {
    await _apiClient.post(
      '/api/support/partner-users?partnerId=$partnerId',
      body: {
        'username': username,
        'password': password,
        'displayName': '$username Admin',
        'isPartnerAdmin': true,
        'isActive': true,
      },
    );
  }

  Future<void> updatePartnerAdmin(int userId, {
    required String username,
    required String password,
  }) async {
    await _apiClient.put('/api/support/partner-users/$userId', body: {
      'username': username,
      if (password.isNotEmpty) 'password': password,
      'displayName': '$username Admin',
      'isPartnerAdmin': true,
      'isActive': true,
    });
  }

}
