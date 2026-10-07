import 'package:go_router/go_router.dart';
import 'patrol_page.dart';
import 'patrol_route_contract.dart';

List<GoRoute> buildPatrolFeatureRoutes() => PatrolRoutes.all
    .map(
      (r) => GoRoute(
        path: r.routePath,
        name: r.routeName,
        builder: (_, _) => PatrolPage(
          menuCode: r.menuCode,
          title: _titles[r.menuCode]!,
          endpoint: _endpoints[r.menuCode]!,
        ),
      ),
    )
    .toList();
const _titles = <String, String>{
  '56001': 'ตั้งค่าระบบตรวจตามจุด',
  '56002': 'จุดตรวจและพื้นที่',
  '56003': 'อุปกรณ์และ Adapter',
  '56004': 'บัตรและข้อมูลยืนยันตัวตน',
  '56005': 'แบบตรวจ Checklist',
  '56006': 'เส้นทางตรวจ',
  '56007': 'ตารางตรวจและผู้รับผิดชอบ',
  '56008': 'ปฏิบัติงานตรวจตามจุด',
  '56009': 'ติดตามงานตรวจ',
  '56010': 'เหตุผิดปกติและ Service',
  '56011': 'ประวัติและ Audit',
  '56012': 'Dashboard และรายงาน',
};
const _endpoints = <String, String>{
  '56001': 'settings',
  '56002': 'checkpoints',
  '56003': 'devices',
  '56004': 'credentials',
  '56005': 'checklists',
  '56006': 'routes',
  '56007': 'schedules',
  '56008': 'runs',
  '56009': 'monitor',
  '56010': 'incidents',
  '56011': 'audit',
  '56012': 'dashboard',
};
