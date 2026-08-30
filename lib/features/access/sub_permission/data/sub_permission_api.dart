import '../../../../core/api/api_client.dart';

class SubPermissionApi {
  SubPermissionApi({ApiClient? client}) : _client = client ?? ApiClient();
  final ApiClient _client;

  Future<Map<String, dynamic>> list() async => Map<String, dynamic>.from(
    await _client.get('/api/company/sub-permissions') as Map,
  );

  Future<List<Map<String, dynamic>>> employees(
    String menuCode,
    String permissionPointCode,
  ) async => List<Map<String, dynamic>>.from(
    await _client.get(
          '/api/company/sub-permissions/employees',
          query: {
            'menuCode': menuCode,
            'permissionPointCode': permissionPointCode,
          },
        )
        as List,
  );

  Future<Set<String>> currentCodes(String menuCode) async =>
      Set<String>.from(
        (await _client.get(
                  '/api/company/sub-permissions/current',
                  query: {'menuCode': menuCode},
                )
                as List)
            .map((value) => value.toString().trim()),
      );

  Future<void> saveEmployees(
    String menuCode,
    String permissionPointCode,
    List<int> employeeIds,
  ) async => _client.put(
    '/api/company/sub-permissions/employees',
    body: {
      'menuCode': menuCode,
      'permissionPointCode': permissionPointCode,
      'employeeIds': employeeIds,
    },
  );

  void dispose() => _client.dispose();
}
