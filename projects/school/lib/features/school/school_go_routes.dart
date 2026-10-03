import 'package:go_router/go_router.dart';
import 'guardian_portal_page.dart';
import 'school_page.dart';
import 'school_route_contract.dart';

List<GoRoute> buildSchoolFeatureRoutes() => SchoolRoutes.all
    .map(
      (r) => GoRoute(
        path: r.routePath,
        name: r.routeName,
        builder: (context, state) => SchoolPage(
          menuCode: r.menuCode,
          fallbackTitle: _titles[r.menuCode]!,
        ),
      ),
    )
    .toList();

List<GoRoute> buildSchoolPublicRoutes() => [
  GoRoute(
    path: '/school/guardian',
    name: 'schoolGuardianLogin',
    builder: (context, state) => const GuardianPortalPage(),
  ),
];

const _titles = <String, String>{
  '52001': 'ตั้งค่าระบบโรงเรียน',
  '52002': 'ระดับชั้น',
  '52003': 'รอบเรียนและเวลาเข้าออก',
  '52004': 'วันหยุดโรงเรียน',
  '52005': 'วิชา ห้องเรียน และตารางเรียน',
  '52006': 'ข้อมูลนักเรียน',
  '52007': 'ข้อมูลผู้ปกครอง',
  '52008': 'ลงเวลาเข้า–ออกโรงเรียน',
  '52009': 'เช็กชื่อรายคาบ',
  '52010': 'ข่าวสารถึงผู้ปกครอง',
  '52011': 'รายงานเวลาเข้า–ออก',
  '52012': 'รายงานเวลาเรียนรายวิชา',
  '52013': 'Dashboard โรงเรียน',
  '52014': 'มุมผู้ปกครอง',
};
