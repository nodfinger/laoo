import 'package:flutter_test/flutter_test.dart';
import 'package:laoo_service/core/api/api_client.dart';
import 'package:laoo_service/features/service_request/data/service_request_api.dart';

void main() {
  test('self-service mutations use owner-scoped endpoints', () async {
    final client = _RecordingClient();
    final api = ServiceRequestApi(client: client);

    await api.edit(
      42,
      selfService: true,
      subject: 'ไฟไม่ติด',
      detail: 'ห้อง 101',
      rowVersion: 'version',
    );
    expect(client.path, '/api/service/requests/self/42');
    expect(client.body, {
      'subject': 'ไฟไม่ติด',
      'detail': 'ห้อง 101',
      'rowVersion': 'version',
    });

    await api.delete(42, 'version', selfService: true);
    expect(client.path, '/api/service/requests/self/42');
    expect(client.query, {'rowVersion': 'version'});
  });

  test('staff mutations retain staff endpoints', () async {
    final client = _RecordingClient();
    final api = ServiceRequestApi(client: client);

    await api.edit(
      42,
      selfService: false,
      subject: 'ไฟไม่ติด',
      detail: 'ห้อง 101',
      rowVersion: 'version',
    );
    expect(client.path, '/api/service/requests/42');
    await api.delete(42, 'version', selfService: false);
    expect(client.path, '/api/service/requests/42');
  });

  test('self lookup requests owner-scoped choices', () async {
    final client = _RecordingClient();
    final api = ServiceRequestApi(client: client);
    await api.lookup(selfService: true);
    expect(client.path, '/api/service/requests/lookup');
    expect(client.query, {'search': '', 'self': 'true'});
    await api.lookup();
    expect(client.query, {'search': '', 'self': 'false'});
  });

  test(
    'list and detail send menu scope for backend permission checks',
    () async {
      final client = _RecordingClient();
      final api = ServiceRequestApi(client: client);
      await api.list(menuCode: '17001');
      expect(client.query?['menuCode'], '17001');
      await api.detail(42, menuCode: '20002');
      expect(client.query, {'menuCode': '20002'});
    },
  );
}

class _RecordingClient extends ApiClient {
  String? path;
  Object? body;
  Map<String, String>? query;

  @override
  Future<dynamic> get(
    String path, {
    Map<String, String>? query,
    bool authenticated = true,
  }) async {
    this.path = path;
    this.query = query;
    return {'items': [], 'total': 0};
  }

  @override
  Future<dynamic> put(
    String path, {
    Object? body,
    bool authenticated = true,
  }) async {
    this.path = path;
    this.body = body;
  }

  @override
  Future<dynamic> delete(
    String path, {
    Object? body,
    Map<String, String>? query,
    bool authenticated = true,
  }) async {
    this.path = path;
    this.query = query;
  }
}
