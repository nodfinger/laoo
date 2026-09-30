import 'package:go_router/go_router.dart';
import 'sales_page.dart';
import 'sales_route_contract.dart';

List<GoRoute> buildSalesFeatureRoutes() => [
  _route(
    SalesRoutePaths.settings,
    SalesRouteNames.settings,
    '45001',
    'ตั้งค่าระบบขาย',
    'settings',
  ),
  _route(
    SalesRoutePaths.pipelineStages,
    SalesRouteNames.pipelineStages,
    '45002',
    'ขั้นตอนการขาย',
    'pipeline-stages',
  ),
  _route(
    SalesRoutePaths.leads,
    SalesRouteNames.leads,
    '45003',
    'ลูกค้าเป้าหมาย',
    'leads',
  ),
  _route(
    SalesRoutePaths.opportunities,
    SalesRouteNames.opportunities,
    '45004',
    'โอกาสการขาย',
    'opportunities',
  ),
  _route(
    SalesRoutePaths.activities,
    SalesRouteNames.activities,
    '45005',
    'กิจกรรมติดตาม',
    'activities',
  ),
  _route(
    SalesRoutePaths.myTasks,
    SalesRouteNames.myTasks,
    '45006',
    'งานขายของฉัน',
    'my-tasks',
  ),
  _route(
    SalesRoutePaths.reports,
    SalesRouteNames.reports,
    '45007',
    'รายงานการขาย',
    'reports',
  ),
];
GoRoute _route(
  String path,
  String name,
  String code,
  String title,
  String endpoint,
) => GoRoute(
  path: path,
  name: name,
  builder: (_, _) =>
      SalesPage(menuCode: code, title: title, endpoint: endpoint),
);
