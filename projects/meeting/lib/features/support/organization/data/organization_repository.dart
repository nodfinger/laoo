import '../../../../core/api/api_client.dart';

class OrganizationRepository {
  OrganizationRepository({ApiClient? api}) : _api = api ?? ApiClient();
  final ApiClient _api;
  Future<Map<String, bool>> actions() async { final data = await _api.get('/api/support/organization-structure/actions'); if (data is! Map) return const {}; return Map<String, bool>.fromEntries(data.entries.map((e) => MapEntry('${e.key}', e.value == true))); }

  Future<Map<String, dynamic>> load() async => Map<String, dynamic>.from(
        await _api.get(
          '/api/support/organization-structure',
        ) as Map,
      );

  Future<void> create(Map<String, dynamic> body) async =>
      _api.post(
        '/api/support/organization-structure',
        body: body,
      );

  Future<void> updateMode(int mode) async => _api.put(
        '/api/support/organization-structure/mode',
        body: {'orgStructureType': mode},
      );

  Future<void> update(int id, Map<String, dynamic> body) async =>
      _api.put(
        '/api/support/organization-structure/$id',
        body: body,
      );

  Future<void> delete(int id) async => _api.delete(
        '/api/support/organization-structure/$id',
      );
}
