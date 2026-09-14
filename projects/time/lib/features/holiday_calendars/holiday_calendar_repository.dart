import 'package:laoo_shared_core/laoo_shared_core.dart';

class HolidayCalendarRepository {
  HolidayCalendarRepository(this.api);
  final JsonApiClient api;
  static const path = '/api/time/holiday-calendars';

  Future<Map<String, dynamic>> actions() async =>
      Map<String, dynamic>.from(await api.get('$path/actions') as Map);

  Future<Map<String, dynamic>> list({
    required String search,
    required bool? active,
    required int page,
  }) async => Map<String, dynamic>.from(
    await api.get(
          path,
          query: {
            if (search.trim().isNotEmpty) 'search': search.trim(),
            if (active != null) 'isActive': '$active',
            'page': '$page',
            'pageSize': '30',
          },
        )
        as Map,
  );

  Future<void> save(Map<String, dynamic> value) async {
    final id = value['holidayCalendarId'];
    if (id == null) {
      await api.post(path, body: value);
    } else {
      await api.put('$path/$id', body: value);
    }
  }

  Future<void> delete(int id, String rowVersion) =>
      api.delete('$path/$id', query: {'rowVersion': rowVersion});
}
