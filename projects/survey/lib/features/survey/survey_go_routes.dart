import 'package:go_router/go_router.dart';
import 'survey_pages.dart';
import 'survey_route_contract.dart';

List<GoRoute> buildSurveyFeatureRoutes() => SurveyRoutes.all
    .map(
      (route) => GoRoute(
        path: route.routePath,
        name: route.routeName,
        builder: (_, _) => SurveyPage(
          menuCode: route.menuCode,
          title: _titles[route.menuCode]!,
          endpoint: _endpoints[route.menuCode]!,
        ),
      ),
    )
    .toList(growable: false);

const _titles = <String, String>{
  '40001': 'ตั้งค่าระบบแบบสอบถาม',
  '40002': 'แบบสอบถาม',
  '40003': 'กล่องอนุมัติแบบสอบถาม',
  '40004': 'ส่งและติดตามแบบสอบถาม',
  '40005': 'ผลตอบและสรุปผล',
  '40006': 'รายงานแบบสอบถาม',
  '40007': 'แบบสอบถามของฉัน',
};
const _endpoints = <String, String>{
  '40001': 'settings',
  '40002': '',
  '40003': 'approvals',
  '40004': 'deliveries',
  '40005': 'results',
  '40006': 'reports',
  '40007': 'mine',
};
