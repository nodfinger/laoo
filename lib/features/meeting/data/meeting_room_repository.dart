import '../../../../core/api/api_client.dart';

class MeetingRoomRepository {
  MeetingRoomRepository({ApiClient? api}) : _api = api ?? ApiClient();
  final ApiClient _api;
  static const _path = '/api/company/meeting-rooms';
  Future<List<Map<String, dynamic>>> get() async =>
      List<Map<String, dynamic>>.from(await _api.get(_path) as List);
  Future<Map<String, bool>> actions() async => Map<String, bool>.fromEntries(
    (await _api.get('$_path/actions') as Map).entries.map(
      (e) => MapEntry('${e.key}', e.value == true),
    ),
  );
  Future<int> save(Map<String, dynamic> body, {int? id}) async =>
      ((await (id == null
                  ? _api.post(_path, body: body)
                  : _api.put('$_path/$id', body: body)))
              as Map)['roomId']
          as int;
  Future<void> delete(int id) => _api.delete('$_path/$id');
  Future<List<Map<String, dynamic>>> contacts(int roomId) async =>
      List<Map<String, dynamic>>.from(
        await _api.get('$_path/$roomId/contacts') as List,
      );
  Future<void> saveContacts(int roomId, List<int> employeeIds) =>
      _api.put('$_path/$roomId/contacts', body: {'employeeIds': employeeIds});
  Future<String> uploadImage(
    int id,
    String kind,
    List<int> bytes,
    String filename,
  ) async =>
      ((await _api.upload(
                '$_path/$id/images/$kind',
                bytes: bytes,
                filename: filename,
              ))
              as Map)['url']
          as String;
  Future<List<Map<String, dynamic>>> rules(int roomId) async =>
      List<Map<String, dynamic>>.from(
        await _api.get('$_path/$roomId/rules') as List,
      );
  Future<int> saveRule(
    int roomId,
    Map<String, dynamic> body, {
    int? ruleId,
  }) async =>
      ((await (ruleId == null
                  ? _api.post('$_path/$roomId/rules', body: body)
                  : _api.put('$_path/$roomId/rules', body: body)))
              as Map)['ruleId']
          as int;
  Future<void> deleteRule(int roomId) => _api.delete('$_path/$roomId/rules');
}
