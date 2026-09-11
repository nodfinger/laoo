import '../../../../core/api/api_client.dart';

class ResidentRegistryApi {
  ResidentRegistryApi({ApiClient? client}) : _client = client ?? ApiClient();
  final ApiClient _client;
  static const _path = '/api/company/residents';

  Future<Map<String, bool>> actions() async =>
      Map<String, bool>.from(await _client.get('$_path/actions') as Map);
  Future<Map<String, dynamic>> list({
    String search = '',
    bool? isActive,
    int? buildingId,
    int? roomId,
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
            if (buildingId != null) 'buildingId': '$buildingId',
            if (roomId != null) 'roomId': '$roomId',
          },
        )
        as Map,
  );
  Future<Map<String, dynamic>> lookup({
    int? includePersonId,
    int? includeRoomId,
  }) async => Map<String, dynamic>.from(
    await _client.get(
          '$_path/lookup',
          query: {
            if (includePersonId != null) 'includePersonId': '$includePersonId',
            if (includeRoomId != null) 'includeRoomId': '$includeRoomId',
          },
        )
        as Map,
  );
  Future<Map<String, dynamic>> save(
    Map<String, dynamic> body, {
    int? id,
  }) async => Map<String, dynamic>.from(
    (id == null
            ? await _client.post(_path, body: body)
            : await _client.put('$_path/$id', body: body))
        as Map,
  );
  Future<void> delete(int id, String rowVersion) =>
      _client.delete('$_path/$id', query: {'rowVersion': rowVersion});
  void dispose() => _client.dispose();
}
