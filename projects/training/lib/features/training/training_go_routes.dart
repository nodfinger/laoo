import 'package:go_router/go_router.dart';

import '../masters/training_master_page.dart';
import '../tests/training_test_page.dart';
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
  GoRoute(
    path: TrainingRoutePaths.tests,
    name: TrainingRouteNames.tests,
    builder: (context, state) => TrainingTestPage(
      bookingId: int.parse(state.pathParameters['bookingId']!),
      initialSection: state.uri.queryParameters['section'] ?? 'PRE',
    ),
  ),
];
