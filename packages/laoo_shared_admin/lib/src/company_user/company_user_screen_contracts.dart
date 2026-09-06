import 'package:laoo_shared_core/laoo_shared_core.dart';

abstract final class CompanyUserScreenContracts {
  static const partner = ScreenContract(
    menuCode: '07001',
    routeName: 'partnerUsers',
    apiPath: '/api/partner/company-users',
    screenType: 2,
  );
}
