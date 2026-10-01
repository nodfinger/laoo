import 'package:go_router/go_router.dart';

import 'intranet_pages.dart';
import 'intranet_route_contract.dart';

List<GoRoute> buildIntranetFeatureRoutes() => IntranetRoutes.all
    .map(
      (route) => GoRoute(
        path: route.routePath,
        name: route.routeName,
        builder: (_, _) => IntranetPage(
          menuCode: route.menuCode,
          title: _titles[route.menuCode]!,
        ),
      ),
    )
    .toList(growable: false);

const _titles = <String, String>{
  '43001': 'ตั้งค่าระบบ Intranet',
  '43002': 'เนื้อหา Intranet',
  '43003': 'กล่องอนุมัติเนื้อหา Intranet',
  '43004': 'Intranet ของฉัน',
  '43005': 'รายงานและประวัติ Intranet',
};
