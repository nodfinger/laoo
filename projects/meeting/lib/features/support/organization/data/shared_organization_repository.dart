import 'package:laoo_shared_admin/laoo_shared_admin.dart' as shared;

import '../../../../core/api/api_client.dart';

export 'package:laoo_shared_admin/laoo_shared_admin.dart'
    show
        LaooOwnerScope,
        OrganizationScreenContracts,
        OrganizationStructureSnapshot,
        OrganizationUnitRecord,
        OrganizationUnitTypes,
        OrganizationUnitUpsertRequest,
        ScreenContract;

class OrganizationRepository extends shared.OrganizationRepository {
  OrganizationRepository({required super.scope, ApiClient? api})
    : super(api ?? ApiClient());
}
