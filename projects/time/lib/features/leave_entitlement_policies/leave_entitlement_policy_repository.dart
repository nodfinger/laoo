import 'package:laoo_shared_core/laoo_shared_core.dart';

class LeaveEntitlementPolicyRepository {
  LeaveEntitlementPolicyRepository(this.api);
  final JsonApiClient api;
  static const _path = '/api/time/leave-entitlement-policies';
  Future<Map<String, dynamic>> actions() async =>
      Map<String, dynamic>.from(await api.get('$_path/actions') as Map);
  Future<List<Map<String, dynamic>>> leaveTypes() async {
    final value = Map<String, dynamic>.from(
      await api.get('$_path/leave-types') as Map,
    );
    return (value['items'] as List? ?? [])
        .map((x) => Map<String, dynamic>.from(x as Map))
        .toList();
  }

  Future<Map<String, dynamic>> list({
    int? leaveTypeId,
    bool? active,
    int page = 1,
    int pageSize = 30,
  }) async => Map<String, dynamic>.from(
    await api.get(
          _path,
          query: {
            'page': '$page',
            'pageSize': '$pageSize',
            if (leaveTypeId != null) 'leaveTypeId': '$leaveTypeId',
            if (active != null) 'isActive': '$active',
          },
        )
        as Map,
  );
  Future<void> save(Map<String, dynamic> item) async {
    final id = item['id'] as int?;
    if (id == null) {
      await api.post(_path, body: item);
    } else {
      await api.put('$_path/$id', body: item);
    }
  }
}
