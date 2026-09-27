import '../../../core/api/api_client.dart';

class MeetingFoodDistributionRepository {
  MeetingFoodDistributionRepository({ApiClient? api})
    : _api = api ?? ApiClient();

  final ApiClient _api;
  static const path = '/api/company/meeting-food-distribution';

  Future<Map<String, dynamic>> list({
    required DateTime dateFrom,
    required DateTime dateTo,
    String? search,
    String? status,
    int page = 1,
    int pageSize = 20,
  }) async => Map<String, dynamic>.from(
    await _api.get(
          path,
          query: {
            'dateFrom': _dateOnly(dateFrom),
            'dateTo': _dateOnly(dateTo),
            'page': '$page',
            'pageSize': '$pageSize',
            if (search != null && search.trim().isNotEmpty)
              'search': search.trim(),
            if (status != null && status.isNotEmpty) 'status': status,
          },
        )
        as Map,
  );

  Future<Map<String, dynamic>> detail(int participantId, int slotId) async =>
      Map<String, dynamic>.from(
        await _api.get('$path/$participantId/$slotId') as Map,
      );

  Future<Map<String, dynamic>> save(
    int participantId,
    int slotId,
    List<Map<String, dynamic>> items,
  ) async => Map<String, dynamic>.from(
    await _api.put('$path/$participantId/$slotId', body: {'items': items})
        as Map,
  );

  static String _dateOnly(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  void dispose() => _api.dispose();
}
