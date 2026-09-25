import '../../../core/api/api_client.dart';

class PmApi {
  final _client = ApiClient();
  Future<Map<String, dynamic>> get plans async =>
      _object(await _client.get('/api/service/pm/plans'));
  Future<Map<String, dynamic>> get types async =>
      _object(await _client.get('/api/service/pm/item-types'));
  Future<Map<String, dynamic>> assets(String type) async => _object(
    await _client.get(
      '/api/service/pm/assets?itemTypeCode=${Uri.encodeQueryComponent(type)}',
    ),
  );
  Future<void> savePlan(Map<String, dynamic> body, {int? id}) async {
    if (id == null) {
      await _client.post('/api/service/pm/plans', body: body);
    } else {
      await _client.put('/api/service/pm/plans/$id', body: body);
    }
  }

  Future<Map<String, dynamic>> get checklists async =>
      _object(await _client.get('/api/service/pm/checklists'));
  Future<void> createChecklist(Map<String, dynamic> body) =>
      _client.post('/api/service/pm/checklists', body: body);
  Future<Map<String, dynamic>> workOrders(String status) async =>
      _object(await _client.get('/api/service/pm/work-orders?status=$status'));
  Future<void> generate() =>
      _client.post('/api/service/pm/work-orders/generate', body: {});
  Future<void> action(int id, String action, [String? detail]) => _client.post(
    '/api/service/pm/work-orders/$id/$action',
    body: detail == null ? {} : {'resultDetail': detail},
  );
  Map<String, dynamic> _object(dynamic value) =>
      Map<String, dynamic>.from(value as Map);
}
