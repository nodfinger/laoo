import '../../../../core/api/api_client.dart';

class MeetingFacilityRepository {
  MeetingFacilityRepository({ApiClient? api}) : _api = api ?? ApiClient();
  final ApiClient _api;
  static const _path = '/api/company/meeting-facilities';

  Future<List<Map<String, dynamic>>> get() async =>
      List<Map<String, dynamic>>.from(await _api.get(_path) as List);
  Future<Map<String, bool>> actions() async => Map<String, bool>.fromEntries(
    (await _api.get('$_path/actions') as Map).entries.map(
      (entry) => MapEntry('${entry.key}', entry.value == true),
    ),
  );
  Future<List<Map<String, dynamic>>> departments() async =>
      List<Map<String, dynamic>>.from(
        await _api.get('$_path/departments') as List,
      );
  Future<int> save(Map<String, dynamic> body, {int? id}) async =>
      ((await (id == null
                  ? _api.post(_path, body: body)
                  : _api.put('$_path/$id', body: body)))
              as Map)['facilityId']
          as int;
  Future<void> delete(int id) => _api.delete('$_path/$id');
}
