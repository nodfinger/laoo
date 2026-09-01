import '../../../core/api/api_client.dart';
import '../models/partner_company.dart';

class PartnerCompanyRepository {
  PartnerCompanyRepository({ApiClient? apiClient})
    : _api = apiClient ?? ApiClient();
  final ApiClient _api;

  Future<Map<String, bool>> actions({bool support = false}) async {
    final data = await _api.get(
      support
          ? '/api/support/companies/actions'
          : '/api/partner/companies/actions',
    );
    if (data is! Map) return const {};
    return Map<String, bool>.fromEntries(
      data.entries.map(
        (entry) => MapEntry('${entry.key}', entry.value == true),
      ),
    );
  }

  Future<List<PartnerCompany>> getCompanies({
    String? search,
    int? partnerId,
    bool support = false,
  }) async {
    final data = await _api.get(
      support ? '/api/support/companies' : '/api/partner/companies',
      query:
          {
            if (search != null && search.trim().isNotEmpty)
              'search': search.trim(),
            if (partnerId != null) 'partnerId': '$partnerId',
          }.isEmpty
          ? null
          : {
              if (search != null && search.trim().isNotEmpty)
                'search': search.trim(),
              if (partnerId != null) 'partnerId': '$partnerId',
            },
    );
    return (data as List<dynamic>)
        .map((e) => PartnerCompany.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<PartnerCompany> createCompany(PartnerCompanyInput input) async =>
      PartnerCompany.fromJson(
        await _api.post('/api/partner/companies', body: input.toJson())
            as Map<String, dynamic>,
      );

  Future<void> updateCompany(
    int companyId,
    PartnerCompanyInput input, {
    bool support = false,
  }) async {
    final path = support
        ? '/api/support/companies/$companyId'
        : '/api/partner/companies/$companyId';
    await _api.put(path, body: input.toJson());
  }

  Future<void> deleteCompany(int companyId, {bool support = false}) async {
    final path = support
        ? '/api/support/companies/$companyId'
        : '/api/partner/companies/$companyId';
    await _api.delete(path);
  }

  Future<void> updateAdmin(
    int companyId,
    String username,
    String password,
  ) async {
    await _api.put(
      '/api/partner/companies/$companyId/admin',
      body: {'username': username, 'password': password},
    );
  }

  Future<List<PartnerCompanyFeature>> getCompanyFeatures(int companyId) async {
    final data = await _api.get('/api/partner/companies/$companyId/features');
    return (data as List<dynamic>)
        .map(
          (item) => PartnerCompanyFeature.fromJson(
            item as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  Future<void> updateCompanyFeatures(
    int companyId,
    Map<String, bool> features,
  ) async {
    await _api.put(
      '/api/partner/companies/$companyId/features',
      body: {
        'features': features.entries
            .map(
              (entry) => {
                'featureCode': entry.key,
                'isEnabled': entry.value,
              },
            )
            .toList(),
      },
    );
  }
}
