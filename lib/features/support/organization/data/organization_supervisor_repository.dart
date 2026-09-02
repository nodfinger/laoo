import '../../../../core/api/api_client.dart';

class OrganizationSupervisorRepository {
  OrganizationSupervisorRepository({ApiClient? api})
    : _api = api ?? ApiClient();
  final ApiClient _api;

  Future<List<Map<String, dynamic>>> list() async =>
      List<Map<String, dynamic>>.from(
        await _api.get('/api/company/organization-supervisors') as List,
      );

  Future<void> save(int orgUnitId, int employeeId, String supervisorType) =>
      _api.put(
        '/api/company/organization-supervisors/$orgUnitId',
        body: {'employeeId': employeeId, 'supervisorType': supervisorType},
      );
}
