import 'package:laoo_shared_core/laoo_shared_core.dart';

abstract final class EvaluationProject {
  static const code = 'LAOO_EVALUATION';
}

abstract final class EvaluationMenuCodes {
  static const settings = '47001',
      templates = '47002',
      rounds = '47003',
      approvals = '47004',
      mine = '47005',
      results = '47006',
      reports = '47007';
}

abstract final class EvaluationRouteNames {
  static const settings = 'evaluationSettings',
      templates = 'evaluationTemplates',
      rounds = 'evaluationRounds',
      approvals = 'evaluationApprovals',
      mine = 'myEvaluations',
      results = 'evaluationResults',
      reports = 'evaluationReports';
}

abstract final class EvaluationRoutePaths {
  static const settings = '/company/evaluation-settings',
      templates = '/company/evaluation-templates',
      rounds = '/company/evaluation-rounds',
      approvals = '/company/evaluation-approvals',
      mine = '/company/my-evaluations',
      results = '/company/evaluation-results',
      reports = '/company/evaluation-reports';
}

abstract final class EvaluationPublicRoutePaths {
  static const responsePrefix = '/evaluation/respond/';

  static bool isResponseRoute(String path) =>
      path.startsWith(responsePrefix) && path.length > responsePrefix.length;
}

abstract final class EvaluationRoutes {
  static const all = <FeatureRouteContract>[
    FeatureRouteContract(
      projectCode: EvaluationProject.code,
      menuCode: EvaluationMenuCodes.settings,
      screenType: 2,
      routeName: EvaluationRouteNames.settings,
      routePath: EvaluationRoutePaths.settings,
      isImplemented: false,
    ),
    FeatureRouteContract(
      projectCode: EvaluationProject.code,
      menuCode: EvaluationMenuCodes.templates,
      screenType: 1,
      routeName: EvaluationRouteNames.templates,
      routePath: EvaluationRoutePaths.templates,
      isImplemented: false,
    ),
    FeatureRouteContract(
      projectCode: EvaluationProject.code,
      menuCode: EvaluationMenuCodes.rounds,
      screenType: 4,
      routeName: EvaluationRouteNames.rounds,
      routePath: EvaluationRoutePaths.rounds,
      isImplemented: false,
    ),
    FeatureRouteContract(
      projectCode: EvaluationProject.code,
      menuCode: EvaluationMenuCodes.approvals,
      screenType: 3,
      routeName: EvaluationRouteNames.approvals,
      routePath: EvaluationRoutePaths.approvals,
      isImplemented: false,
    ),
    FeatureRouteContract(
      projectCode: EvaluationProject.code,
      menuCode: EvaluationMenuCodes.mine,
      screenType: 3,
      routeName: EvaluationRouteNames.mine,
      routePath: EvaluationRoutePaths.mine,
      isImplemented: false,
    ),
    FeatureRouteContract(
      projectCode: EvaluationProject.code,
      menuCode: EvaluationMenuCodes.results,
      screenType: 3,
      routeName: EvaluationRouteNames.results,
      routePath: EvaluationRoutePaths.results,
      isImplemented: false,
    ),
    FeatureRouteContract(
      projectCode: EvaluationProject.code,
      menuCode: EvaluationMenuCodes.reports,
      screenType: 3,
      routeName: EvaluationRouteNames.reports,
      routePath: EvaluationRoutePaths.reports,
      isImplemented: false,
    ),
  ];
  static Iterable<FeatureRouteContract> get implemented =>
      all.where((x) => x.isImplemented);
}
