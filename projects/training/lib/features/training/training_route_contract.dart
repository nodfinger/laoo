import 'package:laoo_shared_core/laoo_shared_core.dart';

abstract final class TrainingProject {
  static const code = 'LAOO_TRAINING';
}

abstract final class TrainingMenuCodes {
  static const types = '37001';
  static const instructors = '37002';
  static const testTemplates = '37003';
  static const settings = '37004';
  static const results = '37005';
}

abstract final class TrainingRouteNames {
  static const types = 'trainingTypes';
  static const instructors = 'trainingInstructors';
  static const testTemplates = 'trainingTestTemplates';
  static const tests = 'trainingTests';
  static const settings = 'trainingSettings';
  static const results = 'trainingResults';
}

abstract final class TrainingRoutePaths {
  static const types = '/company/training-types';
  static const instructors = '/company/training-instructors';
  static const testTemplates = '/company/training-test-templates';
  static const tests = '/company/training-tests/:bookingId';
  static const settings = '/company/training-settings';
  static const results = '/company/training-results';

  static bool isInternalTestRoute(String path) {
    final basePath = tests.substring(0, tests.indexOf('/:bookingId'));
    return path.startsWith('$basePath/') &&
        path.length > basePath.length + 1 &&
        !path.substring(basePath.length + 1).contains('/');
  }
}

abstract final class TrainingRoutes {
  static const all = <FeatureRouteContract>[
    FeatureRouteContract(
      projectCode: TrainingProject.code,
      menuCode: TrainingMenuCodes.results,
      screenType: 3,
      routeName: TrainingRouteNames.results,
      routePath: TrainingRoutePaths.results,
    ),
    FeatureRouteContract(
      projectCode: TrainingProject.code,
      menuCode: TrainingMenuCodes.settings,
      screenType: 2,
      routeName: TrainingRouteNames.settings,
      routePath: TrainingRoutePaths.settings,
      isImplemented: true,
    ),
    FeatureRouteContract(
      projectCode: TrainingProject.code,
      menuCode: TrainingMenuCodes.types,
      screenType: 1,
      routeName: TrainingRouteNames.types,
      routePath: TrainingRoutePaths.types,
    ),
    FeatureRouteContract(
      projectCode: TrainingProject.code,
      menuCode: TrainingMenuCodes.instructors,
      screenType: 1,
      routeName: TrainingRouteNames.instructors,
      routePath: TrainingRoutePaths.instructors,
    ),
    FeatureRouteContract(
      projectCode: TrainingProject.code,
      menuCode: TrainingMenuCodes.testTemplates,
      screenType: 1,
      routeName: TrainingRouteNames.testTemplates,
      routePath: TrainingRoutePaths.testTemplates,
    ),
  ];
}
