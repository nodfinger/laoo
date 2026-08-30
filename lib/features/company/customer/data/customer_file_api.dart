import '../../../../core/api/api_client.dart';

class CustomerFileApi {
  CustomerFileApi({ApiClient? client}) : _client = client ?? ApiClient();
  final ApiClient _client;

  Future<List<Map<String, dynamic>>> list(int customerId) async =>
      List<Map<String, dynamic>>.from(
        await _client.get('/api/company/customers/$customerId/files') as List,
      );

  Future<void> upload(
    int customerId, {
    required String fileName,
    required List<int> bytes,
    required String fileType,
    String? description,
  }) async {
    await _client.upload(
      '/api/company/customers/$customerId/files',
      fileName: fileName,
      bytes: bytes,
      fields: {'fileType': fileType, 'description': description ?? ''},
    );
  }

  Future<List<int>> downloadBytes(int customerId, int fileId) =>
      _client.getBytes('/api/company/customers/$customerId/files/$fileId/download');

  Future<void> delete(int customerId, int fileId) async =>
      _client.delete('/api/company/customers/$customerId/files/$fileId');

  Future<void> updateDescription(
    int customerId,
    int fileId,
    String? description,
  ) async =>
      _client.put('/api/company/customers/$customerId/files/$fileId', body: {
        'description': description ?? '',
      });

  void dispose() => _client.dispose();
}
