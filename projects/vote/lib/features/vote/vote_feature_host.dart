import 'package:flutter/widgets.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';

typedef VoteWorkspaceShellBuilder =
    Widget Function({
      required String pageTitle,
      required String activeMenu,
      required Widget child,
    });

VoteWorkspaceShellBuilder? _workspaceShellBuilder;
JsonApiClient Function()? _apiFactory;
void Function(JsonApiClient)? _apiDisposer;

void configureVoteFeatureHost(
  VoteWorkspaceShellBuilder builder, {
  JsonApiClient Function()? apiClientFactory,
  void Function(JsonApiClient)? apiClientDisposer,
}) {
  _workspaceShellBuilder = builder;
  _apiFactory = apiClientFactory;
  _apiDisposer = apiClientDisposer;
}

JsonApiClient createVoteApiClient() =>
    _apiFactory?.call() ??
    (throw StateError('Vote API client is not configured.'));

void disposeVoteApiClient(JsonApiClient client) => _apiDisposer?.call(client);

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
