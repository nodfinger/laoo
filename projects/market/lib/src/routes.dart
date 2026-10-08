import 'package:go_router/go_router.dart';
import 'market_map_page.dart';

abstract final class MarketRoutes {
  static const stalls = 'market-stalls';
  static const stallPath = '/company/market-stalls';
}

List<GoRoute> buildMarketRoutes() => [
  GoRoute(
    path: MarketRoutes.stallPath,
    name: MarketRoutes.stalls,
    builder: (context, state) => const MarketMapPage(),
  ),
];
