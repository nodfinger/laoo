import 'package:flutter/widgets.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';

typedef SapPmsShell = Widget Function({
  required String pageTitle,
  required String activeMenu,
  required Widget child,
});

SapPmsShell? _shell;
JsonApiClient Function()? _api;
void Function(JsonApiClient)? _dispose;
LaooWorkspaceUiTokens Function()? _tokens;
Future<String> Function(String, String)? _title;

void configureSapPmsFeatureHost(
  SapPmsShell shell, {
  required JsonApiClient Function() apiClientFactory,
  required void Function(JsonApiClient) apiClientDisposer,
  required LaooWorkspaceUiTokens Function() uiTokensProvider,
  required Future<String> Function(String, String) menuTitleResolver,
}) {
  _shell = shell;
  _api = apiClientFactory;
  _dispose = apiClientDisposer;
  _tokens = uiTokensProvider;
  _title = menuTitleResolver;
}

JsonApiClient createSapPmsApi() => _api!.call();
void disposeSapPmsApi(JsonApiClient value) => _dispose?.call(value);
LaooWorkspaceUiTokens get sapPmsTokens => _tokens!.call();
Future<String> sapPmsTitle(String code, String fallback) =>
    _title?.call(code, fallback) ?? Future.value(fallback);
Widget sapPmsShell({
  required String title,
  required String menu,
  required Widget child,
}) => _shell!.call(pageTitle: title, activeMenu: menu, child: child);
