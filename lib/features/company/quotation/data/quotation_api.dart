import '../../../../core/api/api_client.dart';

class QuotationApi {
  QuotationApi({ApiClient? client}) : _client = client ?? ApiClient();
  final ApiClient _client;
  Future<List<Map<String, dynamic>>> list() async =>
      List<Map<String, dynamic>>.from(
        await _client.get('/api/company/quotations') as List,
      );
  Future<Map<String, bool>> actions() async {
    final raw = Map<String, dynamic>.from(
      await _client.get('/api/company/quotations/actions') as Map,
    );
    return raw.map((key, value) => MapEntry(key, value == true));
  }

  Future<Map<String, dynamic>> lookup() async => Map<String, dynamic>.from(
    await _client.get('/api/company/quotations/lookup') as Map,
  );
  Future<Map<String, dynamic>> get(int quotationId) async =>
      Map<String, dynamic>.from(
        await _client.get('/api/company/quotations/$quotationId') as Map,
      );
  Future<Map<String, dynamic>> create(Map<String, dynamic> body) async =>
      Map<String, dynamic>.from(
        await _client.post('/api/company/quotations', body: body) as Map,
      );
  Future<Map<String, dynamic>> update(
    int quotationId,
    Map<String, dynamic> body,
  ) async => Map<String, dynamic>.from(
    await _client.put('/api/company/quotations/$quotationId', body: body)
        as Map,
  );
  Future<void> delete(int quotationId) async {
    await _client.delete('/api/company/quotations/$quotationId');
  }

  void dispose() => _client.dispose();
}
