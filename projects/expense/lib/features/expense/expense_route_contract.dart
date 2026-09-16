import 'package:laoo_shared_core/laoo_shared_core.dart';

abstract final class ExpenseProject {
  static const code = 'LAOO_EXPENSE';
}

abstract final class ExpenseMenuCodes {
  static const settings = '41001',
      categories = '41002',
      advances = '41003',
      claims = '41004',
      approvalInbox = '41005',
      settlements = '41006',
      myExpenses = '41007',
      reports = '41008';
}

abstract final class ExpenseRouteNames {
  static const settings = 'expenseSettings',
      categories = 'expenseCategories',
      advances = 'expenseAdvances',
      claims = 'expenseClaims',
      approvalInbox = 'expenseApprovalInbox',
      settlements = 'expenseSettlements',
      myExpenses = 'myExpenses',
      reports = 'expenseReports';
}

abstract final class ExpenseRoutePaths {
  static const settings = '/company/expense-settings',
      categories = '/company/expense-categories',
      advances = '/company/expense-advances',
      claims = '/company/expense-claims',
      approvalInbox = '/company/expense-approvals',
      settlements = '/company/expense-settlements',
      myExpenses = '/company/my-expenses',
      reports = '/company/expense-reports';
}

abstract final class ExpenseRoutes {
  static const all = <FeatureRouteContract>[
    FeatureRouteContract(
      projectCode: ExpenseProject.code,
      menuCode: ExpenseMenuCodes.settings,
      screenType: 2,
      routeName: ExpenseRouteNames.settings,
      routePath: ExpenseRoutePaths.settings,
      isImplemented: false,
    ),
    FeatureRouteContract(
      projectCode: ExpenseProject.code,
      menuCode: ExpenseMenuCodes.categories,
      screenType: 1,
      routeName: ExpenseRouteNames.categories,
      routePath: ExpenseRoutePaths.categories,
      isImplemented: false,
    ),
    FeatureRouteContract(
      projectCode: ExpenseProject.code,
      menuCode: ExpenseMenuCodes.advances,
      screenType: 4,
      routeName: ExpenseRouteNames.advances,
      routePath: ExpenseRoutePaths.advances,
      isImplemented: false,
    ),
    FeatureRouteContract(
      projectCode: ExpenseProject.code,
      menuCode: ExpenseMenuCodes.claims,
      screenType: 4,
      routeName: ExpenseRouteNames.claims,
      routePath: ExpenseRoutePaths.claims,
      isImplemented: false,
    ),
    FeatureRouteContract(
      projectCode: ExpenseProject.code,
      menuCode: ExpenseMenuCodes.approvalInbox,
      screenType: 3,
      routeName: ExpenseRouteNames.approvalInbox,
      routePath: ExpenseRoutePaths.approvalInbox,
      isImplemented: false,
    ),
    FeatureRouteContract(
      projectCode: ExpenseProject.code,
      menuCode: ExpenseMenuCodes.settlements,
      screenType: 2,
      routeName: ExpenseRouteNames.settlements,
      routePath: ExpenseRoutePaths.settlements,
      isImplemented: false,
    ),
    FeatureRouteContract(
      projectCode: ExpenseProject.code,
      menuCode: ExpenseMenuCodes.myExpenses,
      screenType: 4,
      routeName: ExpenseRouteNames.myExpenses,
      routePath: ExpenseRoutePaths.myExpenses,
      isImplemented: false,
    ),
    FeatureRouteContract(
      projectCode: ExpenseProject.code,
      menuCode: ExpenseMenuCodes.reports,
      screenType: 3,
      routeName: ExpenseRouteNames.reports,
      routePath: ExpenseRoutePaths.reports,
      isImplemented: false,
    ),
  ];
  static Iterable<FeatureRouteContract> get implemented =>
      all.where((route) => route.isImplemented);
}
