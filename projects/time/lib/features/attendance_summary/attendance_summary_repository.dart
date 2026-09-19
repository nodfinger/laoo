import 'package:laoo_shared_core/laoo_shared_core.dart';

class AttendanceSummaryRepository {
  AttendanceSummaryRepository(this.api);

  final JsonApiClient api;
  static const _path = '/api/time/attendance/summary';

  Future<Map<String, dynamic>> actions() async => Map<String, dynamic>.from(
    await api.get('$_path/actions') as Map,
  );

  Future<Map<String, dynamic>> list({
    required DateTime fromWorkDate,
    required DateTime toWorkDate,
    String? employee,
    int? branchId,
    int? divisionOrgUnitId,
    int? departmentOrgUnitId,
    int page = 1,
    int pageSize = 30,
  }) async {
    final value = Map<String, dynamic>.from(
      await api.get(
            _path,
            query: {
              'fromWorkDate': _date(fromWorkDate),
              'toWorkDate': _date(toWorkDate),
              if (employee?.trim().isNotEmpty == true) 'employee': employee!.trim(),
              if (branchId != null) 'branchId': '$branchId',
              if (divisionOrgUnitId != null)
                'divisionOrgUnitId': '$divisionOrgUnitId',
              if (departmentOrgUnitId != null)
                'departmentOrgUnitId': '$departmentOrgUnitId',
              'page': '$page',
              'pageSize': '$pageSize',
            },
          )
          as Map,
    );
    return (value['items'] as List? ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> organizationUnits() async {
    final value = Map<String, dynamic>.from(
      await api.get('$_path/organization-units') as Map,
    );
    return (value['items'] as List? ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> branches() async {
    final value = Map<String, dynamic>.from(
      await api.get('$_path/branches') as Map,
    );
    return <String, dynamic>{
      'total': (value['total'] as num?)?.toInt() ?? 0,
      'page': (value['page'] as num?)?.toInt() ?? page,
      'pageSize': (value['pageSize'] as num?)?.toInt() ?? pageSize,
      'items': (value['items'] as List? ?? const [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList(growable: false),
    };
  }

  static String _date(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}
