import '../../../core/api/api_client.dart';
import '../models/partner_company.dart';

class PartnerCompanyRepository {
  PartnerCompanyRepository({ApiClient? apiClient}) : _api = apiClient ?? ApiClient();
  final ApiClient _api;
  Future<List<PartnerCompany>> getCompanies({String? search, bool support = false}) async {
    final data = await _api.get(support ? '/api/support/companies' : '/api/partner/companies', query: search == null || search.trim().isEmpty ? null : {'search': search.trim()});
    return (data as List<dynamic>).map((e) => PartnerCompany.fromJson(e as Map<String, dynamic>)).toList();
  }
  Future<PartnerCompany> createCompany(PartnerCompanyInput input) async => PartnerCompany.fromJson(await _api.post('/api/partner/companies', body: input.toJson()) as Map<String, dynamic>);

  Future<void> updateCompany(int companyId, PartnerCompanyInput input) async {
    await _api.put('/api/partner/companies/$companyId', body: input.toJson());
  }

  Future<void> deleteCompany(int companyId) async {
    await _api.delete('/api/partner/companies/$companyId');
  }
}
