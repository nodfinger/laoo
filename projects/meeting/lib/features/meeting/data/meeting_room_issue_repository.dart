import '../../../../core/api/api_client.dart';

class MeetingRoomIssueRepository {
  MeetingRoomIssueRepository({ApiClient? api}) : _api = api ?? ApiClient();
  final ApiClient _api;
  static const _path = '/api/company/meeting-room-issues';

  Future<List<Map<String, dynamic>>> get({int? roomId}) async =>
      List<Map<String, dynamic>>.from(
        await _api.get(
              _path,
              query: {if (roomId != null) 'roomId': '${roomId}'},
            )
            as List,
      );

  Future<Map<String, bool>> actions() async => Map<String, bool>.fromEntries(
    (await _api.get('$_path/actions') as Map).entries.map(
      (entry) => MapEntry('${entry.key}', entry.value == true),
    ),
  );

  Future<void> create({
    required int roomId,
    required int itemId,
    required String description,
    String? imageUrl,
  }) => _api.post(
    _path,
    body: {
      'roomId': roomId,
      'itemId': itemId,
      'description': description,
      if (imageUrl != null && imageUrl.isNotEmpty) 'imageUrl': imageUrl,
    },
  );

  Future<void> updateStatus(int id, String statusCode) =>
      _api.put('$_path/$id/status', body: {'statusCode': statusCode});
}
