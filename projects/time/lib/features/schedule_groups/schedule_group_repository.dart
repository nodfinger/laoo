import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'schedule_group_models.dart';

class ScheduleGroupRepository {
  ScheduleGroupRepository(this.api);
  final JsonApiClient api;
  static const path = '/api/time/schedule-groups';
  Future<ScheduleGroupActions> actions() async => ScheduleGroupActions.fromJson(
    Map<String, dynamic>.from(await api.get('$path/actions') as Map),
  );
  Future<ScheduleGroupResult> list({
    String? search,
    bool? active,
    int page = 1,
    int pageSize = 30,
  }) async => ScheduleGroupResult.fromJson(
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
  Future<void> save(ScheduleGroup x) async {
    x.id == null
        ? await api.post(path, body: x.toJson())
        : await api.put('$path/${x.id}', body: x.toJson());
  }

  Future<void> delete(ScheduleGroup x) =>
      api.delete('$path/${x.id}', query: {'rowVersion': x.rowVersion ?? ''});
}
