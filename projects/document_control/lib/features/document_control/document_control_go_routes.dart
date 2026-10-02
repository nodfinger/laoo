import 'package:go_router/go_router.dart';
import 'document_control_page.dart';
import 'document_control_route_contract.dart';

List<GoRoute> buildDocumentControlFeatureRoutes() => [
  _route(
    DocumentControlRoutePaths.settings,
    DocumentControlRouteNames.settings,
    DocumentControlMenuCodes.settings,
    'ตั้งค่าระบบควบคุมเอกสาร',
    DocumentControlPageMode.settings,
  ),
  _route(
    DocumentControlRoutePaths.types,
    DocumentControlRouteNames.types,
    DocumentControlMenuCodes.types,
    'ประเภทเอกสาร',
    DocumentControlPageMode.types,
  ),
  _route(
    DocumentControlRoutePaths.controlled,
    DocumentControlRouteNames.controlled,
    DocumentControlMenuCodes.controlled,
    'ทะเบียนเอกสารควบคุม',
    DocumentControlPageMode.controlled,
  ),
  _route(
    DocumentControlRoutePaths.approvals,
    DocumentControlRouteNames.approvals,
    DocumentControlMenuCodes.approvals,
    'ตรวจทานและอนุมัติเอกสาร',
    DocumentControlPageMode.approvals,
  ),
  _route(
    DocumentControlRoutePaths.general,
    DocumentControlRouteNames.general,
    DocumentControlMenuCodes.general,
    'เอกสารทั่วไป',
    DocumentControlPageMode.general,
  ),
  _route(
    DocumentControlRoutePaths.library,
    DocumentControlRouteNames.library,
    DocumentControlMenuCodes.library,
    'คลังเอกสาร',
    DocumentControlPageMode.library,
  ),
  _route(
    DocumentControlRoutePaths.acknowledgements,
    DocumentControlRouteNames.acknowledgements,
    DocumentControlMenuCodes.acknowledgements,
    'เอกสารรอรับทราบ',
    DocumentControlPageMode.acknowledgements,
  ),
  _route(
    DocumentControlRoutePaths.reports,
    DocumentControlRouteNames.reports,
    DocumentControlMenuCodes.reports,
    'รายงานและ Audit',
    DocumentControlPageMode.reports,
  ),
];

GoRoute _route(
  String path,
  String name,
  String menuCode,
  String title,
  DocumentControlPageMode mode,
) => GoRoute(
  path: path,
  name: name,
  builder: (_, _) =>
      DocumentControlPage(menuCode: menuCode, fallbackTitle: title, mode: mode),
);
