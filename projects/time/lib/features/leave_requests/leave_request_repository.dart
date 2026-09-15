import 'package:laoo_shared_core/laoo_shared_core.dart';

class LeaveRequestRepository {
  LeaveRequestRepository(this.api, this.mode);

  final JsonApiClient api;
  final String mode;
  static const _path = '/api/time/leave-requests';

  Future<Map<String, dynamic>> actions() async => Map<String, dynamic>.from(
        await api.get('$_path/actions', query: {'mode': mode}) as Map,
      );

  Future<Map<String, dynamic>> lookups() async => Map<String, dynamic>.from(
        await api.get('$_path/lookups', query: {'mode': mode}) as Map,
      );

  Future<Map<String, dynamic>> list({
    String? status,
    DateTime? fromWorkDate,
    DateTime? toWorkDate,
    int page = 1,
    int pageSize = 30,
  }) async => Map<String, dynamic>.from(
        await api.get(
          _path,
          query: {
            'mode': mode,
            'page': '$page',
            'pageSize': '$pageSize',
            if (status?.isNotEmpty == true) 'status': status!,
            if (fromWorkDate != null) 'fromWorkDate': _date(fromWorkDate),
            if (toWorkDate != null) 'toWorkDate': _date(toWorkDate),
          },
        ) as Map,
      );

  Future<Map<String, dynamic>> submit(Map<String, dynamic> value) async =>
      Map<String, dynamic>.from(
        await api.post('$_path?mode=$mode', body: value) as Map,
      );

  Future<void> decide(int requestId, {
    required String decisionCode,
    required String rowVersion,
    String? reason,
  }) => api.post('$_path/$requestId/decision', body: {
        'decisionCode': decisionCode,
        'rowVersion': rowVersion,
        'reason': reason,
      });

  Future<void> cancel(int requestId, {
    required String rowVersion,
    String? reason,
  }) => api.post('$_path/$requestId/cancel', body: {
        'rowVersion': rowVersion,
        'reason': reason,
      });

  static String _date(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}
