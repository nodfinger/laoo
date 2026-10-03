import 'package:flutter/widgets.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';

typedef SchoolShell =
    Widget Function({
      required String pageTitle,
      required String activeMenu,
      required Widget child,
    });

SchoolShell? _shell;
JsonApiClient Function()? _api;
void Function(JsonApiClient)? _dispose;
LaooWorkspaceUiTokens Function()? _tokens;
Future<String> Function(String, String)? _title;
Future<dynamic> Function(Map<String, dynamic>)? _guardianLogin;
Future<dynamic> Function(String)? _guardianPortal;
void Function(BuildContext, {required String message, required bool error})?
_message;

void configureSchoolFeatureHost(
  SchoolShell shell, {
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
  required Future<dynamic> Function(Map<String, dynamic>) guardianLogin,
  required Future<dynamic> Function(String token) guardianPortal,
}) {
  _shell = shell;
  _api = apiClientFactory;
  _dispose = apiClientDisposer;
  _tokens = uiTokensProvider;
  _title = menuTitleResolver;
  _message = messagePresenter;
  _guardianLogin = guardianLogin;
  _guardianPortal = guardianPortal;
}

JsonApiClient createSchoolApi() => _api!.call();
void disposeSchoolApi(JsonApiClient value) => _dispose?.call(value);
LaooWorkspaceUiTokens get schoolTokens => _tokens!.call();
Future<String> schoolTitle(String code, String fallback) =>
    _title?.call(code, fallback) ?? Future.value(fallback);
void schoolMessage(
  BuildContext context,
  String message, {
  bool error = false,
}) => _message?.call(context, message: message, error: error);
Widget schoolShell({
  required String title,
  required String menu,
  required Widget child,
}) => _shell!.call(pageTitle: title, activeMenu: menu, child: child);
Future<dynamic> schoolGuardianLogin(Map<String, dynamic> body) =>
    _guardianLogin!.call(body);
Future<dynamic> schoolGuardianPortal(String token) =>
    _guardianPortal!.call(token);
