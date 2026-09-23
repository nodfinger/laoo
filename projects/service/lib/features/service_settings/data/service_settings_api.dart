import '../../../core/api/api_client.dart';

class ServiceSettingsApi {
  ServiceSettingsApi({ApiClient? client}) : _client = client ?? ApiClient();
  final ApiClient _client;

  Future<Map<String, dynamic>> get() async => Map<String, dynamic>.from(
    await _client.get('/api/service/settings') as Map,
  );

  Future<void> update(Map<String, dynamic> settings) async {
    await _client.put('/api/service/settings', body: settings);
  }
}
