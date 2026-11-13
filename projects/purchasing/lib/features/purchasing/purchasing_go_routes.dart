import 'package:go_router/go_router.dart';

import 'purchasing_request_page.dart';
import 'purchasing_route_contract.dart';

List<GoRoute> buildPurchasingFeatureRoutes() => [
      GoRoute(
        name: PurchasingRouteNames.requests,
        path: PurchasingRoutePaths.requests,
        builder: (_, _) => const PurchasingRequestPage(),
      ),
    ];
