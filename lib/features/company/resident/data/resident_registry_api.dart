import '../../../../core/api/api_client.dart';

class ResidentRegistryApi {
  ResidentRegistryApi({ApiClient? client}) : _client = client ?? ApiClient();
  final ApiClient _client;
  static const _path = '/api/company/residents';

  Future<Map<String, bool>> actions() async =>
      Map<String, bool>.from(await _client.get('/actions') as Map);
  Future<Map<String, dynamic>> list({
    String search = '',
    bool? isActive,
    int? buildingId,
    int? roomId,
    int? laneId,
    int? houseId,
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
            if (laneId != null) 'laneId': '$laneId',
            if (houseId != null) 'houseId': '$houseId',
          },
        )
        as Map,
  );
  Future<Map<String, dynamic>> lookup({
    int? includePersonId,
    int? includeRoomId,
    int? includeHouseId,
  }) async => Map<String, dynamic>.from(
    await _client.get(
          '/lookup',
          query: {
            if (includePersonId != null) 'includePersonId': '$includePersonId',
            if (includeRoomId != null) 'includeRoomId': '$includeRoomId',
            if (includeHouseId != null) 'includeHouseId': '$includeHouseId',
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
            : await _client.put('/', body: body))
        as Map,
  );
  Future<void> delete(int id, String rowVersion) =>
      _client.delete('/', query: {'rowVersion': rowVersion});
  void dispose() => _client.dispose();
}
