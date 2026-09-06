import 'package:laoo_shared_admin/laoo_shared_admin.dart' as shared;

import '../../../../core/api/api_client.dart';

export 'package:laoo_shared_admin/laoo_shared_admin.dart'
    show
        PartnerUserRecord,
        PartnerUserScreenContracts,
        PartnerUserUpsertRequest,
        ScreenContract;

class PartnerUserRepository extends shared.PartnerUserRepository {
  PartnerUserRepository({ApiClient? api}) : super(api ?? ApiClient());
}
