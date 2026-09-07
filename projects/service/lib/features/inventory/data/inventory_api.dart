import '../../../core/api/api_client.dart';

class InventoryApi {
  InventoryApi({ApiClient? client}) : _client = client ?? ApiClient();
  final ApiClient _client;

  Future<Map<String, bool>> actions(String resource) async =>
      Map<String, bool>.from(
        await _client.get('/api/company/$resource/actions') as Map,
      );

  Future<List<Map<String, dynamic>>> warehouses({String? search}) async =>
      List<Map<String, dynamic>>.from(
        await _client.get(
              '/api/company/warehouses',
              query: {
                if (search?.trim().isNotEmpty == true) 'search': search!.trim(),
              },
            )
            as List,
      );

  Future<void> saveWarehouse(Map<String, dynamic> body, {int? id}) async =>
      id == null
      ? _client.post('/api/company/warehouses', body: body)
      : _client.put('/api/company/warehouses/$id', body: body);
  Future<void> deleteWarehouse(int id) =>
      _client.delete('/api/company/warehouses/$id');
  Future<List<Map<String, dynamic>>> branches() async =>
      List<Map<String, dynamic>>.from(
        await _client.get('/api/company/warehouses/lookup') as List,
      );

  Future<Map<String, dynamic>> receiptLookup() async =>
      Map<String, dynamic>.from(
        await _client.get('/api/company/stock-receipts/lookup') as Map,
      );
  Future<List<Map<String, dynamic>>> receipts({String? search}) async =>
      List<Map<String, dynamic>>.from(
        await _client.get(
              '/api/company/stock-receipts',
              query: {
                if (search?.trim().isNotEmpty == true) 'search': search!.trim(),
              },
            )
            as List,
      );
  Future<Map<String, dynamic>> receipt(int id) async =>
      Map<String, dynamic>.from(
        await _client.get('/api/company/stock-receipts/$id') as Map,
      );
  Future<void> saveReceipt(Map<String, dynamic> body, {int? id}) async =>
      id == null
      ? _client.post('/api/company/stock-receipts', body: body)
      : _client.put('/api/company/stock-receipts/$id', body: body);
  Future<void> confirmReceipt(int id) =>
      _client.post('/api/company/stock-receipts/$id/confirm');
  Future<void> voidReceipt(int id) =>
      _client.post('/api/company/stock-receipts/$id/void');

  Future<List<Map<String, dynamic>>> instances({String? search}) async =>
      List<Map<String, dynamic>>.from(
        await _client.get(
              '/api/company/item-instances',
              query: {
                if (search?.trim().isNotEmpty == true) 'search': search!.trim(),
              },
            )
            as List,
      );
  Future<List<Map<String, dynamic>>> instanceHistory(int id) async =>
      List<Map<String, dynamic>>.from(
        await _client.get('/api/company/item-instances/$id/history') as List,
      );
  Future<void> updateInstanceLocation(int id, Map<String, dynamic> body) =>
      _client.put('/api/company/item-instances/$id/location', body: body);

  Future<Map<String, dynamic>> issueLookup() async => Map<String, dynamic>.from(
    await _client.get('/api/company/inventory-issues/lookup') as Map,
  );
  Future<List<Map<String, dynamic>>> issues() async =>
      List<Map<String, dynamic>>.from(
        await _client.get('/api/company/inventory-issues') as List,
      );
  Future<void> createIssue(Map<String, dynamic> body) =>
      _client.post('/api/company/inventory-issues', body: body);
  Future<void> confirmIssue(int id) =>
      _client.post('/api/company/inventory-issues/$id/confirm');
  Future<void> voidIssue(int id) =>
      _client.post('/api/company/inventory-issues/$id/void');

  void dispose() => _client.dispose();
}
