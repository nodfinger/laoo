import '../../../core/api/api_client.dart';

class MeetingRoomBookingRepository {
  MeetingRoomBookingRepository({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;
  static const _path = '/api/company/meeting-room-bookings';

  Future<Map<String, bool>> actions() async {
    final data = await _api.get('$_path/actions') as Map;
    return Map<String, bool>.fromEntries(
      data.entries.map(
        (entry) => MapEntry('${entry.key}', entry.value == true),
      ),
    );
  }

  Future<Map<String, dynamic>> options() async =>
      Map<String, dynamic>.from(await _api.get('$_path/options') as Map);

  Future<Map<String, dynamic>> list({
    required DateTime dateFrom,
    required DateTime dateTo,
    int page = 1,
    int pageSize = 30,
    int? roomId,
    bool mine = false,
  }) async {
    final data = await _api.get(
      _path,
      query: {
        'dateFrom': _dateOnly(dateFrom),
        'dateTo': _dateOnly(dateTo),
        'page': '$page',
        'pageSize': '$pageSize',
        if (mine) 'mine': 'true',
        if (roomId != null) 'roomId': '$roomId',
      },
    );
    return Map<String, dynamic>.from(data as Map);
  }

  Future<List<Map<String, dynamic>>> calendar({
    required DateTime from,
    required DateTime to,
    int? branchId,
    int? buildingId,
    int? floorId,
    int? roomId,
    String? status,
  }) async {
    final data = await _api.get(
      '$_path/calendar',
      query: {
        'from': _dateOnly(from),
        'to': _dateOnly(to),
        if (branchId != null) 'branchId': '$branchId',
        if (buildingId != null) 'buildingId': '$buildingId',
        if (floorId != null) 'floorId': '$floorId',
        if (roomId != null) 'roomId': '$roomId',
        if (status != null && status.isNotEmpty) 'status': status,
      },
    );
    return List<Map<String, dynamic>>.from(
      Map<String, dynamic>.from(data as Map)['items'] as List,
    );
  }

  Future<List<Map<String, dynamic>>> availability({
    required List<Map<String, String>> slots,
    int? roomId,
    int? branchId,
    int? buildingId,
    int? floorId,
    int? attendeeCount,
    int? excludeBookingId,
  }) async {
    final data = await _api.post(
      '$_path/availability',
      body: {
        'slots': slots,
        'roomId': roomId,
        'branchId': branchId,
        'buildingId': buildingId,
        'floorId': floorId,
        'attendeeCount': attendeeCount,
        'excludeBookingId': excludeBookingId,
      },
    );
    return List<Map<String, dynamic>>.from(data as List);
  }

  Future<Map<String, dynamic>> get(int id) async =>
      Map<String, dynamic>.from(await _api.get('$_path/$id') as Map);

  Future<Map<String, dynamic>> approvalRequests({
    int page = 1,
    int pageSize = 30,
    String? status,
    String? search,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    final data = await _api.get(
      '$_path/approval-requests',
      query: {
        'page': '$page',
        'pageSize': '$pageSize',
        if (status != null && status.isNotEmpty) 'status': status,
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        if (dateFrom != null) 'dateFrom': _dateOnly(dateFrom),
        if (dateTo != null) 'dateTo': _dateOnly(dateTo),
      },
    );
    return Map<String, dynamic>.from(data as Map);
  }

  Future<List<Map<String, dynamic>>> approvalHistory(int bookingId) async {
    final data = await _api.get('$_path/approval-requests/$bookingId/history');
    final body = Map<String, dynamic>.from(data as Map);
    return List<Map<String, dynamic>>.from(body['items'] as List? ?? const []);
  }

  Future<Map<String, dynamic>> decideApproval(
    int approvalId,
    String decision, {
    String? remark,
  }) async {
    final data = await _api.post(
      '$_path/approval-requests/$approvalId/decision',
      body: {'decision': decision, 'remark': remark},
    );
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> save(
    Map<String, dynamic> body, {
    int? id,
  }) async {
    final data = id == null
        ? await _api.post(_path, body: body)
        : await _api.put('$_path/$id', body: body);
    return Map<String, dynamic>.from(data as Map);
  }

  Future<void> cancel(int id) async => _api.delete('$_path/$id');

  Future<Map<String, dynamic>> rollback(int id, {String? remark}) async {
    final data = await _api.post(
      '$_path/$id/rollback',
      body: {'remark': remark},
    );
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Map<String, dynamic>> participants(int bookingId) async =>
      Map<String, dynamic>.from(
        await _api.get('$_path/$bookingId/participants') as Map,
      );

  Future<Map<String, dynamic>> saveParticipants(
    int bookingId,
    List<int> employeeIds,
  ) async => Map<String, dynamic>.from(
    await _api.put(
          '$_path/$bookingId/participants',
          body: {'employeeIds': employeeIds},
        )
        as Map,
  );

  static String _dateOnly(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  void dispose() => _api.dispose();
}
