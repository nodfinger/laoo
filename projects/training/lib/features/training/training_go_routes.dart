import 'package:go_router/go_router.dart';

import '../masters/training_master_page.dart';
import '../masters/training_test_template_placeholder_page.dart';
import '../results/training_results_page.dart';
import '../results/my_training_page.dart';
import '../tests/training_test_page.dart';
import 'training_route_contract.dart';
import 'training_settings_page.dart';

List<GoRoute> buildTrainingFeatureRoutes() => [
  GoRoute(
    path: TrainingRoutePaths.settings,
    name: TrainingRouteNames.settings,
    builder: (context, state) => const TrainingSettingsPage(),
  ),
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
    path: TrainingRoutePaths.testTemplates,
    name: TrainingRouteNames.testTemplates,
    builder: (context, state) => const TrainingTestTemplatePlaceholderPage(),
  ),
  GoRoute(
    path: TrainingRoutePaths.results,
    name: TrainingRouteNames.results,
    builder: (context, state) => const TrainingResultsPage(),
  ),
  GoRoute(
    path: TrainingRoutePaths.myTraining,
    name: TrainingRouteNames.myTraining,
    builder: (context, state) => const MyTrainingPage(),
  ),
  GoRoute(
    path: TrainingRoutePaths.tests,
    name: TrainingRouteNames.tests,
    builder: (context, state) => TrainingTestPage(
      bookingId: int.parse(state.pathParameters['bookingId']!),
      initialSection: state.uri.queryParameters['section'] ?? 'PRE',
      examId: int.tryParse(state.uri.queryParameters['examId'] ?? ''),
    ),
  ),
];
