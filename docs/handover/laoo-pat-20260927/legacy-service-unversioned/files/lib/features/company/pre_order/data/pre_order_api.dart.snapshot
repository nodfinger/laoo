import '../../../../core/api/api_client.dart';

class PreOrderApi {
  PreOrderApi({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<List<Map<String, dynamic>>> list({
    String? search,
    String? status,
  }) async {
    final query = <String, String>{};
    if (search != null && search.trim().isNotEmpty) {
      query['search'] = search.trim();
    }
    if (status != null && status.trim().isNotEmpty && status != 'ALL') {
      query['status'] = status.trim();
    }
    return List<Map<String, dynamic>>.from(
      await _client.get('/api/company/pre-orders', query: query) as List,
    );
  }

  Future<Map<String, bool>> actions() async {
    final raw = Map<String, dynamic>.from(
      await _client.get('/api/company/pre-orders/actions') as Map,
    );
    return raw.map((key, value) => MapEntry(key, value == true));
  }

  Future<Map<String, dynamic>> lookup() async => Map<String, dynamic>.from(
    await _client.get('/api/company/pre-orders/lookup') as Map,
  );

  Future<Map<String, dynamic>> quotation(int quotationId) async =>
      Map<String, dynamic>.from(
        await _client.get('/api/company/pre-orders/quotation/$quotationId')
            as Map,
      );

  Future<Map<String, dynamic>> get(int preOrderId) async =>
      Map<String, dynamic>.from(
        await _client.get('/api/company/pre-orders/$preOrderId') as Map,
      );

  Future<Map<String, dynamic>> create(Map<String, dynamic> body) async =>
      Map<String, dynamic>.from(
        await _client.post('/api/company/pre-orders', body: body) as Map,
      );

  Future<Map<String, dynamic>> update(
    int preOrderId,
    Map<String, dynamic> body,
  ) async => Map<String, dynamic>.from(
    await _client.put('/api/company/pre-orders/$preOrderId', body: body) as Map,
  );

  Future<void> delete(int preOrderId) async {
    await _client.delete('/api/company/pre-orders/$preOrderId');
  }

  void dispose() => _client.dispose();
}
