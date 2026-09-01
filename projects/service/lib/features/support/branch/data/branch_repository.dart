import 'package:laoo_shared_admin/laoo_shared_admin.dart' as shared;

import '../../../../core/api/api_client.dart';

export 'package:laoo_shared_admin/laoo_shared_admin.dart'
    show
        BranchRecord,
        BranchScreenContracts,
        BranchUpsertRequest,
        LaooOwnerScope,
        ScreenContract;

class BranchRepository extends shared.BranchRepository {
  BranchRepository({required super.scope, ApiClient? api})
    : super(api ?? ApiClient());
}
