import 'package:go_router/go_router.dart';

import 'five_s_page.dart';
import 'five_s_route_contract.dart';

List<GoRoute> buildFiveSFeatureRoutes() => <GoRoute>[
  _route(
    FiveSRoutePaths.inspectionAreas,
    FiveSRouteNames.inspectionAreas,
    '39001',
    'พื้นที่ตรวจ 5ส',
    'areas',
  ),
  _route(
    FiveSRoutePaths.templates,
    FiveSRouteNames.templates,
    '39002',
    'Template และเกณฑ์คะแนน 5ส',
    'templates',
  ),
  _route(
    FiveSRoutePaths.inspectionTeams,
    FiveSRouteNames.inspectionTeams,
    '39003',
    'ทีมตรวจ',
    'teams',
  ),
  _route(
    FiveSRoutePaths.inspectionPlans,
    FiveSRouteNames.inspectionPlans,
    '39004',
    'แผนและรอบตรวจ',
    'plans',
  ),
  _route(
    FiveSRoutePaths.inspections,
    FiveSRouteNames.inspections,
    '39005',
    'ตรวจ 5ส',
    'inspections',
  ),
  _route(
    FiveSRoutePaths.inspectionConfirmations,
    FiveSRouteNames.inspectionConfirmations,
    '39006',
    'ยืนยันผลตรวจ',
    'confirmations',
  ),
  _route(
    FiveSRoutePaths.findings,
    FiveSRouteNames.findings,
    '39007',
    'ข้อบกพร่องและการแก้ไข',
    'findings',
  ),
  _route(
    FiveSRoutePaths.inspectionHistory,
    FiveSRouteNames.inspectionHistory,
    '39008',
    'ประวัติผลตรวจ',
    'history',
  ),
  _route(
    FiveSRoutePaths.reports,
    FiveSRouteNames.reports,
    '39009',
    'รายงานคะแนนและข้อบกพร่องค้าง',
    'reports',
  ),
  _route(
    FiveSRoutePaths.settings,
    FiveSRouteNames.settings,
    '39010',
    'ตั้งค่าระบบ 5ส',
    'settings',
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
      FiveSPage(menuCode: code, title: title, endpoint: endpoint),
);
