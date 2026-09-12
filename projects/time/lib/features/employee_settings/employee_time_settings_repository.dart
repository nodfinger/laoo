import 'package:laoo_shared_core/laoo_shared_core.dart';

import 'employee_time_settings_models.dart';

class EmployeeTimeSettingsRepository {
  EmployeeTimeSettingsRepository(this.api);

  static const path = '/api/time/employee-settings';
  final JsonApiClient api;

  Future<EmployeeTimeActions> actions() async {
    final json = await api.get('$path/actions');
    return EmployeeTimeActions.fromJson(Map<String, dynamic>.from(json as Map));
  }

  Future<EmployeeTimeSettingsResult> list({
    String? search,
    bool? isActive,
    bool? requiresAttendance,
    int? divisionOrgUnitId,
    int? departmentOrgUnitId,
    int page = 1,
    int pageSize = 30,
  }) async {
    final query = <String, String>{
      'page': '$page',
      'pageSize': '$pageSize',
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      if (isActive != null) 'isActive': '$isActive',
      if (requiresAttendance != null)
        'requirementCode': requiresAttendance ? 'REQUIRED' : 'EXEMPT',
      if (divisionOrgUnitId != null) 'divisionOrgUnitId': '$divisionOrgUnitId',
      if (departmentOrgUnitId != null)
        'departmentOrgUnitId': '$departmentOrgUnitId',
    };
    final json = await api.get(path, query: query);
    return EmployeeTimeSettingsResult.fromJson(
      Map<String, dynamic>.from(json as Map),
    );
  }

  Future<EmployeeOrganizationFilterOptions> organizationFilters() async {
    final json = await api.get('$path/organization-filters');
    return EmployeeOrganizationFilterOptions.fromJson(
      Map<String, dynamic>.from(json as Map),
    );
  }

  Future<void> update(
    int employeeId,
    EmployeeTimeSettingsUpdate request,
  ) async {
    await api.put('$path/$employeeId', body: request.toJson());
  }
}
