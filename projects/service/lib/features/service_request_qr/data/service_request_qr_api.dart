import '../../../core/api/api_client.dart';

class ServiceRequestQrApi {
  ServiceRequestQrApi({ApiClient? client}) : _client = client ?? ApiClient();
  final ApiClient _client;

  Future<Map<String, dynamic>> actions() async => Map<String, dynamic>.from(
    await _client.get('/api/service/request-qr-portals/actions') as Map,
  );

  Future<Map<String, dynamic>> list({
    String search = '',
    String status = '',
    int page = 1,
  }) async => Map<String, dynamic>.from(
    await _client.get(
          '/api/service/request-qr-portals',
          query: {
            'search': search,
            'status': status,
            'page': '$page',
            'pageSize': '20',
          },
        )
        as Map,
  );

  Future<List<Map<String, dynamic>>> lookup({String search = ''}) async {
    final value =
        await _client.get(
              '/api/service/request-qr-portals/lookup',
              query: {'search': search},
            )
            as Map;
    return ((value['items'] as List?) ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<Map<String, dynamic>> create(int itemInstanceId) async =>
      Map<String, dynamic>.from(
        await _client.post(
              '/api/service/request-qr-portals',
              body: {'itemInstanceId': itemInstanceId},
            )
            as Map,
      );

  Future<void> setActive(int id, bool isActive) => _client.put(
    '/api/service/request-qr-portals/$id/active',
    body: {'isActive': isActive},
  );

  Future<Map<String, dynamic>> scan(String token) async =>
      Map<String, dynamic>.from(
        await _client.get('/api/service/request-qr-portals/scan/$token') as Map,
      );
}
