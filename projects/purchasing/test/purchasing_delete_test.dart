import 'package:flutter_test/flutter_test.dart';
import 'package:laoo_purchasing/features/purchasing/purchasing_request_repository.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';

class _Api implements JsonApiClient {
  String? deletedPath;
  @override
  Future<dynamic> delete(
    String path, {
    Object? body,
    Map<String, String>? query,
    bool authenticated = true,
  }) async {
    deletedPath = path;
    return {'attachmentCleanupFailed': true};
  }

  @override
  Future<dynamic> get(
    String path, {
    Map<String, String>? query,
    bool authenticated = true,
  }) => throw UnimplementedError();
  @override
  Future<dynamic> post(
    String path, {
    Object? body,
    bool authenticated = true,
  }) => throw UnimplementedError();
  @override
  Future<dynamic> put(String path, {Object? body, bool authenticated = true}) =>
      throw UnimplementedError();
}

void main() {
  test('delete returns the attachment cleanup warning', () async {
    final api = _Api();
    final result = await PurchasingRequestRepository(api).delete(42);
    expect(api.deletedPath, '/api/purchasing/requests/42');
    expect(result['attachmentCleanupFailed'], isTrue);
  });
}
