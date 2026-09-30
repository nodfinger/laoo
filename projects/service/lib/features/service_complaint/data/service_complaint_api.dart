import '../../../core/api/api_client.dart';

class ServiceComplaintApi {
  ServiceComplaintApi({ApiClient? client}) : _client = client ?? ApiClient();
  final ApiClient _client;

  Future<Map<String, dynamic>> actions() async => Map<String, dynamic>.from(
    await _client.get('/api/service/complaints/actions') as Map,
  );

  Future<Map<String, dynamic>> list({
    String search = '',
    String status = '',
    bool self = true,
    int page = 1,
  }) async => Map<String, dynamic>.from(
    await _client.get(
          '/api/service/complaints',
          query: {
            'search': search,
            'status': status,
            'self': '$self',
            'page': '$page',
            'pageSize': '20',
          },
        )
        as Map,
  );

  Future<Map<String, dynamic>> detail(int id) async =>
      Map<String, dynamic>.from(
        await _client.get('/api/service/complaints/$id') as Map,
      );

  Future<Map<String, dynamic>> create({
    required String subject,
    required String detail,
  }) async => Map<String, dynamic>.from(
    await _client.post(
          '/api/service/complaints',
          body: {'subject': subject, 'detail': detail},
        )
        as Map,
  );

  Future<void> edit(
    int id, {
    required String subject,
    required String detail,
    required String rowVersion,
  }) => _client.put(
    '/api/service/complaints/$id',
    body: {'subject': subject, 'detail': detail, 'rowVersion': rowVersion},
  );

  Future<void> delete(int id, String rowVersion) => _client.delete(
    '/api/service/complaints/$id',
    query: {'rowVersion': rowVersion},
  );

  Future<void> start(int id) =>
      _client.post('/api/service/complaints/$id/start', body: {});
  Future<void> complete(int id, String resolutionDetail) => _client.post(
    '/api/service/complaints/$id/complete',
    body: {'resolutionDetail': resolutionDetail},
  );
  Future<void> cancel(int id, String reason) => _client.post(
    '/api/service/complaints/$id/cancel',
    body: {'cancellationReason': reason},
  );

  Future<List<Map<String, dynamic>>> attachments(int id) async {
    final value =
        await _client.get('/api/service/complaints/$id/attachments') as Map;
    return ((value['items'] as List?) ?? const [])
        .map((x) => Map<String, dynamic>.from(x as Map))
        .toList();
  }

  Future<Map<String, dynamic>> uploadAttachment(
    int id, {
    required String fileName,
    required List<int> bytes,
  }) async => Map<String, dynamic>.from(
    await _client.upload(
          '/api/service/complaints/$id/attachments',
          fileName: fileName,
          bytes: bytes,
        )
        as Map,
  );

  Future<void> deleteAttachment(int id, int attachmentId) =>
      _client.delete('/api/service/complaints/$id/attachments/$attachmentId');

  Future<List<int>> downloadAttachment(int id, int attachmentId) =>
      _client.getBytes('/api/service/complaints/$id/attachments/$attachmentId');
}
