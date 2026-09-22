import '../../../core/api/api_client.dart';

class ServiceRequestApi {
  ServiceRequestApi({ApiClient? client}) : _client = client ?? ApiClient();
  final ApiClient _client;

  Future<Map<String, dynamic>> actions() async => Map<String, dynamic>.from(
    await _client.get('/api/service/requests/actions') as Map,
  );

  Future<Map<String, dynamic>> lookup({String search = ''}) async =>
      Map<String, dynamic>.from(
        await _client.get(
              '/api/service/requests/lookup',
              query: {'search': search},
            )
            as Map,
      );

  Future<Map<String, dynamic>> list({
    String search = '',
    String status = '',
    int page = 1,
  }) async => Map<String, dynamic>.from(
    await _client.get(
          '/api/service/requests',
          query: {
            'search': search,
            'status': status,
            'page': '$page',
            'pageSize': '20',
          },
        )
        as Map,
  );

  Future<Map<String, dynamic>> create({
    required bool selfService,
    int? requesterId,
    String? requesterType,
    required int? equipmentItemId,
    required String subject,
    required String detail,
  }) async => Map<String, dynamic>.from(
    await _client.post(
          selfService ? '/api/service/requests/self' : '/api/service/requests',
          body: {
            'requesterId': requesterId,
            'requesterType': requesterType,
            'equipmentItemId': equipmentItemId,
            'subject': subject,
            'detail': detail,
          },
        )
        as Map,
  );
}
