import '../../../../core/api/api_client.dart';

class VendorApi {
  VendorApi({ApiClient? client}) : _client = client ?? ApiClient();
  final ApiClient _client;
  static const _path = '/api/company/vendors';
  Future<Map<String, bool>> actions() async =>
      Map<String, bool>.from(await _client.get('$_path/actions') as Map);
  Future<Map<String, dynamic>> list({
    String search = '',
    bool? isActive,
    String? entityTypeCode,
    int page = 1,
    int pageSize = 20,
  }) async => Map<String, dynamic>.from(
    await _client.get(
          _path,
          query: {
            'search': search,
            'page': '$page',
            'pageSize': '$pageSize',
            if (isActive != null) 'isActive': '$isActive',
            'entityTypeCode': ?entityTypeCode,
          },
        )
        as Map,
  );
  Future<Map<String, dynamic>> get(int id) async =>
      Map<String, dynamic>.from(await _client.get('$_path/$id') as Map);
  Future<Map<String, dynamic>> save(
    Map<String, dynamic> body, {
    int? id,
  }) async => Map<String, dynamic>.from(
    (id == null
            ? await _client.post(_path, body: body)
            : await _client.put('$_path/$id', body: body))
        as Map,
  );
  Future<void> delete(int id, String rowVersion) async =>
      _client.delete('$_path/$id', query: {'rowVersion': rowVersion});
  void dispose() => _client.dispose();
}
