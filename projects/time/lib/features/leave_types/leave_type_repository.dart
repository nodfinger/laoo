import 'package:laoo_shared_core/laoo_shared_core.dart';

class LeaveTypeRepository {
  LeaveTypeRepository(this.api);
  final JsonApiClient api;
  static const _path = '/api/time/leave-types';
  Future<Map<String, dynamic>> actions() async =>
      Map<String, dynamic>.from(await api.get('$_path/actions') as Map);
  Future<Map<String, dynamic>> list({
    String? search,
    bool? active,
    int page = 1,
    int pageSize = 30,
  }) async => Map<String, dynamic>.from(
    await api.get(
          _path,
          query: {
            'page': '$page',
            'pageSize': '$pageSize',
            if (search?.trim().isNotEmpty == true) 'search': search!.trim(),
            if (active != null) 'isActive': '$active',
          },
        )
        as Map,
  );
  Future<void> save(Map<String, dynamic> item) async {
    final id = item['id'] as int?;
    if (id == null) return api.post(_path, body: item);
    return api.put('$_path/$id', body: item);
  }

  Future<void> delete(int id, String rowVersion) =>
      api.delete('$_path/$id', query: {'rowVersion': rowVersion});
}
