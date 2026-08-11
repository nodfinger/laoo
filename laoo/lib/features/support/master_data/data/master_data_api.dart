import '../../../../core/api/api_client.dart';

class MasterDataApi {
  MasterDataApi({ApiClient? apiClient}) : _api = apiClient ?? ApiClient();
  final ApiClient _api;

  Future<List<Map<String, dynamic>>> groups() async => List<Map<String, dynamic>>.from(await _api.get('/api/support/master-data/groups') as List);
  Future<List<Map<String, dynamic>>> list(String groupCode, {String? search}) async => List<Map<String, dynamic>>.from(await _api.get('/api/support/master-data', query: {'groupCode': groupCode, if (search != null && search.isNotEmpty) 'search': search}) as List);
  Future<void> create(String groupCode, Map<String, dynamic> body) async { await _api.post('/api/support/master-data/$groupCode', body: body); }
  Future<void> update(String groupCode, String code, Map<String, dynamic> body) async { await _api.put('/api/support/master-data/$groupCode/$code', body: body); }
  Future<void> delete(String groupCode, String code) async { await _api.delete('/api/support/master-data/$groupCode/$code'); }
  void dispose() => _api.dispose();
}
