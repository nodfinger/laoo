import 'package:laoo_shared_admin/laoo_shared_admin.dart' as shared;

import '../../../../core/api/api_client.dart';

export 'package:laoo_shared_admin/laoo_shared_admin.dart'
    show
        EmployeeListResult,
        EmployeeOwnerScope,
        EmployeeRecord,
        EmployeeScreenContracts,
        EmployeeUpsertRequest,
        EmployeeUserRecord,
        ScreenContract;

class EmployeeRepository extends shared.EmployeeRepository {
  EmployeeRepository({required super.scope, ApiClient? api})
    : super(api ?? ApiClient());
}
