import '../../../core/api/api_client.dart';

class MeetingEquipmentRequestRepository {
  MeetingEquipmentRequestRepository({ApiClient? api})
    : _api = api ?? ApiClient();
  final ApiClient _api;
  static const _path = '/api/company/meeting-equipment-requests';

  Future<Map<String, dynamic>> list({String? status}) async =>
      Map<String, dynamic>.from(
        await _api.get(
              _path,
              query: {
                if (status != null && status.isNotEmpty) 'status': status,
              },
            )
            as Map,
      );

  Future<Map<String, dynamic>> departmentTasks({
    String? status,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? search,
    int? roomId,
    int page = 1,
    int pageSize = 20,
  }) async => Map<String, dynamic>.from(
    await _api.get(
          '$_path/department-tasks',
          query: {
            if (status != null && status.isNotEmpty) 'status': status,
            if (dateFrom != null) 'dateFrom': dateFrom.toIso8601String(),
            if (dateTo != null) 'dateTo': dateTo.toIso8601String(),
            if (search != null && search.trim().isNotEmpty)
              'search': search.trim(),
            if (roomId != null) 'roomId': '$roomId',
            'page': '$page',
            'pageSize': '$pageSize',
          },
        )
        as Map,
  );

  Future<Map<String, dynamic>> booking(int bookingId) async =>
      Map<String, dynamic>.from(
        await _api.get('$_path/booking/$bookingId') as Map,
      );

  Future<List<Map<String, dynamic>>> departmentTaskRooms() async =>
      List<Map<String, dynamic>>.from(
        ((await _api.get('$_path/department-tasks/rooms') as Map)['items']
            as List),
      );

  Future<Map<String, dynamic>> settings() async =>
      Map<String, dynamic>.from(await _api.get('$_path/settings') as Map);

  Future<void> saveSettings(bool requireReview) => _api.put(
    '$_path/settings',
    body: {'requireEquipmentRequestReview': requireReview},
  );

  Future<void> savePlan(int bookingId, DateTime cutoff, bool isActive) =>
      _api.put(
        '$_path/booking/$bookingId/plan',
        body: {
          'requestCutoffDateTime': cutoff.toIso8601String(),
          'isActive': isActive,
        },
      );

  Future<void> save(int bookingId, List<Map<String, dynamic>> items) =>
      _api.post('$_path/booking/$bookingId', body: {'items': items});

  Future<void> review(
    int requestId,
    String action, {
    String? remark,
    List<int>? detailIds,
  }) => _api.put(
    '$_path/requests/$requestId/review',
    body: {
      'actionCode': action,
      if (remark != null && remark.trim().isNotEmpty) 'remark': remark.trim(),
      if (detailIds != null && detailIds.isNotEmpty) 'detailIds': detailIds,
    },
  );

  Future<void> cancel(int detailId) =>
      _api.put('$_path/details/$detailId/cancel');

  Future<Map<String, dynamic>> timeline(int requestId) async =>
      Map<String, dynamic>.from(
        await _api.get('$_path/requests/$requestId/timeline') as Map,
      );

  Future<void> updateStatus(
    int detailId,
    String status, {
    String? resultRemark,
  }) => _api.put(
    '$_path/details/$detailId/status',
    body: {
      'statusCode': status,
      if (resultRemark != null && resultRemark.trim().isNotEmpty)
        'resultRemark': resultRemark.trim(),
    },
  );
}
