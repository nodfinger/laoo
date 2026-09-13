import 'package:laoo_shared_core/laoo_shared_core.dart';

class AttendanceEventsRepository {
  AttendanceEventsRepository(this.api);

  final JsonApiClient api;
  static const path = '/api/time/attendance/events';

  Future<Map<String, dynamic>> actions() async => Map<String, dynamic>.from(
    await api.get('$path/actions') as Map,
  );

  Future<Map<String, dynamic>> list({
    required DateTime fromDateTime,
    required DateTime toDateTime,
    String? employee,
    String? deviceCode,
    String? sourceCode,
    int page = 1,
    int pageSize = 30,
  }) async => Map<String, dynamic>.from(
    await api.get(
          path,
          query: {
            'fromDateTime': fromDateTime.toIso8601String(),
            'toDateTime': toDateTime.toIso8601String(),
            'page': '$page',
            'pageSize': '$pageSize',
            if (employee?.trim().isNotEmpty == true) 'employee': employee!.trim(),
            if (deviceCode?.trim().isNotEmpty == true)
              'deviceCode': deviceCode!.trim(),
            if (sourceCode?.trim().isNotEmpty == true)
              'sourceCode': sourceCode!.trim(),
          },
        )
        as Map,
  );
}
