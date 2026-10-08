import 'package:flutter/widgets.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';

typedef MarketShell =
    Widget Function({
      required String pageTitle,
      required String activeMenu,
      required Widget child,
    });

late MarketShell marketShell;
late JsonApiClient Function() marketApi;
late void Function(JsonApiClient) marketDispose;
late LaooWorkspaceUiTokens Function() marketTokens;
late IconData Function(String?) marketMenuIcon;
late String Function(DateTime) marketDateText;
late String Function(Object error, String action) marketErrorText;
late void Function(BuildContext, {required String message, required bool error})
marketMessage;

void configureMarketFeatureHost({
  required MarketShell shell,
  required JsonApiClient Function() api,
  required void Function(JsonApiClient) dispose,
  required LaooWorkspaceUiTokens Function() tokens,
  required IconData Function(String?) menuIcon,
  required String Function(DateTime) dateText,
  required String Function(Object error, String action) errorText,
  required void Function(
    BuildContext, {
    required String message,
    required bool error,
  })
  message,
}) {
  marketShell = shell;
  marketApi = api;
  marketDispose = dispose;
  marketTokens = tokens;
  marketMenuIcon = menuIcon;
  marketDateText = dateText;
  marketErrorText = errorText;
  marketMessage = message;
}
