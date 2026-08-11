import '../../../../core/api/api_client.dart';

class BranchRepository {
  BranchRepository({ApiClient? api}) : _api = api ?? ApiClient();
  final ApiClient _api;
  Future<List<Map<String, dynamic>>> get({
    String? search,
    int? companyId,
    bool support = true,
  }) async => List<Map<String, dynamic>>.from(
    await _api.get(
          support ? '/api/support/branches' : '/api/partner/branches',
          query: {
            'search': search ?? '',
            if (companyId != null) 'companyId': '$companyId',
          },
        )
        as List,
  );
  Future<void> create(Map<String, dynamic> data, {bool support = true}) async {
    await _api.post(
      support ? '/api/support/branches' : '/api/partner/branches',
      body: data,
    );
  }

  Future<void> update(
    int id,
    Map<String, dynamic> data, {
    bool support = true,
  }) async {
    await _api.put(
      '${support ? '/api/support/branches' : '/api/partner/branches'}/$id',
      body: data,
    );
  }

  Future<void> delete(int id, {bool support = true}) async {
    await _api.delete(
      '${support ? '/api/support/branches' : '/api/partner/branches'}/$id',
    );
  }
}
