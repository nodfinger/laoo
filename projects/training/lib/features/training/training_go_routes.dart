import 'package:go_router/go_router.dart';

import '../masters/training_master_page.dart';
import 'training_route_contract.dart';

List<GoRoute> buildTrainingFeatureRoutes() => [
  GoRoute(
    path: TrainingRoutePaths.types,
    name: TrainingRouteNames.types,
    builder: (context, state) => const TrainingMasterPage.types(),
  ),
  GoRoute(
    path: TrainingRoutePaths.instructors,
    name: TrainingRouteNames.instructors,
    builder: (context, state) => const TrainingMasterPage.instructors(),
  ),
];
