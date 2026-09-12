import 'package:laoo_shared_core/laoo_shared_core.dart';

class TimeCorrectionRepository {
  TimeCorrectionRepository(this.api, this.mode);

  final JsonApiClient api;
  final String mode;
  static const path = '/api/time/corrections';

  Future<Map<String, dynamic>> actions() async => Map<String, dynamic>.from(
    await api.get('$path/actions', query: {'mode': mode}) as Map,
  );

  Future<Map<String, dynamic>> lookups() async => Map<String, dynamic>.from(
    await api.get('$path/lookups', query: {'mode': mode}) as Map,
  );

  Future<Map<String, dynamic>> list({
    String? status,
    int page = 1,
    int pageSize = 30,
  }) async => Map<String, dynamic>.from(
    await api.get(
          path,
          query: {
            'mode': mode,
            'page': '$page',
            'pageSize': '$pageSize',
            if (status?.isNotEmpty == true) 'status': status!,
          },
        )
        as Map,
  );

  Future<Map<String, dynamic>> get(int id) async => Map<String, dynamic>.from(
    await api.get('$path/$id', query: {'mode': mode}) as Map,
  );

  Future<List<Map<String, dynamic>>> sessions(
    int employeeId,
    DateTime workDate,
  ) async {
    final value = Map<String, dynamic>.from(
      await api.get(
            '$path/sessions',
            query: {
              'mode': mode,
              'employeeId': '$employeeId',
              'workDate': _date(workDate),
            },
          )
          as Map,
    );
    return (value['items'] as List? ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<Map<String, dynamic>> submit(Map<String, dynamic> body) async =>
      Map<String, dynamic>.from(
        await api.post('$path/${mode == 'self' ? 'self' : 'proxy'}', body: body)
            as Map,
      );

  Future<void> decide(
    int id, {
    required String decision,
    required String rowVersion,
    String? reason,
  }) async => api.post(
    '$path/$id/decision',
    body: {
      'decisionCode': decision,
      'rowVersion': rowVersion,
      'reason': reason,
    },
  );

  Future<void> cancel(
    int id, {
    required String rowVersion,
    required String reason,
  }) async => api.post(
    '$path/$id/cancel',
    body: {
      'decisionCode': 'CANCELLED',
      'rowVersion': rowVersion,
      'reason': reason,
    },
  );

  static String _date(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}
