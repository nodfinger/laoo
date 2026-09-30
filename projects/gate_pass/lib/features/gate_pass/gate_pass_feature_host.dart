import 'package:flutter/widgets.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';

typedef GatePassWorkspaceShellBuilder =
    Widget Function({
      required String pageTitle,
      required String activeMenu,
      required Widget child,
    });
typedef GatePassMenuTitleResolver =
    Future<String> Function(String menuCode, String fallback);
typedef GatePassMessagePresenter =
    void Function(
      BuildContext context, {
      required String message,
      required bool error,
    });
typedef GatePassUpload =
    Future<dynamic> Function(
      String path, {
      required String fileName,
      required List<int> bytes,
    });

class GatePassUiTokens {
  const GatePassUiTokens({
    required this.contentMargin,
    required this.cardPadding,
    required this.sectionSpacing,
    required this.itemSpacing,
    required this.radius,
    required this.buttonHeight,
    required this.paginationCardHeight,
    required this.compactBreakpoint,
    required this.captionStyle,
    required this.sectionStyle,
    required this.inputStyle,
    required this.tableStyle,
    required this.buttonStyle,
    required this.primaryColor,
    required this.borderColor,
  });

  final EdgeInsets contentMargin;
  final EdgeInsets cardPadding;
  final double sectionSpacing;
  final double itemSpacing;
  final double radius;
  final double buttonHeight;
  final double paginationCardHeight;
  final double compactBreakpoint;
  final TextStyle captionStyle;
  final TextStyle sectionStyle;
  final TextStyle inputStyle;
  final TextStyle tableStyle;
  final TextStyle buttonStyle;
  final Color primaryColor;
  final Color borderColor;
}

GatePassWorkspaceShellBuilder? _workspaceShellBuilder;
JsonApiClient Function()? _apiFactory;
void Function(JsonApiClient)? _apiDisposer;
GatePassUiTokens Function()? _uiTokensProvider;
GatePassMenuTitleResolver? _menuTitleResolver;
GatePassMessagePresenter? _messagePresenter;
GatePassUpload? _upload;

void configureGatePassFeatureHost(
  GatePassWorkspaceShellBuilder builder, {
  JsonApiClient Function()? apiClientFactory,
  void Function(JsonApiClient)? apiClientDisposer,
  GatePassUiTokens Function()? uiTokensProvider,
  GatePassMenuTitleResolver? menuTitleResolver,
  GatePassMessagePresenter? messagePresenter,
  GatePassUpload? upload,
}) {
  _workspaceShellBuilder = builder;
  _apiFactory = apiClientFactory;
  _apiDisposer = apiClientDisposer;
  _uiTokensProvider = uiTokensProvider;
  _menuTitleResolver = menuTitleResolver;
  _messagePresenter = messagePresenter;
  _upload = upload;
}

JsonApiClient createGatePassApiClient() =>
    _apiFactory?.call() ??
    (throw StateError('Gate Pass API client is not configured.'));

void disposeGatePassApiClient(JsonApiClient client) =>
    _apiDisposer?.call(client);

GatePassUiTokens get gatePassUiTokens =>
    _uiTokensProvider?.call() ??
    (throw StateError('Gate Pass UI tokens are not configured.'));

Future<String> resolveGatePassMenuTitle(String menuCode, String fallback) =>
    _menuTitleResolver?.call(menuCode, fallback) ?? Future.value(fallback);

void showGatePassMessage(
  BuildContext context, {
  required String message,
  bool error = false,
}) => _messagePresenter?.call(context, message: message, error: error);

Future<dynamic> uploadGatePassFile(
  String path, {
  required String fileName,
  required List<int> bytes,
}) =>
    _upload?.call(path, fileName: fileName, bytes: bytes) ??
    (throw StateError('Gate Pass upload is not configured.'));

Widget buildGatePassWorkspaceShell({
  required String pageTitle,
  required String activeMenu,
  required Widget child,
}) {
  final builder = _workspaceShellBuilder;
  if (builder == null) {
    throw StateError('Gate Pass feature host is not configured.');
  }
  return builder(pageTitle: pageTitle, activeMenu: activeMenu, child: child);
}
