import '../../../core/api/api_client.dart';

class MeetingFoodOrderSummaryRepository {
  MeetingFoodOrderSummaryRepository({ApiClient? api})
    : _api = api ?? ApiClient();

  final ApiClient _api;
  static const path = '/api/company/meeting-food-order-summaries';

  Future<Map<String, dynamic>> list({
    required DateTime dateFrom,
    required DateTime dateTo,
    String? search,
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
          },
        )
        as Map,
  );

  Future<Map<String, dynamic>> get(int bookingId) async =>
      Map<String, dynamic>.from(await _api.get('$path/$bookingId') as Map);

  static String _dateOnly(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  void dispose() => _api.dispose();
}
