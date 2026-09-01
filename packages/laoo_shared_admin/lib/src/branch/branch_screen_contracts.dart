import 'package:laoo_shared_core/laoo_shared_core.dart';

abstract final class BranchScreenContracts {
  static const support = ScreenContract(
    menuCode: '01003',
    routeName: 'branch',
    apiPath: '/api/support/branches',
    screenType: 1,
    legacyPermissionCodes: ['BRANCH'],
  );

  static const partner = ScreenContract(
    menuCode: '06002',
    routeName: 'partnerBranches',
    apiPath: '/api/partner/branches',
    screenType: 1,
    legacyPermissionCodes: ['PARTNER_BRANCH'],
  );

  static const company = ScreenContract(
    menuCode: '09002',
    routeName: 'companyBranches',
    apiPath: '/api/company/branches',
    screenType: 1,
  );

  static ScreenContract forScope(LaooOwnerScope scope) => switch (scope) {
    LaooOwnerScope.support => support,
    LaooOwnerScope.partner => partner,
    LaooOwnerScope.company => company,
  };
}
