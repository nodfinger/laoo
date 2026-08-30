import '../../../../core/api/api_client.dart';

class TemporaryReceiptApi {
  TemporaryReceiptApi({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<List<Map<String, dynamic>>> list({
    String? search,
    String? status,
    String? referenceType,
  }) async {
    final query = <String, String>{};
    if (search?.trim().isNotEmpty == true) query['search'] = search!.trim();
    if (status != null && status != 'ALL') query['status'] = status;
    if (referenceType != null && referenceType != 'ALL') {
      query['referenceType'] = referenceType;
    }
    return List<Map<String, dynamic>>.from(
      await _client.get('/api/company/temporary-receipts', query: query)
          as List,
    );
  }

  Future<Map<String, bool>> actions() async {
    final raw = Map<String, dynamic>.from(
      await _client.get('/api/company/temporary-receipts/actions') as Map,
    );
    return raw.map((key, value) => MapEntry(key, value == true));
  }

  Future<Map<String, dynamic>> lookup() async => Map<String, dynamic>.from(
    await _client.get('/api/company/temporary-receipts/lookup') as Map,
  );

  Future<Map<String, dynamic>> get(int id) async => Map<String, dynamic>.from(
    await _client.get('/api/company/temporary-receipts/$id') as Map,
  );

  Future<Map<String, dynamic>> create(Map<String, dynamic> body) async =>
      Map<String, dynamic>.from(
        await _client.post('/api/company/temporary-receipts', body: body)
            as Map,
      );

  Future<Map<String, dynamic>> update(
    int id,
    Map<String, dynamic> body,
  ) async => Map<String, dynamic>.from(
    await _client.put('/api/company/temporary-receipts/$id', body: body) as Map,
  );

  Future<void> delete(int id) async {
    await _client.delete('/api/company/temporary-receipts/$id');
  }

  void dispose() => _client.dispose();
}
