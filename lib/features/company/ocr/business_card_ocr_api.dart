import 'dart:typed_data';
import '../../../core/api/api_client.dart';

class BusinessCardOcrApi {
  BusinessCardOcrApi({ApiClient? client}) : _client = client ?? ApiClient();
  final ApiClient _client;
  Future<dynamic> get(String path, Map<String, String> query) =>
      _client.get(path, query: query);
  Future<dynamic> upload(
    String path,
    Uint8List bytes,
    String name,
    Map<String, String> fields,
  ) => _client.upload(path, fileName: name, bytes: bytes, fields: fields);
  Future<Map<String, dynamic>> actions() async => Map<String, dynamic>.from(
    await _client.get('/api/company/ocr/business-cards/settings/actions')
        as Map,
  );
  Future<Map<String, dynamic>> settings() async => Map<String, dynamic>.from(
    await _client.get('/api/company/ocr/business-cards/settings') as Map,
  );
  Future<void> saveSettings(bool enabled, int size, int timeout) => _client.put(
    '/api/company/ocr/business-cards/settings',
    body: {
      'isEnabled': enabled,
      'maxImageSizeMB': size,
      'timeoutSeconds': timeout,
    },
  );
  void dispose() => _client.dispose();
}
