import 'package:flutter/widgets.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';

typedef SapPmsShell =
    Widget Function({
      required String pageTitle,
      required String activeMenu,
      required Widget child,
    });
SapPmsShell? _shell;
JsonApiClient Function()? _client;
void Function(JsonApiClient)? _dispose;
LaooWorkspaceUiTokens Function()? _tokens;
Future<String> Function(String, String)? _title;
void Function(BuildContext, {required String message, required bool error})?
_message;

void configureSapPmsFeatureHost(
  SapPmsShell shell, {
  required JsonApiClient Function() apiClientFactory,
  required void Function(JsonApiClient) apiClientDisposer,
  required LaooWorkspaceUiTokens Function() uiTokensProvider,
  required Future<String> Function(String, String) menuTitleResolver,
  required void Function(
    BuildContext, {
    required String message,
    required bool error,
  })
  messagePresenter,
}) {
  _shell = shell;
  _client = apiClientFactory;
  _dispose = apiClientDisposer;
  _tokens = uiTokensProvider;
  _title = menuTitleResolver;
  _message = messagePresenter;
}

Widget sapPmsShell({required String pageTitle, required Widget child}) =>
    _shell!(pageTitle: pageTitle, activeMenu: 'mySystemSapPms', child: child);
JsonApiClient sapPmsClient() => _client!();
void disposeSapPmsClient(JsonApiClient client) => _dispose!(client);
LaooWorkspaceUiTokens get sapPmsTokens => _tokens!();
Future<String> sapPmsTitle() => _title!('65002', 'ตรวจสอบข้อมูล API SAP-PMS');
void sapPmsMessage(
  BuildContext context,
  String message, {
  bool error = false,
}) => _message!(context, message: message, error: error);
