import 'package:flutter/widgets.dart';

typedef VoteWorkspaceShellBuilder =
    Widget Function({
      required String pageTitle,
      required String activeMenu,
      required Widget child,
    });

VoteWorkspaceShellBuilder? _workspaceShellBuilder;

void configureVoteFeatureHost(VoteWorkspaceShellBuilder builder) =>
    _workspaceShellBuilder = builder;

Widget buildVoteWorkspaceShell({
  required String pageTitle,
  required String activeMenu,
  required Widget child,
}) {
  final builder = _workspaceShellBuilder;
  if (builder == null) {
    throw StateError('Vote feature host is not configured.');
  }
  return builder(pageTitle: pageTitle, activeMenu: activeMenu, child: child);
}
