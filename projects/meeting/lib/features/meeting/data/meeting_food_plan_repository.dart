import '../../../../core/api/api_client.dart';

class MeetingFoodPlanRepository {
  MeetingFoodPlanRepository({ApiClient? api}) : _api = api ?? ApiClient();
  final ApiClient _api;
  static const _path = '/api/company/meeting-food-plans';

  Future<Map<String, dynamic>> list({String? search, int page = 1}) async =>
      Map<String, dynamic>.from(
        await _api.get(
              _path,
              query: {
                'page': '$page',
                'pageSize': '20',
                if (search != null && search.trim().isNotEmpty)
                  'search': search.trim(),
              },
            )
            as Map,
      );

  Future<Map<String, dynamic>> get(int bookingId) async =>
      Map<String, dynamic>.from(await _api.get('$_path/$bookingId') as Map);

  Future<Map<String, bool>> actions() async => Map<String, bool>.fromEntries(
    (await _api.get('$_path/actions') as Map).entries.map(
      (entry) => MapEntry('${entry.key}', entry.value == true),
    ),
  );

  Future<void> save(
    int bookingId, {
    required DateTime cutoff,
    required Set<int> foodIds,
    required bool isActive,
  }) => _api.put(
    '$_path/$bookingId',
    body: {
      'orderCutoffDateTime': cutoff.toIso8601String(),
      'foodIds': foodIds.toList()..sort(),
      'isActive': isActive,
    },
  );

  Future<void> delete(int bookingId) => _api.delete('$_path/$bookingId');
}
