import 'route_names.dart';
import 'route_paths.dart';

enum AppMenuScope { support, partner, company, shared }

class AppMenuRouteSpec {
  const AppMenuRouteSpec({
    required this.menuCode,
    required this.databaseRouteName,
    required this.goRouteName,
    required this.path,
    required this.scope,
  });

  final String menuCode;
  final String databaseRouteName;
  final String goRouteName;
  final String path;
  final AppMenuScope scope;
}

abstract final class AppMenuRouteRegistry {
  static const Map<String, AppMenuRouteSpec> _byMenuCode = {
    '01001': AppMenuRouteSpec(
      menuCode: '01001',
      databaseRouteName: 'partner',
      goRouteName: RouteNames.partner,
      path: RoutePaths.partner,
      scope: AppMenuScope.support,
    ),
    '01004': AppMenuRouteSpec(
      menuCode: '01004',
      databaseRouteName: 'technicalInfo',
      goRouteName: RouteNames.technicalInfo,
      path: RoutePaths.technicalInfo,
      scope: AppMenuScope.support,
    ),
    '02001': AppMenuRouteSpec(
      menuCode: '02001',
      databaseRouteName: 'laooUser',
      goRouteName: RouteNames.laooUser,
      path: RoutePaths.laooUser,
      scope: AppMenuScope.support,
    ),
    '02002': AppMenuRouteSpec(
      menuCode: '02002',
      databaseRouteName: 'partnerUser',
      goRouteName: RouteNames.partnerUser,
      path: RoutePaths.partnerUser,
      scope: AppMenuScope.support,
    ),
    '02003': AppMenuRouteSpec(
      menuCode: '02003',
      databaseRouteName: 'companyUser',
      goRouteName: RouteNames.companyUser,
      path: RoutePaths.companyUser,
      scope: AppMenuScope.support,
    ),
    '03001': AppMenuRouteSpec(
      menuCode: '03001',
      databaseRouteName: 'module',
      goRouteName: RouteNames.module,
      path: RoutePaths.module,
      scope: AppMenuScope.support,
    ),
    '03002': AppMenuRouteSpec(
      menuCode: '03002',
      databaseRouteName: 'customerModule',
      goRouteName: RouteNames.customerModule,
      path: RoutePaths.customerModule,
      scope: AppMenuScope.support,
    ),
    '03003': AppMenuRouteSpec(
      menuCode: '03003',
      databaseRouteName: 'permission',
      goRouteName: RouteNames.permission,
      path: RoutePaths.permission,
      scope: AppMenuScope.support,
    ),
    '04001': AppMenuRouteSpec(
      menuCode: '04001',
      databaseRouteName: 'audit',
      goRouteName: RouteNames.audit,
      path: RoutePaths.audit,
      scope: AppMenuScope.support,
    ),
    '04002': AppMenuRouteSpec(
      menuCode: '04002',
      databaseRouteName: 'loginLog',
      goRouteName: RouteNames.loginLog,
      path: RoutePaths.loginLog,
      scope: AppMenuScope.support,
    ),
    '05001': AppMenuRouteSpec(
      menuCode: '05001',
      databaseRouteName: 'companySetup',
      goRouteName: RouteNames.companySetup,
      path: RoutePaths.companySetup,
      scope: AppMenuScope.shared,
    ),
    '05002': AppMenuRouteSpec(
      menuCode: '05002',
      databaseRouteName: 'masterData',
      goRouteName: RouteNames.masterData,
      path: RoutePaths.masterData,
      scope: AppMenuScope.shared,
    ),
    '05003': AppMenuRouteSpec(
      menuCode: '05003',
      databaseRouteName: 'companySetupAdditional',
      goRouteName: RouteNames.companySetupAdditional,
      path: RoutePaths.companySetupAdditional,
      scope: AppMenuScope.shared,
    ),
    '06001': AppMenuRouteSpec(
      menuCode: '06001',
      databaseRouteName: 'partnerCompanies',
      goRouteName: RouteNames.partnerCompanies,
      path: RoutePaths.partnerCompanies,
      scope: AppMenuScope.partner,
    ),
    '06002': AppMenuRouteSpec(
      menuCode: '06002',
      databaseRouteName: 'partnerBranches',
      goRouteName: RouteNames.partnerBranches,
      path: RoutePaths.partnerBranches,
      scope: AppMenuScope.partner,
    ),
    '07001': AppMenuRouteSpec(
      menuCode: '07001',
      databaseRouteName: 'partnerUsers',
      goRouteName: RouteNames.partnerUsers,
      path: RoutePaths.partnerUsers,
      scope: AppMenuScope.partner,
    ),
    '11005': AppMenuRouteSpec(
      menuCode: '11005',
      databaseRouteName: 'organizationStructure',
      goRouteName: RouteNames.organizationStructure,
      path: RoutePaths.organizationStructure,
      scope: AppMenuScope.partner,
    ),
    '08001': AppMenuRouteSpec(
      menuCode: '08001',
      databaseRouteName: 'companyProducts',
      goRouteName: RouteNames.companyProducts,
      path: RoutePaths.companyProducts,
      scope: AppMenuScope.company,
    ),
    '09001': AppMenuRouteSpec(
      menuCode: '09001',
      databaseRouteName: 'companyCustomers',
      goRouteName: RouteNames.companyCustomers,
      path: RoutePaths.companyCustomers,
      scope: AppMenuScope.company,
    ),
    '09002': AppMenuRouteSpec(
      menuCode: '09002',
      databaseRouteName: 'companyBranches',
      goRouteName: RouteNames.companyBranches,
      path: RoutePaths.companyBranches,
      scope: AppMenuScope.company,
    ),
    '10001': AppMenuRouteSpec(
      menuCode: '10001',
      databaseRouteName: 'companyEmployees',
      goRouteName: RouteNames.companyEmployees,
      path: RoutePaths.companyEmployees,
      scope: AppMenuScope.company,
    ),
    '10002': AppMenuRouteSpec(
      menuCode: '10002',
      databaseRouteName: 'companyUsers',
      goRouteName: RouteNames.companyUsers,
      path: RoutePaths.companyUsers,
      scope: AppMenuScope.company,
    ),
    '10003': AppMenuRouteSpec(
      menuCode: '10003',
      databaseRouteName: 'companyRoleGroups',
      goRouteName: RouteNames.companyRoleGroups,
      path: RoutePaths.companyRoleGroups,
      scope: AppMenuScope.company,
    ),
    '10004': AppMenuRouteSpec(
      menuCode: '10004',
      databaseRouteName: 'companyMenuPermissions',
      goRouteName: RouteNames.companyMenuPermissions,
      path: RoutePaths.companyMenuPermissions,
      scope: AppMenuScope.company,
    ),
    '10005': AppMenuRouteSpec(
      menuCode: '10005',
      databaseRouteName: 'organizationStructure',
      goRouteName: RouteNames.organizationStructure,
      path: RoutePaths.organizationStructure,
      scope: AppMenuScope.company,
    ),
    '11001': AppMenuRouteSpec(
      menuCode: '11001',
      databaseRouteName: 'partnerEmployees',
      goRouteName: RouteNames.partnerEmployees,
      path: RoutePaths.partnerEmployees,
      scope: AppMenuScope.partner,
    ),
    '11002': AppMenuRouteSpec(
      menuCode: '11002',
      databaseRouteName: 'partnerUsers',
      goRouteName: RouteNames.partnerUsers,
      path: RoutePaths.partnerUsers,
      scope: AppMenuScope.partner,
    ),
    '11003': AppMenuRouteSpec(
      menuCode: '11003',
      databaseRouteName: 'partnerRoleGroups',
      goRouteName: RouteNames.partnerRoleGroups,
      path: RoutePaths.partnerRoleGroups,
      scope: AppMenuScope.partner,
    ),
    '11004': AppMenuRouteSpec(
      menuCode: '11004',
      databaseRouteName: 'partnerMenuPermissions',
      goRouteName: RouteNames.partnerMenuPermissions,
      path: RoutePaths.partnerMenuPermissions,
      scope: AppMenuScope.partner,
    ),
    '12001': AppMenuRouteSpec(
      menuCode: '12001',
      databaseRouteName: 'customerEmployees',
      goRouteName: RouteNames.customerEmployees,
      path: RoutePaths.customerEmployees,
      scope: AppMenuScope.partner,
    ),
    '12002': AppMenuRouteSpec(
      menuCode: '12002',
      databaseRouteName: 'laooUsers',
      goRouteName: RouteNames.laooUsers,
      path: RoutePaths.laooUsers,
      scope: AppMenuScope.support,
    ),
  };

  static AppMenuRouteSpec? byMenuCode(String menuCode) =>
      _byMenuCode[menuCode.trim()];

  static Iterable<AppMenuRouteSpec> get all => _byMenuCode.values;

  static Iterable<AppMenuRouteSpec> byPath(String path) =>
      _byMenuCode.values.where((spec) => spec.path == path);

  static bool containsPath(String path) => byPath(path).isNotEmpty;
}
