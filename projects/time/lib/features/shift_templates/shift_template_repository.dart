import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'shift_template_models.dart';

class ShiftTemplateRepository {
  ShiftTemplateRepository(this.api);
  final JsonApiClient api;
  static const path = '/api/time/shift-templates';
  Future<ShiftActions> actions() async => ShiftActions.fromJson(
    Map<String, dynamic>.from(await api.get('$path/actions') as Map),
  );
  Future<ShiftPageResult> list({
    String? search,
    bool? active,
    int page = 1,
    int pageSize = 30,
  }) async => ShiftPageResult.fromJson(
    Map<String, dynamic>.from(
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
    ),
  );
  Future<ShiftDetail> get(int id) async => ShiftDetail.fromJson(
    Map<String, dynamic>.from(await api.get('$path/$id') as Map),
  );
  Future<void> save(ShiftDetail value) async {
    if (value.id == null) {
      await api.post(path, body: value.toJson());
    } else {
      await api.put('$path/${value.id}', body: value.toJson());
    }
  }

  Future<void> delete(ShiftSummary value) async =>
      api.delete('$path/${value.id}', query: {'rowVersion': value.rowVersion});
}
