import 'package:laoo_shared_core/laoo_shared_core.dart';

import 'partner_user_models.dart';
import 'partner_user_screen_contracts.dart';

class PartnerUserRepository {
  PartnerUserRepository(this._api);

  final JsonApiClient _api;

  ScreenContract get contract => PartnerUserScreenContracts.support;

  Future<Map<String, bool>> actions() async {
    final data = await _api.get('${contract.apiPath}/actions');
    if (data is! Map) return const {};
    return Map<String, bool>.fromEntries(
      data.entries.map(
        (entry) => MapEntry(entry.key.toString(), entry.value == true),
      ),
    );
  }

  Future<List<PartnerUserRecord>> list(int partnerId) async {
    final data = await _api.get(
      contract.apiPath,
      query: {'partnerId': '$partnerId'},
    );
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map(
          (item) => PartnerUserRecord.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList(growable: false);
  }

  Future<void> create(int partnerId, PartnerUserUpsertRequest request) async {
    await _api.post(
      '${contract.apiPath}?partnerId=$partnerId',
      body: request.toJson(),
    );
  }

  Future<void> update(int id, PartnerUserUpsertRequest request) async {
    await _api.put('${contract.apiPath}/$id', body: request.toJson());
  }

  Future<void> delete(int id) async {
    await _api.delete('${contract.apiPath}/$id');
  }
}
