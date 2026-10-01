import 'package:go_router/go_router.dart';

import 'pos_route_contract.dart';
import 'pos_pages.dart';

List<GoRoute> buildPosFeatureRoutes() => <GoRoute>[
  _route(
    PosRoutePaths.settings,
    PosRouteNames.settings,
    '46001',
    'ตั้งค่าระบบ POS',
    PosPageKind.settings,
  ),
  _route(
    PosRoutePaths.outletsAndTerminals,
    PosRouteNames.outletsAndTerminals,
    '46002',
    'จุดขายและเครื่องขาย',
    PosPageKind.outlets,
  ),
  _route(
    PosRoutePaths.outletItems,
    PosRouteNames.outletItems,
    '46003',
    'สินค้า ราคา และสต็อกตามจุดขาย',
    PosPageKind.items,
  ),
  _route(
    PosRoutePaths.sales,
    PosRouteNames.sales,
    '46004',
    'ขายหน้าร้าน',
    PosPageKind.sales,
  ),
  _route(
    PosRoutePaths.cashShifts,
    PosRouteNames.cashShifts,
    '46005',
    'กะเงินสด',
    PosPageKind.shifts,
  ),
  _route(
    PosRoutePaths.returns,
    PosRouteNames.returns,
    '46006',
    'คืนและยกเลิกรายการขาย',
    PosPageKind.returns,
  ),
  _route(
    PosRoutePaths.reports,
    PosRouteNames.reports,
    '46007',
    'รายงาน POS',
    PosPageKind.reports,
  ),
];

GoRoute _route(
  String path,
  String name,
  String menuCode,
  String title,
  PosPageKind kind,
) => GoRoute(
  path: path,
  name: name,
  builder: (_, _) =>
      PosPage(menuCode: menuCode, fallbackTitle: title, kind: kind),
);
