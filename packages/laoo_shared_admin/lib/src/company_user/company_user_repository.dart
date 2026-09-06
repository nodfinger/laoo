import 'package:laoo_shared_core/laoo_shared_core.dart';

import 'company_user_models.dart';
import 'company_user_screen_contracts.dart';

class CompanyUserRepository {
  CompanyUserRepository(this._api);

  final JsonApiClient _api;

  ScreenContract get contract => CompanyUserScreenContracts.partner;

  Future<Map<String, bool>> actions() async {
    final data = await _api.get('${contract.apiPath}/actions');
    if (data is! Map) return const {};
    return Map<String, bool>.fromEntries(
      data.entries.map(
        (entry) => MapEntry(entry.key.toString(), entry.value == true),
      ),
    );
  }

  Future<List<CompanyUserRecord>> list({
    String? search,
    int? companyId,
    bool? isActive,
  }) async {
    final data = await _api.get(
      contract.apiPath,
      query: {
        if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
        if (companyId != null) 'companyId': '$companyId',
        if (isActive != null) 'isActive': '$isActive',
      },
    );
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map(
          (item) => CompanyUserRecord.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList(growable: false);
  }

  Future<void> update(int id, CompanyUserUpdateRequest request) async {
    await _api.put('${contract.apiPath}/$id', body: request.toJson());
  }
}
