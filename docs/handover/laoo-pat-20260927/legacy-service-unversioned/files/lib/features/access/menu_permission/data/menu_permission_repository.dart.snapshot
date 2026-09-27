import '../../../../core/api/api_client.dart';
import '../models/menu_permission_row.dart';

class MenuPermissionRepository {
  MenuPermissionRepository({ApiClient? client})
    : _client = client ?? ApiClient();
  final ApiClient _client;
  Future<Map<String, bool>> actions(String scope) async {
    final data = await _client.get(
      '/api/menu-permissions/actions',
      query: {'scope': scope},
    );
    if (data is! Map) return const {};
    return Map<String, bool>.fromEntries(
      data.entries.map((e) => MapEntry('${e.key}', e.value == true)),
    );
  }

  Future<List<MenuPermissionRow>> list(String scope, int groupId) async {
    final data =
        await _client.get(
              '/api/menu-permissions',
              query: {'scope': scope, 'roleGroupId': '$groupId'},
            )
            as List<dynamic>;
    return data
        .map((e) => MenuPermissionRow.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> save(
    String scope,
    int groupId,
    List<MenuPermissionRow> rows,
  ) async => _client.put(
    '/api/menu-permissions?scope=$scope&roleGroupId=$groupId',
    body: rows.map((e) => e.toJson()).toList(),
  );
  Future<void> clear(String scope, int groupId) async => _client.delete(
    '/api/menu-permissions',
    query: {'scope': scope, 'roleGroupId': '$groupId'},
  );
}
