import 'package:laoo_shared_core/laoo_shared_core.dart';

import 'branch_models.dart';
import 'branch_screen_contracts.dart';

class BranchRepository {
  BranchRepository(this._api, {required this.scope});

  final JsonApiClient _api;
  final LaooOwnerScope scope;

  ScreenContract get contract => BranchScreenContracts.forScope(scope);

  Future<Map<String, bool>> actions() async {
    final data = await _api.get('${contract.apiPath}/actions');
    if (data is! Map) return const {};
    return Map<String, bool>.fromEntries(
      data.entries.map(
        (entry) => MapEntry('${entry.key}', entry.value == true),
      ),
    );
  }

  Future<List<BranchRecord>> get({String? search, int? companyId}) async {
    final data = await _api.get(
      contract.apiPath,
      query: {
        'search': search ?? '',
        if (companyId != null) 'companyId': '$companyId',
      },
    );
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((item) => BranchRecord.fromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  Future<void> create(BranchUpsertRequest request) async {
    await _api.post(contract.apiPath, body: request.toJson());
  }

  Future<void> update(int id, BranchUpsertRequest request) async {
    await _api.put('${contract.apiPath}/$id', body: request.toJson());
  }

  Future<void> delete(int id) async {
    await _api.delete('${contract.apiPath}/$id');
  }
}
