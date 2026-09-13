import 'package:laoo_shared_core/laoo_shared_core.dart';

class AttendanceResultsRepository {
  AttendanceResultsRepository(this.api);

  final JsonApiClient api;
  static const path = '/api/time/attendance/results';

  Future<Map<String, dynamic>> actions() async => Map<String, dynamic>.from(
    await api.get('$path/actions') as Map,
  );

  Future<Map<String, dynamic>> list({
    required DateTime fromWorkDate,
    required DateTime toWorkDate,
    String? employee,
    String? statusCode,
    int page = 1,
    int pageSize = 30,
  }) async => Map<String, dynamic>.from(
    await api.get(
          path,
          query: {
            'fromWorkDate': _date(fromWorkDate),
            'toWorkDate': _date(toWorkDate),
            'page': '$page',
            'pageSize': '$pageSize',
            if (employee?.trim().isNotEmpty == true) 'employee': employee!.trim(),
            if (statusCode?.trim().isNotEmpty == true)
              'statusCode': statusCode!.trim(),
          },
        )
        as Map,
  );

  static String _date(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}
