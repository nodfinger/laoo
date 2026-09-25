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
  Future<Map<String, dynamic>> planAssets(int id) async =>
      _object(await _client.get('/api/service/pm/plans/$id/assets'));
  Future<void> setPlanAssets(int id, List<int> ids) =>
      _client.put('/api/service/pm/plans/$id/assets', body: {'ids': ids});
  Future<Map<String, dynamic>> planChecklists(int id) async =>
      _object(await _client.get('/api/service/pm/plans/$id/checklists'));
  Future<void> setPlanChecklists(int id, List<int> ids) =>
      _client.put('/api/service/pm/plans/$id/checklists', body: {'ids': ids});
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
  Future<Map<String, dynamic>> workOrders({
    String status = '',
    DateTime? from,
    DateTime? to,
  }) async {
    final query = <String, String>{'status': status};
    if (from != null) query['from'] = from.toIso8601String().substring(0, 10);
    if (to != null) query['to'] = to.toIso8601String().substring(0, 10);
    return _object(
      await _client.get(
        '/api/service/pm/work-orders?${Uri(queryParameters: query).query}',
      ),
    );
  }

  Future<Map<String, dynamic>> workOrder(int id) async =>
      _object(await _client.get('/api/service/pm/work-orders/$id'));
  Future<void> saveChecks(int id, List<Map<String, dynamic>> items) => _client
      .put('/api/service/pm/work-orders/$id/checks', body: {'items': items});
  Future<void> generate() =>
      _client.post('/api/service/pm/work-orders/generate', body: {});
  Future<void> action(int id, String action, [String? detail]) => _client.post(
    '/api/service/pm/work-orders/$id/$action',
    body: detail == null ? {} : {'resultDetail': detail},
  );
  Map<String, dynamic> _object(dynamic value) =>
      Map<String, dynamic>.from(value as Map);
}
