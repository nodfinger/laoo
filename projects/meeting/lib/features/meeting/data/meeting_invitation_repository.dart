import '../../../../core/api/api_client.dart';

class MeetingInvitationRepository {
  MeetingInvitationRepository({ApiClient? api}) : _api = api ?? ApiClient();
  final ApiClient _api;
  static const _path = '/api/company/my-meeting-invitations';

  Future<Map<String, dynamic>> list({
    String? search,
    String? status,
    int page = 1,
  }) async => Map<String, dynamic>.from(
    await _api.get(
          _path,
          query: {
            'page': '$page',
            'pageSize': '20',
            if (search != null && search.trim().isNotEmpty)
              'search': search.trim(),
            if (status != null && status.isNotEmpty) 'status': status,
          },
        )
        as Map,
  );

  Future<Map<String, dynamic>> get(int participantId) async =>
      Map<String, dynamic>.from(await _api.get('$_path/$participantId') as Map);

  Future<Map<String, bool>> actions() async => Map<String, bool>.fromEntries(
    (await _api.get('$_path/actions') as Map).entries.map(
      (entry) => MapEntry('${entry.key}', entry.value == true),
    ),
  );

  Future<void> respond(
    int participantId, {
    required String status,
    String? remark,
  }) => _api.put(
    '$_path/$participantId/response',
    body: {'status': status, 'remark': remark},
  );
}
