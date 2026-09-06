import '../../../../core/api/api_client.dart';

class TaxInvoiceApi {
  TaxInvoiceApi({ApiClient? client}) : _client = client ?? ApiClient();
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
      await _client.get('/api/company/tax-invoices', query: query) as List,
    );
  }

  Future<Map<String, bool>> actions() async => Map<String, dynamic>.from(
    await _client.get('/api/company/tax-invoices/actions') as Map,
  ).map((key, value) => MapEntry(key, value == true));

  Future<Map<String, dynamic>> lookup() async => Map<String, dynamic>.from(
    await _client.get('/api/company/tax-invoices/lookup') as Map,
  );

  Future<Map<String, dynamic>> source(String type, int id) async =>
      Map<String, dynamic>.from(
        await _client.get('/api/company/tax-invoices/source/$type/$id') as Map,
      );

  Future<Map<String, dynamic>> get(int id) async => Map<String, dynamic>.from(
    await _client.get('/api/company/tax-invoices/$id') as Map,
  );

  Future<Map<String, dynamic>> create(Map<String, dynamic> body) async =>
      Map<String, dynamic>.from(
        await _client.post('/api/company/tax-invoices', body: body) as Map,
      );

  Future<Map<String, dynamic>> update(
    int id,
    Map<String, dynamic> body,
  ) async => Map<String, dynamic>.from(
    await _client.put('/api/company/tax-invoices/$id', body: body) as Map,
  );

  Future<void> delete(int id) =>
      _client.delete('/api/company/tax-invoices/$id');

  Future<Map<String, dynamic>> issue(int id) async => Map<String, dynamic>.from(
    await _client.post('/api/company/tax-invoices/$id/issue') as Map,
  );

  Future<Map<String, dynamic>> voidDocument(int id) async =>
      Map<String, dynamic>.from(
        await _client.post('/api/company/tax-invoices/$id/void') as Map,
      );

  void dispose() => _client.dispose();
}
