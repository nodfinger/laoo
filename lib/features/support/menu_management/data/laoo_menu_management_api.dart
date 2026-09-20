import '../../../../core/api/api_client.dart';

class LaooMenuManagementApi {
  LaooMenuManagementApi({ApiClient? client}) : _client = client ?? ApiClient();
  final ApiClient _client;
  void dispose() => _client.dispose();
  Future<String> caption() async {
    final json = Map<String, dynamic>.from(
      await _client.get('/api/laoo-menu-management/caption') as Map,
    );
    return '${json['caption'] ?? ''}';
  }

  Future<Map<String, dynamic>> load({
    String? projectCode,
  }) async => Map<String, dynamic>.from(
    await _client.get(
          '/api/laoo-menu-management${projectCode == null ? '' : '?projectCode=$projectCode'}',
        )
        as Map,
  );
  Future<void> save({
    required List<Map<String, dynamic>> groups,
    required List<Map<String, dynamic>> menus,
  }) => _client.put(
    '/api/laoo-menu-management',
    body: {'groups': groups, 'menus': menus},
  );
}
