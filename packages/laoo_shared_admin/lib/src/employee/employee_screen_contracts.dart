import 'package:laoo_shared_core/laoo_shared_core.dart';

enum EmployeeOwnerScope { partner, partnerCustomer, company }

abstract final class EmployeeScreenContracts {
  static const partner = ScreenContract(
    menuCode: '11001',
    routeName: 'partnerEmployees',
    apiPath: '/api/partner/employees',
    screenType: 1,
  );
  static const partnerCustomer = ScreenContract(
    menuCode: '12001',
    routeName: 'customerEmployees',
    apiPath: '/api/partner/customer-employees',
    screenType: 1,
  );
  static const company = ScreenContract(
    menuCode: '10001',
    routeName: 'companyEmployees',
    apiPath: '/api/company/employees',
    screenType: 1,
  );

  static ScreenContract forScope(EmployeeOwnerScope scope) => switch (scope) {
    EmployeeOwnerScope.partner => partner,
    EmployeeOwnerScope.partnerCustomer => partnerCustomer,
    EmployeeOwnerScope.company => company,
  };
}
