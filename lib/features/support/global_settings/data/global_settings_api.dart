import '../../../../core/api/api_client.dart';

class GlobalSettingsApi {
  GlobalSettingsApi({ApiClient? client}) : _client = client ?? ApiClient();
  final ApiClient _client;
  Future<Map<String, dynamic>> get() async => Map<String, dynamic>.from(await _client.get('/api/global-settings') as Map);
  Future<void> save({required double itemMB, required double cardMB, String? itemDescription, String? cardDescription}) async => _client.put('/api/global-settings', body: {'maxItemImageSizeMB': itemMB, 'maxBusinessCardImageSizeMB': cardMB, 'descriptionItemImage': itemDescription ?? '', 'descriptionBusinessCardImage': cardDescription ?? ''});
  void dispose() => _client.dispose();
}
