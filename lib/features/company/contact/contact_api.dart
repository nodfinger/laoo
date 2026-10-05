import 'dart:typed_data';
import '../../../core/api/api_client.dart';

class ContactApi {
  ContactApi({ApiClient? client}) : _client = client ?? ApiClient();
  final ApiClient _client;
  Future<Map<String, dynamic>> actions() async => Map<String, dynamic>.from(
    await _client.get('/api/company/contacts/actions') as Map,
  );
  Future<Map<String, dynamic>> list({
    required String search,
    required int page,
    int pageSize = 20,
  }) async => Map<String, dynamic>.from(
    await _client.get(
          '/api/company/contacts',
          query: {
            'search': search,
            'page': page.toString(),
            'pageSize': pageSize.toString(),
          },
        )
        as Map,
  );
  Future<Map<String, dynamic>> lookups({
    String search = '',
    int? personId,
    int? customerId,
  }) async => Map<String, dynamic>.from(
    await _client.get(
          '/api/company/contacts/lookups',
          query: {
            'search': search,
            if (personId != null) 'personId': personId.toString(),
            if (customerId != null) 'customerId': customerId.toString(),
          },
        )
        as Map,
  );
  Future<Map<String, dynamic>> save(
    Map<String, dynamic> body, {
    int? id,
  }) async => Map<String, dynamic>.from(
    (id == null
            ? await _client.post('/api/company/contacts', body: body)
            : await _client.put('/api/company/contacts/$id', body: body))
        as Map,
  );
  Future<void> delete(int id, String rowVersion) => _client.delete(
    '/api/company/contacts/$id',
    query: {'rowVersion': rowVersion},
  );
  Future<void> upload(int id, BusinessCardImageValue image) => _client.upload(
    '/api/company/contacts/$id/files',
    fileName: image.name,
    bytes: image.bytes,
  );
  void dispose() => _client.dispose();
}

class BusinessCardImageValue {
  const BusinessCardImageValue(this.bytes, this.name);
  final Uint8List bytes;
  final String name;
}
