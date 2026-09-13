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

  Future<Map<String, dynamic>> booking(int bookingId) async =>
      Map<String, dynamic>.from(
        await _api.get('$_path/booking/$bookingId') as Map,
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
