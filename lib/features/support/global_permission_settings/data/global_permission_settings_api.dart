import '../../../../core/api/api_client.dart';

class GlobalPermissionSettingsApi {
  GlobalPermissionSettingsApi({ApiClient? client})
    : _client = client ?? ApiClient();
  final ApiClient _client;
  Future<String> caption() async {
    final data = Map<String, dynamic>.from(
      await _client.get('/api/global-permission-settings/caption') as Map,
    );
    return '${data['menuName'] ?? ''}'.trim();
  }

  Future<List<Map<String, dynamic>>> menus() async =>
      (await _client.get('/api/global-permission-settings/menus') as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
  Future<void> addPoint({
    required String menuCode,
    required String code,
    required String name,
    String? description,
  }) async => _client.post(
    '/api/global-permission-settings/points',
    body: {
      'menuCode': menuCode,
      'permissionPointCode': code,
      'permissionPointName': name,
      'permissionPointDescription': description ?? '',
    },
  );
  Future<void> updatePoint({
    required String menuCode,
    required String code,
    required String name,
    String? description,
  }) async => _client.put(
    '/api/global-permission-settings/points/${Uri.encodeComponent(menuCode)}/${Uri.encodeComponent(code)}',
    body: {
      'menuCode': menuCode,
      'permissionPointCode': code,
      'permissionPointName': name,
      'permissionPointDescription': description ?? '',
    },
  );
  Future<void> deletePoint({
    required String menuCode,
    required String code,
  }) async => _client.delete(
    '/api/global-permission-settings/points/${Uri.encodeComponent(menuCode)}/${Uri.encodeComponent(code)}',
  );
  void dispose() => _client.dispose();
}
