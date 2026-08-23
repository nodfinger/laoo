import '../../../../core/api/api_client.dart';

class ItemApi {
  ItemApi({ApiClient? client}) : _client = client ?? ApiClient();
  final ApiClient _client;

  Future<Map<String, bool>> actions() async => Map<String, bool>.fromEntries(
    (await _client.get('/api/company/items/actions') as Map).entries.map(
      (e) => MapEntry('${e.key}', e.value == true),
    ),
  );

  Future<List<Map<String, dynamic>>> list({
    String? groupCode,
    String? typeCode,
    String? search,
  }) async => List<Map<String, dynamic>>.from(
    await _client.get(
          '/api/company/items',
          query: {
            if (groupCode?.isNotEmpty == true) 'groupCode': groupCode!,
            if (typeCode?.isNotEmpty == true) 'typeCode': typeCode!,
            if (search?.trim().isNotEmpty == true) 'search': search!.trim(),
          },
        )
        as List,
  );
  Future<Map<String, dynamic>> get(int id) async => Map<String, dynamic>.from(
    await _client.get('/api/company/items/$id') as Map,
  );
  Future<void> create(Map<String, dynamic> body) async =>
      _client.post('/api/company/items', body: body);
  Future<void> update(int id, Map<String, dynamic> body) async =>
      _client.put('/api/company/items/$id', body: body);
  Future<void> updateVisibility(
    int id, {
    required bool isActive,
    required bool showShop,
  }) async => _client.patch(
    '/api/company/items/$id/visibility',
    body: {'isActive': isActive, 'showShop': showShop},
  );
  Future<void> delete(int id) async => _client.delete('/api/company/items/$id');
  Future<List<Map<String, dynamic>>> getPackUnits(int id) async =>
      List<Map<String, dynamic>>.from(
        await _client.get('/api/company/items/$id/pack-units') as List,
      );
  Future<List<Map<String, dynamic>>> savePackUnits(
    int id,
    List<Map<String, dynamic>> items,
  ) async => List<Map<String, dynamic>>.from(
    await _client.put(
          '/api/company/items/$id/pack-units',
          body: {'items': items},
        )
        as List,
  );
  Future<void> deletePackUnit(int itemId, int packUnitId) async =>
      _client.delete('/api/company/items/$itemId/pack-units/$packUnitId');
  void dispose() => _client.dispose();
}
