import 'package:laoo_shared_core/laoo_shared_core.dart';

abstract final class SurveyProject {
  static const code = 'LAOO_SURVEY';
}

abstract final class SurveyMenuCodes {
  static const settings = '40001';
  static const questionnaires = '40002';
  static const approvalInbox = '40003';
  static const delivery = '40004';
  static const results = '40005';
  static const reports = '40006';
}

abstract final class SurveyRouteNames {
  static const settings = 'surveySettings';
  static const questionnaires = 'surveys';
  static const approvalInbox = 'surveyApprovalInbox';
  static const delivery = 'surveyDelivery';
  static const results = 'surveyResults';
  static const reports = 'surveyReports';
}

abstract final class SurveyRoutePaths {
  static const settings = '/company/survey-settings';
  static const questionnaires = '/company/surveys';
  static const approvalInbox = '/company/survey-approvals';
  static const delivery = '/company/survey-delivery';
  static const results = '/company/survey-results';
  static const reports = '/company/survey-reports';
}

abstract final class SurveyRoutes {
  static const all = <FeatureRouteContract>[
    FeatureRouteContract(
      projectCode: SurveyProject.code,
      menuCode: SurveyMenuCodes.settings,
      screenType: 2,
      routeName: SurveyRouteNames.settings,
      routePath: SurveyRoutePaths.settings,
      isImplemented: false,
    ),
    FeatureRouteContract(
      projectCode: SurveyProject.code,
      menuCode: SurveyMenuCodes.questionnaires,
      screenType: 4,
      routeName: SurveyRouteNames.questionnaires,
      routePath: SurveyRoutePaths.questionnaires,
      isImplemented: false,
    ),
    FeatureRouteContract(
      projectCode: SurveyProject.code,
      menuCode: SurveyMenuCodes.approvalInbox,
      screenType: 3,
      routeName: SurveyRouteNames.approvalInbox,
      routePath: SurveyRoutePaths.approvalInbox,
      isImplemented: false,
    ),
    FeatureRouteContract(
      projectCode: SurveyProject.code,
      menuCode: SurveyMenuCodes.delivery,
      screenType: 2,
      routeName: SurveyRouteNames.delivery,
      routePath: SurveyRoutePaths.delivery,
      isImplemented: false,
    ),
    FeatureRouteContract(
      projectCode: SurveyProject.code,
      menuCode: SurveyMenuCodes.results,
      screenType: 3,
      routeName: SurveyRouteNames.results,
      routePath: SurveyRoutePaths.results,
      isImplemented: false,
    ),
    FeatureRouteContract(
      projectCode: SurveyProject.code,
      menuCode: SurveyMenuCodes.reports,
      screenType: 3,
      routeName: SurveyRouteNames.reports,
      routePath: SurveyRoutePaths.reports,
      isImplemented: false,
    ),
  ];
  static Iterable<FeatureRouteContract> get implemented =>
      all.where((route) => route.isImplemented);
}
