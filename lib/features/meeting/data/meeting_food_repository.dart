import '../../../../core/api/api_client.dart';

class MeetingFoodRepository {
  MeetingFoodRepository({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;
  static const _path = '/api/company/meeting-foods';

  Future<List<Map<String, dynamic>>> get() async =>
      List<Map<String, dynamic>>.from(await _api.get(_path) as List);

  Future<List<Map<String, dynamic>>> types() async =>
      List<Map<String, dynamic>>.from(await _api.get('$_path/types') as List);

  Future<Map<String, bool>> actions() async => Map<String, bool>.fromEntries(
    (await _api.get('$_path/actions') as Map).entries.map(
      (entry) => MapEntry('${entry.key}', entry.value == true),
    ),
  );

  Future<int> save(Map<String, dynamic> body, {int? id}) async =>
      ((await (id == null
                  ? _api.post(_path, body: body)
                  : _api.put('$_path/$id', body: body)))
              as Map)['foodId']
          as int;

  Future<String> uploadImage(int id, List<int> bytes, String filename) async =>
      ((await _api.upload('$_path/$id/image', bytes: bytes, filename: filename))
              as Map)['imageUrl']
          as String;

  Future<void> delete(int id) => _api.delete('$_path/$id');
}
