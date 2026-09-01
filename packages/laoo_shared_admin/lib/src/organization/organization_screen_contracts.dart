import 'package:laoo_shared_core/laoo_shared_core.dart';

abstract final class OrganizationScreenContracts {
  static const support = ScreenContract(
    menuCode: '12005',
    routeName: 'organizationStructure',
    apiPath: '/api/support/organization-structure',
    screenType: 1,
    legacyPermissionCodes: ['ORGANIZATION_STRUCTURE'],
  );

  static const partner = ScreenContract(
    menuCode: '11005',
    routeName: 'organizationStructure',
    apiPath: '/api/partner/organization-structure',
    screenType: 1,
    legacyPermissionCodes: ['ORGANIZATION_STRUCTURE'],
  );

  static const company = ScreenContract(
    menuCode: '10005',
    routeName: 'organizationStructure',
    apiPath: '/api/company/organization-structure',
    screenType: 1,
    legacyPermissionCodes: ['ORGANIZATION_STRUCTURE'],
  );

  static ScreenContract forScope(LaooOwnerScope scope) => switch (scope) {
    LaooOwnerScope.support => support,
    LaooOwnerScope.partner => partner,
    LaooOwnerScope.company => company,
  };
}
