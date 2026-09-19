export 'features/vote/vote_feature_host.dart';
export 'features/vote/vote_go_routes.dart';
export 'features/vote/vote_route_contract.dart';

import 'package:laoo_shared_core/laoo_shared_core.dart';

abstract final class VoteProject {
  static const code = 'LAOO_VOTE';
}

abstract final class VoteMenuCodes {
  static const settings = '44001';
  static const topics = '44002';
  static const approvalInbox = '44003';
  static const myVotes = '44004';
  static const results = '44005';
}

abstract final class VoteRouteNames {
  static const settings = 'voteSettings';
  static const topics = 'votes';
  static const approvalInbox = 'voteApprovalInbox';
  static const myVotes = 'myVotes';
  static const results = 'voteResults';
}

abstract final class VoteRoutePaths {
  static const settings = '/company/vote-settings';
  static const topics = '/company/votes';
  static const approvalInbox = '/company/vote-approvals';
  static const myVotes = '/company/my-votes';
  static const results = '/company/vote-results';
}

abstract final class VoteRoutes {
  static const all = <FeatureRouteContract>[
    FeatureRouteContract(
      projectCode: VoteProject.code,
      menuCode: VoteMenuCodes.settings,
      screenType: 2,
      routeName: VoteRouteNames.settings,
      routePath: VoteRoutePaths.settings,
      isImplemented: false,
    ),
    FeatureRouteContract(
      projectCode: VoteProject.code,
      menuCode: VoteMenuCodes.topics,
      screenType: 4,
      routeName: VoteRouteNames.topics,
      routePath: VoteRoutePaths.topics,
      isImplemented: false,
    ),
    FeatureRouteContract(
      projectCode: VoteProject.code,
      menuCode: VoteMenuCodes.approvalInbox,
      screenType: 3,
      routeName: VoteRouteNames.approvalInbox,
      routePath: VoteRoutePaths.approvalInbox,
      isImplemented: false,
    ),
    FeatureRouteContract(
      projectCode: VoteProject.code,
      menuCode: VoteMenuCodes.myVotes,
      screenType: 3,
      routeName: VoteRouteNames.myVotes,
      routePath: VoteRoutePaths.myVotes,
      isImplemented: false,
    ),
    FeatureRouteContract(
      projectCode: VoteProject.code,
      menuCode: VoteMenuCodes.results,
      screenType: 3,
      routeName: VoteRouteNames.results,
      routePath: VoteRoutePaths.results,
      isImplemented: false,
    ),
  ];

  static Iterable<FeatureRouteContract> get implemented =>
      all.where((route) => route.isImplemented);
}
