import '../../../core/api/api_client.dart';

class ServiceDashboardApi {
  ServiceDashboardApi({ApiClient? client}) : _client = client ?? ApiClient();
  final ApiClient _client;
  Future<Map<String, dynamic>> load(DateTime from, DateTime to) async =>
      Map<String, dynamic>.from(
        await _client.get(
              '/api/service/dashboard',
              query: {'from': _date(from), 'to': _date(to)},
            )
            as Map,
      );
  String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}
