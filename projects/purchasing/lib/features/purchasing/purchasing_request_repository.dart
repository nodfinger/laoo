import 'package:laoo_shared_core/laoo_shared_core.dart';

class PurchasingRequestRepository {
  PurchasingRequestRepository(this.api);
  final JsonApiClient api;

  Future<Map<String, dynamic>> list({
    String? search,
    String? divisionId,
    String? departmentId,
    String? requesterId,
    int page = 1,
    int pageSize = 20,
  }) async {
    final value = await api.get('/api/purchasing/requests', query: {
      'page': '$page',
      'pageSize': '$pageSize',
      if (search?.trim().isNotEmpty == true) 'search': search!.trim(),
      if (divisionId?.isNotEmpty == true) 'divisionId': divisionId!,
      if (departmentId?.isNotEmpty == true) 'departmentId': departmentId!,
      if (requesterId?.isNotEmpty == true) 'requesterId': requesterId!,
    });
    return Map<String, dynamic>.from(value as Map);
  }

  Future<Map<String, dynamic>> get(int id) async =>
      Map<String, dynamic>.from(await api.get('/api/purchasing/requests/$id') as Map);

  Future<Map<String, dynamic>> save(Map<String, dynamic> body) async =>
      Map<String, dynamic>.from(await api.post('/api/purchasing/requests', body: body) as Map);

  Future<Map<String, dynamic>> update(int id, Map<String, dynamic> body) async =>
      Map<String, dynamic>.from(await api.put('/api/purchasing/requests/$id', body: body) as Map);

  Future<void> delete(int id) => api.delete('/api/purchasing/requests/$id');

  Future<dynamic> uploadAttachment({
    required int requestId,
    required int detailId,
    required List<int> bytes,
    required String fileName,
  }) =>
      throw UnsupportedError(
        'Configure PurchasingUpload in the feature host to upload attachments.',
      );
}
