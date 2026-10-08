import 'package:flutter/widgets.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';

typedef SportShell =
    Widget Function({
      required String pageTitle,
      required String activeMenu,
      required Widget child,
    });

late SportShell sportShell;
late JsonApiClient Function() sportApi;
late void Function(JsonApiClient) sportDispose;
late LaooWorkspaceUiTokens Function() sportTokens;
late IconData Function(String?) sportMenuIcon;
late void Function(BuildContext, {required String message, required bool error})
sportMessage;

void configureSportFeatureHost({
  required SportShell shell,
  required JsonApiClient Function() api,
  required void Function(JsonApiClient) dispose,
  required LaooWorkspaceUiTokens Function() tokens,
  required IconData Function(String?) menuIcon,
  required void Function(
    BuildContext, {
    required String message,
    required bool error,
  })
  message,
}) {
  sportShell = shell;
  sportApi = api;
  sportDispose = dispose;
  sportTokens = tokens;
  sportMenuIcon = menuIcon;
  sportMessage = message;
}
