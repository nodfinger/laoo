import 'package:laoo_shared_core/laoo_shared_core.dart';

class PosApi {
  PosApi(this.client);
  final JsonApiClient client;

  Future<Map<String, dynamic>> actions(String menu) async =>
      _map(await client.get('/api/company/pos/actions/$menu'));
  Future<Map<String, dynamic>> settings() async =>
      _map(await client.get('/api/company/pos/settings'));
  Future<void> saveSettings(Map<String, dynamic> body) =>
      client.put('/api/company/pos/settings', body: body);
  Future<Map<String, dynamic>> options() async =>
      _map(await client.get('/api/company/pos/options'));
  Future<List<Map<String, dynamic>>> list(String endpoint) async =>
      _list(await client.get('/api/company/pos/$endpoint'));
  Future<Map<String, dynamic>> bootstrap(String activationId) async =>
      _map(await client.get('/api/company/pos/bootstrap/$activationId'));
  Future<List<Map<String, dynamic>>> products(
    String activationId, {
    String? search,
  }) async => _list(
    await client.get(
      '/api/company/pos/products/$activationId',
      query: {if (search != null && search.trim().isNotEmpty) 'search': search},
    ),
  );
  Future<Map<String, dynamic>> create(String endpoint, Object body) async =>
      _map(await client.post('/api/company/pos/$endpoint', body: body));
  Future<Map<String, dynamic>> update(
    String endpoint,
    Object id,
    Object body,
  ) async =>
      _map(await client.put('/api/company/pos/$endpoint/$id', body: body));
  Future<void> remove(String endpoint, Object id) =>
      client.delete('/api/company/pos/$endpoint/$id');
  Future<void> action(String path, {Object? body}) =>
      client.post('/api/company/pos/$path', body: body);
  Future<Map<String, dynamic>> finalize(Map<String, dynamic> body) async =>
      _map(await client.post('/api/company/pos/sales/finalize', body: body));
  Future<Map<String, dynamic>> sale(Object id) async =>
      _map(await client.get('/api/company/pos/sales/$id'));
  Future<Map<String, dynamic>> report() async =>
      _map(await client.get('/api/company/pos/reports'));

  static Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
  static List<Map<String, dynamic>> _list(dynamic value) => value is List
      ? value.whereType<Map>().map(Map<String, dynamic>.from).toList()
      : <Map<String, dynamic>>[];
}
