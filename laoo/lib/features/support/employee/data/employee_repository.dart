import '../../../../core/api/api_client.dart';

class EmployeeRepository {
  EmployeeRepository({ApiClient? api}) : _api = api ?? ApiClient();
  final ApiClient _api;

  Future<Map<String, dynamic>> list({String? search, int? divisionId, int? departmentId, int? companyId, bool customer = false, bool company = false, int page = 1, int pageSize = 20}) async =>
      Map<String, dynamic>.from(await _api.get(company ? '/api/company/employees' : customer ? '/api/partner/customer-employees' : '/api/partner/employees', query: {
        'search': search ?? '',
        if (divisionId != null) 'divisionId': '$divisionId',
        if (departmentId != null) 'departmentId': '$departmentId',
        if (companyId != null) 'companyId': '$companyId',
        'page': '$page',
        'pageSize': '$pageSize',
      }) as Map);

  Future<void> create(Map<String, dynamic> body, {bool customer = false, bool company = false}) async => _api.post(company ? '/api/company/employees' : customer ? '/api/partner/customer-employees' : '/api/partner/employees', body: body);
  Future<void> update(int id, Map<String, dynamic> body, {bool customer = false, bool company = false}) async => _api.put('${company ? '/api/company/employees' : customer ? '/api/partner/customer-employees' : '/api/partner/employees'}/$id', body: body);
  Future<void> delete(int id, {int? companyId, bool customer = false, bool company = false}) async => _api.delete('${company ? '/api/company/employees' : customer ? '/api/partner/customer-employees' : '/api/partner/employees'}/$id', query: {
    if (companyId != null) 'companyId': '$companyId',
  });
}
