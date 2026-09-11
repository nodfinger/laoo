import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'rotation_pattern_models.dart';

class RotationPatternRepository {
  RotationPatternRepository(this.api);
  final JsonApiClient api;
  static const path = '/api/time/rotation-patterns';
  Future<RotationActions> actions() async => RotationActions.fromJson(
    Map<String, dynamic>.from(await api.get('$path/actions') as Map),
  );
  Future<List<ShiftOption>> shifts() async =>
      (await api.get('$path/shift-options') as List)
          .whereType<Map>()
          .map((x) => ShiftOption.fromJson(Map<String, dynamic>.from(x)))
          .toList();
  Future<RotationResult> list({int page = 1, int pageSize = 30}) async =>
      RotationResult.fromJson(
        Map<String, dynamic>.from(
          await api.get(
                path,
                query: {
                  'page': '$page',
                  'pageSize': '$pageSize',
                  'isActive': 'true',
                },
              )
              as Map,
        ),
      );
  Future<RotationPattern> get(int id) async => RotationPattern.fromJson(
    Map<String, dynamic>.from(await api.get('$path/$id') as Map),
  );
  Future<void> save(RotationPattern x) async {
    x.id == null
        ? await api.post(path, body: x.toJson())
        : await api.put('$path/${x.id}', body: x.toJson());
  }

  Future<void> delete(RotationPattern x) =>
      api.delete('$path/${x.id}', query: {'rowVersion': x.rowVersion ?? ''});
}
