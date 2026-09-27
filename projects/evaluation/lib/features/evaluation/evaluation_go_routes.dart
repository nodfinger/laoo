import 'package:go_router/go_router.dart';

import 'evaluation_route_contract.dart';
import 'evaluation_list_page.dart';
import 'evaluation_settings_page.dart';

List<GoRoute> buildEvaluationFeatureRoutes() => <GoRoute>[
  GoRoute(
    path: EvaluationRoutePaths.settings,
    name: EvaluationRouteNames.settings,
    builder: (_, _) =>
        const EvaluationSettingsPage(title: 'ตั้งค่าระบบประเมิน'),
  ),
  _page(
    EvaluationRoutePaths.templates,
    EvaluationRouteNames.templates,
    '47002',
    'แบบประเมิน',
    'templates',
  ),
  _page(
    EvaluationRoutePaths.rounds,
    EvaluationRouteNames.rounds,
    '47003',
    'รอบประเมิน',
    'rounds',
  ),
  _page(
    EvaluationRoutePaths.approvals,
    EvaluationRouteNames.approvals,
    '47004',
    'กล่องอนุมัติรอบประเมิน',
    'approvals',
  ),
  _page(
    EvaluationRoutePaths.mine,
    EvaluationRouteNames.mine,
    '47005',
    'งานประเมินของฉัน',
    'mine',
  ),
  _page(
    EvaluationRoutePaths.results,
    EvaluationRouteNames.results,
    '47006',
    'ผลประเมิน',
    'result-rounds-filtered',
  ),
  _page(
    EvaluationRoutePaths.reports,
    EvaluationRouteNames.reports,
    '47007',
    'รายงานการประเมิน',
    'reports-filtered',
  ),
];
GoRoute _page(
  String path,
  String name,
  String menu,
  String title,
  String api,
) => GoRoute(
  path: path,
  name: name,
  builder: (_, _) => EvaluationListPage(
    menu: menu,
    title: title,
    path: '/api/company/evaluations/$api',
  ),
);
