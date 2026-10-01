import 'package:go_router/go_router.dart';
import 'expense_page.dart';
import 'expense_route_contract.dart';
import 'expense_workflow_page.dart';

List<GoRoute> buildExpenseFeatureRoutes() => [
  _route(
    ExpenseRoutePaths.settings,
    ExpenseRouteNames.settings,
    ExpenseMenuCodes.settings,
    'ตั้งค่าระบบค่าใช้จ่าย',
    'settings',
  ),
  _route(
    ExpenseRoutePaths.categories,
    ExpenseRouteNames.categories,
    ExpenseMenuCodes.categories,
    'ประเภทค่าใช้จ่าย',
    'categories',
  ),
  _workflow(
    ExpenseRoutePaths.advances,
    ExpenseRouteNames.advances,
    ExpenseMenuCodes.advances,
    'เงินทดรองและเคลียร์เงิน',
    ExpenseWorkflowMode.advances,
  ),
  _workflow(
    ExpenseRoutePaths.claims,
    ExpenseRouteNames.claims,
    ExpenseMenuCodes.claims,
    'ใบขอเบิกค่าใช้จ่าย',
    ExpenseWorkflowMode.claims,
  ),
  _workflow(
    ExpenseRoutePaths.approvalInbox,
    ExpenseRouteNames.approvalInbox,
    ExpenseMenuCodes.approvalInbox,
    'กล่องอนุมัติค่าใช้จ่าย',
    ExpenseWorkflowMode.approvals,
  ),
  _workflow(
    ExpenseRoutePaths.settlements,
    ExpenseRouteNames.settlements,
    ExpenseMenuCodes.settlements,
    'ติดตามการจ่ายและเคลียร์เงิน',
    ExpenseWorkflowMode.settlements,
  ),
  _workflow(
    ExpenseRoutePaths.myExpenses,
    ExpenseRouteNames.myExpenses,
    ExpenseMenuCodes.myExpenses,
    'ค่าใช้จ่ายของฉัน',
    ExpenseWorkflowMode.mine,
  ),
  _workflow(
    ExpenseRoutePaths.reports,
    ExpenseRouteNames.reports,
    ExpenseMenuCodes.reports,
    'รายงานค่าใช้จ่าย',
    ExpenseWorkflowMode.reports,
  ),
  _route(
    ExpenseRoutePaths.directEntries,
    ExpenseRouteNames.directEntries,
    ExpenseMenuCodes.directEntries,
    'บันทึกค่าใช้จ่ายโดยตรง',
    'direct',
  ),
];
GoRoute _route(
  String path,
  String name,
  String menu,
  String title,
  String endpoint,
) => GoRoute(
  path: path,
  name: name,
  builder: (_, _) =>
      ExpensePage(menuCode: menu, title: title, endpoint: endpoint),
);
GoRoute _workflow(
  String path,
  String name,
  String menu,
  String title,
  ExpenseWorkflowMode mode,
) => GoRoute(
  path: path,
  name: name,
  builder: (_, _) =>
      ExpenseWorkflowPage(menuCode: menu, title: title, mode: mode),
);
