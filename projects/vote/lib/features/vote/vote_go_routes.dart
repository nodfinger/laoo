import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'vote_route_contract.dart';
import 'vote_pages.dart';

List<GoRoute> buildVoteFeatureRoutes() => <GoRoute>[
  GoRoute(
    path: VoteRoutePaths.settings,
    name: VoteRouteNames.settings,
    builder: (context, state) => const VotePage('settings'),
  ),
  GoRoute(
    path: VoteRoutePaths.topics,
    name: VoteRouteNames.topics,
    builder: (context, state) => const VotePage('topics'),
  ),
  GoRoute(
    path: VoteRoutePaths.approvalInbox,
    name: VoteRouteNames.approvalInbox,
    builder: (context, state) => const VotePage('approvals'),
  ),
  GoRoute(
    path: VoteRoutePaths.myVotes,
    name: VoteRouteNames.myVotes,
    builder: (context, state) => const VotePage('mine'),
  ),
  GoRoute(
    path: VoteRoutePaths.results,
    name: VoteRouteNames.results,
    builder: (context, state) => const VotePage('results'),
  ),
];

class _SettingsPreviewPage extends StatelessWidget {
  const _SettingsPreviewPage();

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(child: Text('กำลังเตรียมหน้าตั้งค่าระบบโหวต')),
  );
}
