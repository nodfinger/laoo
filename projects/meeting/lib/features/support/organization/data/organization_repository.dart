import '../../../../core/api/api_client.dart';

class OrganizationRepository {
  OrganizationRepository({ApiClient? api, bool company = false})
    : _api = api ?? ApiClient(),
      _path = company
          ? '/api/company/organization-structure'
          : '/api/support/organization-structure';

  final ApiClient _api;
  final String _path;

  Future<Map<String, bool>> actions() async {
    final data = await _api.get('$_path/actions');
    if (data is! Map) return const {};
    return Map<String, bool>.fromEntries(
      data.entries.map((e) => MapEntry('${e.key}', e.value == true)),
    );
  }

  Future<Map<String, dynamic>> load() async =>
      Map<String, dynamic>.from(await _api.get(_path) as Map);

  Future<void> create(Map<String, dynamic> body) async =>
      _api.post(_path, body: body);

  Future<void> updateMode(int mode) async =>
      _api.put('$_path/mode', body: {'orgStructureType': mode});

  Future<void> update(int id, Map<String, dynamic> body) async =>
      _api.put('$_path/$id', body: body);

  Future<void> delete(int id) async => _api.delete('$_path/$id');
}
