import 'package:laoo_shared_core/laoo_shared_core.dart';

class PayrollExportRepository {
  PayrollExportRepository(this.api);
  final JsonApiClient api;
  static const path = '/api/time/payroll-exports';

  Future<Map<String, dynamic>> actions(String menuCode) async =>
      Map<String, dynamic>.from(await api.get('$path/actions', query: {'menuCode': menuCode}) as Map);
  Future<List<Map<String, dynamic>>> profiles() async => _items(await api.get('$path/profiles'));
  Future<List<Map<String, dynamic>>> periods() async => _items(await api.get('$path/periods'));
  Future<List<Map<String, dynamic>>> history() async => _items(await api.get('$path/history', query: {'page': '1', 'pageSize': '100'}));
  Future<void> saveProfile(Map<String, dynamic> value) async {
    final id = value['profileId'];
    if (id == null) return api.post('$path/profiles', body: value);
    return api.put('$path/profiles/$id', body: value);
  }
  Future<void> deleteProfile(Map<String, dynamic> value) => api.delete('$path/profiles/${value['profileId']}', query: {'rowVersion': '${value['rowVersion']}'});
  Future<Map<String, dynamic>> generate(int periodId, int profileId) async => Map<String, dynamic>.from(await api.post('$path/generate', body: {'attendancePeriodId': periodId, 'profileId': profileId}) as Map);
  static List<Map<String, dynamic>> _items(dynamic value) { final map = Map<String, dynamic>.from(value as Map); return (map['items'] as List? ?? const []).map((x) => Map<String, dynamic>.from(x as Map)).toList(growable: false); }
}
