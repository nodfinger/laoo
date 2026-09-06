import 'package:laoo_shared_core/laoo_shared_core.dart';

abstract final class PartnerUserScreenContracts {
  static const support = ScreenContract(
    menuCode: '02002',
    routeName: 'partnerUser',
    apiPath: '/api/support/partner-users',
    screenType: 1,
    legacyPermissionCodes: ['PARTNER'],
  );
}
