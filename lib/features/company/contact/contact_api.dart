import 'dart:typed_data';
import 'dart:convert';
import '../../../core/api/api_client.dart';

class ContactApi {
  ContactApi({ApiClient? client, this.supplier = false})
    : _client = client ?? ApiClient();
  final ApiClient _client;
  final bool supplier;
  String get _base =>
      supplier ? '/api/company/supplier-contacts' : '/api/company/contacts';
  Future<Map<String, dynamic>> reviewQueue(String search) async =>
      Map<String, dynamic>.from(
        await _client.get('$_base/ocr-review-queue', query: {'search': search})
            as Map,
      );
  Future<void> completeReview(int id) async {
    await _client.post(
      '$_base/ocr-review-queue/$id/complete',
      body: <String, dynamic>{},
    );
  }

  Future<void> saveDraft(
    Map<String, dynamic> contact,
    List<BusinessCardImageValue> images,
  ) async {
    await _client.post(
      '$_base/ocr-drafts',
      body: {
        'contact': contact,
        'images': [
          for (final image in images)
            {'name': image.name, 'data': base64Encode(image.bytes)},
        ],
      },
    );
  }

  Future<void> sendDraft(int id) async =>
      _client.post('$_base/ocr-drafts/$id/send', body: <String, dynamic>{});
  Future<void> deleteDraft(int id) async =>
      _client.delete('$_base/ocr-drafts/$id');
  Future<Map<String, dynamic>> draftDetails(int id) async =>
      Map<String, dynamic>.from(
        await _client.get('$_base/ocr-drafts/$id') as Map,
      );

  Future<Map<String, dynamic>> actions() async =>
      Map<String, dynamic>.from(await _client.get('$_base/actions') as Map);
  Future<Map<String, dynamic>> list({
    required String search,
    required int page,
    int pageSize = 20,
  }) async => Map<String, dynamic>.from(
    await _client.get(
          '$_base',
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
          '$_base/lookups',
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
            ? await _client.post('$_base', body: body)
            : await _client.put('$_base/$id', body: body))
        as Map,
  );
  Future<void> delete(int id, String rowVersion) =>
      _client.delete('$_base/$id', query: {'rowVersion': rowVersion});
  Future<void> upload(int id, BusinessCardImageValue image) => _client.upload(
    '$_base/$id/files',
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
