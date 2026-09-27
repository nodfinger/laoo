import '../../../core/api/api_client.dart';

class MeetingRoomUsageRepository {
  MeetingRoomUsageRepository({ApiClient? api}) : _api = api ?? ApiClient();
  final ApiClient _api;
  static const _path = '/api/company/meeting-room-usage';

  Future<Map<String, dynamic>> list({
    required DateTime from,
    required DateTime to,
    String? search,
    String? status,
    int? roomId,
    int page = 1,
    int pageSize = 20,
  }) => _get(
    _path,
    from,
    to,
    search: search,
    status: status,
    roomId: roomId,
    page: page,
    pageSize: pageSize,
  );

  Future<Map<String, dynamic>> utilization({
    required DateTime from,
    required DateTime to,
    int? roomId,
    int page = 1,
    int pageSize = 20,
  }) => _get(
    '$_path/reports/utilization',
    from,
    to,
    roomId: roomId,
    page: page,
    pageSize: pageSize,
  );

  Future<Map<String, dynamic>> noShow({
    required DateTime from,
    required DateTime to,
    String? search,
    int? roomId,
    int page = 1,
    int pageSize = 20,
  }) => _get(
    '$_path/reports/no-show',
    from,
    to,
    search: search,
    roomId: roomId,
    page: page,
    pageSize: pageSize,
  );

  Future<Map<String, dynamic>> feedback({
    required DateTime from,
    required DateTime to,
    String? search,
    int? roomId,
    int page = 1,
    int pageSize = 20,
  }) => _get(
    '$_path/reports/feedback',
    from,
    to,
    search: search,
    roomId: roomId,
    page: page,
    pageSize: pageSize,
  );

  Future<Map<String, dynamic>> _get(
    String path,
    DateTime from,
    DateTime to, {
    String? search,
    String? status,
    int? roomId,
    required int page,
    required int pageSize,
  }) async => Map<String, dynamic>.from(
    await _api.get(
          path,
          query: {
            'dateFrom': _date(from),
            'dateTo': _date(to),
            if (search?.trim().isNotEmpty == true) 'search': search!.trim(),
            if (status?.isNotEmpty == true) 'status': status!,
            if (roomId != null) 'roomId': '$roomId',
            'page': '$page',
            'pageSize': '$pageSize',
          },
        )
        as Map,
  );

  Future<List<Map<String, dynamic>>> rooms() async =>
      List<Map<String, dynamic>>.from(
        ((await _api.get('$_path/rooms') as Map)['items'] as List? ?? const []),
      );

  Future<void> checkIn(int bookingId, int slotId) =>
      _api.put('$_path/$bookingId/$slotId/check-in', body: const {});

  Future<void> returnRoom(int bookingId, int slotId, String? remark) =>
      _api.put(
        '$_path/$bookingId/$slotId/return',
        body: {if (remark?.trim().isNotEmpty == true) 'remark': remark!.trim()},
      );

  static String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}
