import 'package:go_router/go_router.dart';

import 'gate_pass_route_contract.dart';
import 'gate_pass_page.dart';

List<GoRoute> buildGatePassFeatureRoutes() => <GoRoute>[
  GoRoute(
    path: GatePassRoutePaths.settings,
    name: GatePassRouteNames.settings,
    builder: (context, state) => const GatePassPage(
      menuCode: '38001',
      title: 'ตั้งค่าระบบนำทรัพย์สินออก',
      endpoint: 'settings',
    ),
  ),
  GoRoute(
    path: GatePassRoutePaths.purposes,
    name: GatePassRouteNames.purposes,
    builder: (context, state) => const GatePassPage(
      menuCode: '38002',
      title: 'วัตถุประสงค์การนำออก',
      endpoint: 'purposes',
    ),
  ),
  GoRoute(
    path: GatePassRoutePaths.requests,
    name: GatePassRouteNames.requests,
    builder: (context, state) => const GatePassPage(
      menuCode: '38003',
      title: 'ใบขอนำทรัพย์สินออก',
      endpoint: 'requests',
    ),
  ),
  GoRoute(
    path: GatePassRoutePaths.approvalInbox,
    name: GatePassRouteNames.approvalInbox,
    builder: (context, state) => const GatePassPage(
      menuCode: '38004',
      title: 'กล่องอนุมัติใบขอนำทรัพย์สินออก',
      endpoint: 'approvals',
    ),
  ),
  GoRoute(
    path: GatePassRoutePaths.exitCheck,
    name: GatePassRouteNames.exitCheck,
    builder: (context, state) => const GatePassPage(
      menuCode: '38005',
      title: 'ตรวจปล่อยทรัพย์สินออก',
      endpoint: 'exit-check',
    ),
  ),
  GoRoute(
    path: GatePassRoutePaths.returnTracking,
    name: GatePassRouteNames.returnTracking,
    builder: (context, state) => const GatePassPage(
      menuCode: '38006',
      title: 'ติดตามรับทรัพย์สินกลับ',
      endpoint: 'returns',
    ),
  ),
  GoRoute(
    path: GatePassRoutePaths.myGatePasses,
    name: GatePassRouteNames.myGatePasses,
    builder: (context, state) => const GatePassPage(
      menuCode: '38007',
      title: 'ใบขอนำทรัพย์สินออกของฉัน',
      endpoint: 'mine',
    ),
  ),
  GoRoute(
    path: GatePassRoutePaths.reports,
    name: GatePassRouteNames.reports,
    builder: (context, state) => const GatePassPage(
      menuCode: '38008',
      title: 'รายงานการนำทรัพย์สินออก',
      endpoint: 'dashboard',
    ),
  ),
];
