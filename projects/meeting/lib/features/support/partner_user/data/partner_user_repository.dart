import '../../../../core/api/api_client.dart';

class PartnerUserRepository {
  PartnerUserRepository({ApiClient? api}) : _api = api ?? ApiClient();
  final ApiClient _api;

  Future<List<Map<String, dynamic>>> list(int partnerId) async {
    final result = await _api.get('/api/support/partner-users', query: {'partnerId': '$partnerId'});
    return (result as List).whereType<Map<String, dynamic>>().toList();
  }

  Future<void> create(int partnerId, Map<String, dynamic> body) => _api.post('/api/support/partner-users?partnerId=$partnerId', body: body);
  Future<void> update(int id, Map<String, dynamic> body) => _api.put('/api/support/partner-users/$id', body: body);
  Future<void> delete(int id) => _api.delete('/api/support/partner-users/$id');
}
