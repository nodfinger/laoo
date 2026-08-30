import '../../../../core/api/api_client.dart';

class CustomerApi {
  CustomerApi({ApiClient? client}) : _client = client ?? ApiClient();
  final ApiClient _client;
  Future<List<Map<String, dynamic>>> list({
    String? search,
    String? groupCode,
    String? businessTypeCode,
  }) async => List<Map<String, dynamic>>.from(
    await _client.get(
          '/api/company/customers',
          query: {
            if (search?.isNotEmpty == true) 'search': search!,
            if (groupCode?.isNotEmpty == true) 'groupCode': groupCode!,
            if (businessTypeCode?.isNotEmpty == true)
              'businessTypeCode': businessTypeCode!,
          },
        )
        as List,
  );
  Future<Map<String, dynamic>> get(int id) async => Map<String, dynamic>.from(
    await _client.get('/api/company/customers/$id') as Map,
  );
  Future<Map<String, dynamic>> salesLookups() async =>
      Map<String, dynamic>.from(
        await _client.get('/api/company/customers/sales-lookups') as Map,
      );
  Future<Map<String, bool>> actions() async => Map<String, bool>.fromEntries(
    (await _client.get('/api/company/customers/actions') as Map).entries.map(
      (e) => MapEntry('${e.key}', e.value == true),
    ),
  );
  Future<void> create(Map<String, dynamic> body) async =>
      _client.post('/api/company/customers', body: body);
  Future<void> update(int id, Map<String, dynamic> body) async =>
      _client.put('/api/company/customers/$id', body: body);
  Future<void> delete(int id) async =>
      _client.delete('/api/company/customers/$id');
  void dispose() => _client.dispose();
}
