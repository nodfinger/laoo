export '../../evaluation_feature.dart'
    show
        EvaluationMenuCodes,
        EvaluationProject,
        EvaluationRouteNames,
        EvaluationRoutePaths,
        EvaluationRoutes;
import 'package:flutter/widgets.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';

typedef EvaluationWorkspaceShellBuilder =
    Widget Function({
      required String pageTitle,
      required String activeMenu,
      required Widget child,
    });
typedef EvaluationMessagePresenter =
    void Function(
      BuildContext context, {
      required String message,
      required bool error,
    });
typedef EvaluationMenuTitleResolver =
    Future<String> Function(String menuCode, String fallback);

class EvaluationUiTokens {
  const EvaluationUiTokens({
    required this.contentMargin,
    required this.cardPadding,
    required this.sectionSpacing,
    required this.itemSpacing,
    required this.radius,
    required this.popupHeaderMinHeight,
    required this.popupFieldSpacing,
    required this.buttonHeight,
    required this.paginationCardHeight,
    required this.compactBreakpoint,
    required this.captionStyle,
    required this.sectionStyle,
    required this.inputStyle,
    required this.buttonStyle,
    required this.primaryColor,
    required this.borderColor,
    required this.backgroundColor,
    required this.popupSurfaceColor,
    required this.dangerColor,
    required this.dangerSurfaceColor,
  });

  final EdgeInsets contentMargin;
  final EdgeInsets cardPadding;
  final double sectionSpacing;
  final double itemSpacing;
  final double radius;
  final double popupHeaderMinHeight;
  final double popupFieldSpacing;
  final double buttonHeight;
  final double paginationCardHeight;
  final double compactBreakpoint;
  final TextStyle captionStyle;
  final TextStyle sectionStyle;
  final TextStyle inputStyle;
  final TextStyle buttonStyle;
  final Color primaryColor;
  final Color borderColor;
  final Color backgroundColor;
  final Color popupSurfaceColor;
  final Color dangerColor;
  final Color dangerSurfaceColor;
}

EvaluationWorkspaceShellBuilder? _builder;
JsonApiClient Function()? _apiFactory;
void Function(JsonApiClient)? _apiDisposer;
EvaluationMessagePresenter? _messagePresenter;
EvaluationUiTokens Function()? _uiTokensProvider;
String Function(Object)? _errorText;
String Function(DateTime)? _dateTimeText;
EvaluationMenuTitleResolver? _menuTitleResolver;
void configureEvaluationFeatureHost(
  EvaluationWorkspaceShellBuilder builder, {
  required JsonApiClient Function() apiClientFactory,
  required void Function(JsonApiClient) apiClientDisposer,
  required EvaluationUiTokens Function() uiTokensProvider,
  required String Function(Object error) errorText,
  required String Function(DateTime value) dateTimeText,
  required EvaluationMenuTitleResolver menuTitleResolver,
  EvaluationMessagePresenter? messagePresenter,
}) {
  _builder = builder;
  _apiFactory = apiClientFactory;
  _apiDisposer = apiClientDisposer;
  _messagePresenter = messagePresenter;
  _uiTokensProvider = uiTokensProvider;
  _errorText = errorText;
  _dateTimeText = dateTimeText;
  _menuTitleResolver = menuTitleResolver;
}

Widget buildEvaluationWorkspaceShell({
  required String pageTitle,
  required String activeMenu,
  required Widget child,
}) {
  final builder = _builder;
  if (builder == null) {
    throw StateError('Evaluation feature host is not configured.');
  }
  return builder(pageTitle: pageTitle, activeMenu: activeMenu, child: child);
}

JsonApiClient createEvaluationApiClient() =>
    _apiFactory?.call() ??
    (throw StateError('Evaluation API client is not configured.'));
void disposeEvaluationApiClient(JsonApiClient client) =>
    _apiDisposer?.call(client);

EvaluationUiTokens get evaluationUiTokens =>
    _uiTokensProvider?.call() ??
    (throw StateError('Evaluation UI tokens are not configured.'));

String evaluationErrorText(Object error) =>
    _errorText?.call(error) ?? 'กรุณาลองใหม่อีกครั้ง';

String evaluationDateTimeText(DateTime value) =>
    _dateTimeText?.call(value) ?? value.toIso8601String();

Future<String> resolveEvaluationMenuTitle(String menuCode, String fallback) =>
    _menuTitleResolver?.call(menuCode, fallback) ?? Future.value(fallback);

void showEvaluationMessage(
  BuildContext context, {
  required String message,
  bool error = false,
}) => _messagePresenter?.call(context, message: message, error: error);
