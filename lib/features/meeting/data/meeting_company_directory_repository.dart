import '../../../core/api/api_client.dart';

class MeetingBranchDirectoryRepository {
  MeetingBranchDirectoryRepository({ApiClient? api})
    : _api = api ?? ApiClient();
  final ApiClient _api;

  Future<List<Map<String, dynamic>>> get({String? search}) async {
    final data = await _api.get(
      '/api/company/branches',
      query: {'search': search ?? ''},
    );
    return List<Map<String, dynamic>>.from(data as List);
  }
}

class MeetingEmployeeDirectoryRepository {
  MeetingEmployeeDirectoryRepository({ApiClient? api})
    : _api = api ?? ApiClient();
  final ApiClient _api;

  Future<Map<String, dynamic>> list({
    bool? isActive,
    int page = 1,
    int pageSize = 100,
  }) async {
    final data = await _api.get(
      '/api/company/employees',
      query: {
        if (isActive != null) 'isActive': isActive ? 'true' : 'false',
        'page': '$page',
        'pageSize': '$pageSize',
      },
    );
    return Map<String, dynamic>.from(data as Map);
  }
}

class MeetingOrganizationDirectoryRepository {
  MeetingOrganizationDirectoryRepository({ApiClient? api})
    : _api = api ?? ApiClient();
  final ApiClient _api;

  Future<Map<String, dynamic>> load() async {
    final data = await _api.get('/api/company/organization-structure');
    return Map<String, dynamic>.from(data as Map);
  }
}
