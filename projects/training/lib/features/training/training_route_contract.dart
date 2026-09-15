import 'package:laoo_shared_core/laoo_shared_core.dart';

abstract final class TrainingProject {
  static const code = 'LAOO_TRAINING';
}

abstract final class TrainingMenuCodes {
  static const types = '37001';
  static const instructors = '37002';
}

abstract final class TrainingRouteNames {
  static const types = 'trainingTypes';
  static const instructors = 'trainingInstructors';
}

abstract final class TrainingRoutePaths {
  static const types = '/company/training-types';
  static const instructors = '/company/training-instructors';
}

abstract final class TrainingRoutes {
  static const all = <FeatureRouteContract>[
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
  ];
}
