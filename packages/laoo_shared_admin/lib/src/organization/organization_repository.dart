import 'package:laoo_shared_core/laoo_shared_core.dart';

import 'organization_models.dart';
import 'organization_screen_contracts.dart';

class OrganizationRepository {
  OrganizationRepository(this._api, {required this.scope});

  final JsonApiClient _api;
  final LaooOwnerScope scope;

  ScreenContract get contract => OrganizationScreenContracts.forScope(scope);

  Future<Map<String, bool>> actions() async {
    final data = await _api.get('${contract.apiPath}/actions');
    if (data is! Map) return const {};
    return Map<String, bool>.fromEntries(
      data.entries.map(
        (entry) => MapEntry('${entry.key}', entry.value == true),
      ),
    );
  }

  Future<OrganizationStructureSnapshot> load() async {
    final data = await _api.get(contract.apiPath);
    return OrganizationStructureSnapshot.fromJson(
      Map<String, dynamic>.from(data as Map),
    );
  }

  Future<void> create(OrganizationUnitUpsertRequest request) async {
    await _api.post(contract.apiPath, body: request.toJson());
  }

  Future<void> updateMode(int mode) async {
    await _api.put(
      '${contract.apiPath}/mode',
      body: {'orgStructureType': mode},
    );
  }

  Future<void> update(int id, OrganizationUnitUpsertRequest request) async {
    await _api.put('${contract.apiPath}/$id', body: request.toJson());
  }

  Future<void> delete(int id) async {
    await _api.delete('${contract.apiPath}/$id');
  }
}
