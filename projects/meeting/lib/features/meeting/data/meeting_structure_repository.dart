import '../../../../core/api/api_client.dart';

class MeetingStructureRepository {
  MeetingStructureRepository({ApiClient? api}) : _api = api ?? ApiClient();
  final ApiClient _api;
  static const _path = '/api/company/meeting-structure';

  Future<List<Map<String, dynamic>>> get({int? branchId}) async =>
      List<Map<String, dynamic>>.from(await _api.get(_path, query: {if (branchId != null) 'branchId': '$branchId'}) as List);
  Future<Map<String, bool>> actions() async => Map<String, bool>.fromEntries((await _api.get('$_path/actions') as Map).entries.map((e) => MapEntry('${e.key}', e.value == true)));
  Future<int> saveBuilding(Map<String, dynamic> body, {int? id}) async => ((await (id == null ? _api.post('$_path/buildings', body: body) : _api.put('$_path/buildings/$id', body: body))) as Map)['buildingId'] as int;
  Future<String> uploadBuildingImage(int id, List<int> bytes, String filename) async => ((await _api.upload('$_path/buildings/$id/image', bytes: bytes, filename: filename)) as Map)['imageUrl'] as String;
  Future<void> saveFloor(Map<String, dynamic> body, {int? id}) async => id == null ? _api.post('$_path/floors', body: body) : _api.put('$_path/floors/$id', body: body);
  Future<void> deleteBuilding(int id) => _api.delete('$_path/buildings/$id');
  Future<void> deleteFloor(int id) => _api.delete('$_path/floors/$id');
}
