import 'package:laoo_shared_core/laoo_shared_core.dart';

class TimeReasonRepository {
  TimeReasonRepository(this.api, this.path);

  final JsonApiClient api;
  final String path;

  Future<Map<String, dynamic>> actions() async =>
      Map<String, dynamic>.from(await api.get('$path/actions') as Map);

  Future<Map<String, dynamic>> list({
    String? search,
    bool? active,
    int page = 1,
    int pageSize = 30,
  }) async => Map<String, dynamic>.from(
    await api.get(
          path,
          query: {
            'page': '$page',
            'pageSize': '$pageSize',
            if (search?.trim().isNotEmpty == true) 'search': search!.trim(),
            if (active != null) 'isActive': '$active',
          },
        )
        as Map,
  );

  Future<void> save(Map<String, dynamic> value) async {
    final id = value['id'] as int?;
    if (id == null) {
      await api.post(path, body: value);
    } else {
      await api.put('$path/$id', body: value);
    }
  }

  Future<void> delete(int id, String rowVersion) =>
      api.delete('$path/$id', query: {'rowVersion': rowVersion});
}
