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
    bool selfService = false,
    int page = 1,
  }) async => Map<String, dynamic>.from(
    await _client.get(
          '/api/service/requests',
          query: {
            'search': search,
            'status': status,
            'self': '$selfService',
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
    String? qrToken,
  }) async => Map<String, dynamic>.from(
    await _client.post(
          selfService ? '/api/service/requests/self' : '/api/service/requests',
          body: {
            'requesterId': requesterId,
            'requesterType': requesterType,
            'equipmentItemId': equipmentItemId,
            'subject': subject,
            'detail': detail,
            'qrToken': qrToken,
          },
        )
        as Map,
  );

  Future<List<Map<String, dynamic>>> attachments(int requestId) async {
    final value =
        await _client.get('/api/service/requests/$requestId/attachments')
            as Map;
    return ((value['items'] as List?) ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<Map<String, dynamic>> uploadAttachment(
    int requestId, {
    required String fileName,
    required List<int> bytes,
  }) async => Map<String, dynamic>.from(
    await _client.upload(
          '/api/service/requests/$requestId/attachments',
          fileName: fileName,
          bytes: bytes,
        )
        as Map,
  );

  Future<void> deleteAttachment(int requestId, int attachmentId) async {
    await _client.delete(
      '/api/service/requests/$requestId/attachments/$attachmentId',
    );
  }

  Future<List<int>> downloadAttachment(int requestId, int attachmentId) =>
      _client.getBytes(
        '/api/service/requests/$requestId/attachments/$attachmentId',
      );

  Future<Map<String, dynamic>> detail(int id) async =>
      Map<String, dynamic>.from(
        await _client.get('/api/service/requests/$id') as Map,
      );

  Future<List<Map<String, dynamic>>> technicians() async {
    final value = await _client.get('/api/service/requests/technicians') as Map;
    return ((value['items'] as List?) ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<void> receive(int id, int employeeId) async {
    await _client.post(
      '/api/service/requests/$id/receive',
      body: {'assignedEmployeeId': employeeId},
    );
  }

  Future<void> start(int id) async {
    await _client.post('/api/service/requests/$id/start', body: {});
  }

  Future<Map<String, dynamic>> partsLookup() async => Map<String, dynamic>.from(
    await _client.get('/api/service/requests/parts/lookup') as Map,
  );
  Future<void> complete(
    int id,
    String resolutionDetail, {
    List<Map<String, dynamic>> parts = const [],
  }) async {
    await _client.post(
      '/api/service/requests/$id/complete',
      body: {'resolutionDetail': resolutionDetail, 'parts': parts},
    );
  }

  Future<void> cancel(int id, String reason) async {
    await _client.post(
      '/api/service/requests/$id/cancel',
      body: {'cancellationReason': reason},
    );
  }
}
