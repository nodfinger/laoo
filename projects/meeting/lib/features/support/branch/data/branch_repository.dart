import '../../../../core/api/api_client.dart';

class BranchRepository {
  BranchRepository({ApiClient? api}) : _api = api ?? ApiClient();
  final ApiClient _api;

  Future<Map<String, bool>> actions({bool support = true, bool company = false}) async {
    final data = await _api.get(
      '${company ? '/api/company/branches' : support ? '/api/support/branches' : '/api/partner/branches'}/actions',
    );
    if (data is! Map) return const {};
    return Map<String, bool>.fromEntries(
      data.entries.map((entry) => MapEntry('${entry.key}', entry.value == true)),
    );
  }
  Future<List<Map<String, dynamic>>> get({
    String? search,
    int? companyId,
    bool support = true,
    bool company = false,
  }) async => List<Map<String, dynamic>>.from(
    await _api.get(
          company ? '/api/company/branches' : support ? '/api/support/branches' : '/api/partner/branches',
          query: {
            'search': search ?? '',
            if (companyId != null) 'companyId': '$companyId',
          },
        )
        as List,
  );
  Future<void> create(Map<String, dynamic> data, {bool support = true, bool company = false}) async {
    await _api.post(
      company ? '/api/company/branches' : support ? '/api/support/branches' : '/api/partner/branches',
      body: data,
    );
  }

  Future<void> update(
    int id,
    Map<String, dynamic> data, {
    bool support = true,
    bool company = false,
  }) async {
    await _api.put(
      '${company ? '/api/company/branches' : support ? '/api/support/branches' : '/api/partner/branches'}/$id',
      body: data,
    );
  }

  Future<void> delete(int id, {bool support = true, bool company = false}) async {
    await _api.delete(
      '${company ? '/api/company/branches' : support ? '/api/support/branches' : '/api/partner/branches'}/$id',
    );
  }
}
