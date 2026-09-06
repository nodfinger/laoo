import 'package:laoo_shared_admin/laoo_shared_admin.dart' as shared;

import '../../../../core/api/api_client.dart';

class SharedBranchRepository extends shared.BranchRepository {
  SharedBranchRepository({required super.scope, ApiClient? api})
    : super(api ?? ApiClient());
}
