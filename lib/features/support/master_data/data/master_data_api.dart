import '../../../../core/api/api_client.dart';

class MasterDataApi {
  MasterDataApi({ApiClient? apiClient, this.lookup, this.menuCode = '05002'})
    : _api = apiClient ?? ApiClient();
  final ApiClient _api;
  final String? lookup;
  final String menuCode;

  Future<Map<String, bool>> actions() async {
    final data = await _api.get(
      '/api/support/master-data/actions',
      query: {'menuCode': menuCode},
    );
    if (data is! Map) return const {};
    return Map<String, bool>.fromEntries(
      data.entries.map(
        (entry) => MapEntry('${entry.key}', entry.value == true),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> groups() async =>
      List<Map<String, dynamic>>.from(
        await _api.get(
              '/api/support/master-data/groups',
              query: {'lookup': ?lookup, 'menuCode': menuCode},
            )
            as List,
      );
  Future<List<Map<String, dynamic>>> list(
    String groupCode, {
    String? search,
  }) async => List<Map<String, dynamic>>.from(
    await _api.get(
          '/api/support/master-data',
          query: {
            'groupCode': groupCode,
            'lookup': ?lookup,
            'menuCode': menuCode,
            if (search != null && search.isNotEmpty) 'search': search,
          },
        )
        as List,
  );
  Future<void> create(String groupCode, Map<String, dynamic> body) async {
    await _api.post(
      '/api/support/master-data/$groupCode?menuCode=$menuCode',
      body: body,
    );
  }

  Future<void> update(
    String groupCode,
    String code,
    Map<String, dynamic> body,
  ) async {
    await _api.put(
      '/api/support/master-data/$groupCode/$code?menuCode=$menuCode',
      body: body,
    );
  }

  Future<void> delete(String groupCode, String code) async {
    await _api.delete(
      '/api/support/master-data/$groupCode/$code?menuCode=$menuCode',
    );
  }

  void dispose() => _api.dispose();
}
