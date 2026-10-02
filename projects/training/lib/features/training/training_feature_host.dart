import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';

typedef TrainingWorkspaceShellBuilder =
    Widget Function({
      required String pageTitle,
      required String activeMenu,
      required Widget child,
    });
typedef TrainingMessageBuilder =
    Widget Function({
      required String message,
      required bool error,
      required VoidCallback onClose,
    });
typedef TrainingMenuCaptionResolver =
    Future<String> Function({
      required String menuCode,
      required String routeName,
      required String fallback,
    });

class TrainingUiTokens {
  const TrainingUiTokens({
    required this.workspace,
    required this.primaryColor,
    required this.borderColor,
    required this.popupFieldSpacing,
    required this.popupHeaderMinHeight,
    required this.paginationButtonSize,
    required this.dialogInsetPadding,
  });
  final LaooWorkspaceUiTokens workspace;
  final Color primaryColor;
  final Color borderColor;
  final double popupFieldSpacing;
  final double popupHeaderMinHeight;
  final double paginationButtonSize;
  final double dialogInsetPadding;
}

TrainingWorkspaceShellBuilder? _shell;
JsonApiClient Function()? _apiFactory;
void Function(JsonApiClient)? _apiDisposer;
String Function(Object)? _errorText;
TrainingMessageBuilder? _message;
TrainingUiTokens Function()? _tokens;
int Function()? _pageSize;
TrainingMenuCaptionResolver? _menuCaptionResolver;

void configureTrainingFeatureHost(
  TrainingWorkspaceShellBuilder shell, {
  required JsonApiClient Function() apiClientFactory,
  required void Function(JsonApiClient) apiClientDisposer,
  required String Function(Object) errorText,
  required TrainingMessageBuilder messageBuilder,
  required TrainingUiTokens Function() uiTokensProvider,
  required int Function() pageSizeProvider,
  TrainingMenuCaptionResolver? menuCaptionResolver,
}) {
  _shell = shell;
  _apiFactory = apiClientFactory;
  _apiDisposer = apiClientDisposer;
  _errorText = errorText;
  _message = messageBuilder;
  _tokens = uiTokensProvider;
  _pageSize = pageSizeProvider;
  _menuCaptionResolver = menuCaptionResolver;
}

Widget buildTrainingWorkspaceShell({
  required String pageTitle,
  required String activeMenu,
  required Widget child,
}) {
  final shell = _shell;
  if (shell == null) {
    throw StateError('Training feature host is not configured.');
  }
  return shell(pageTitle: pageTitle, activeMenu: activeMenu, child: child);
}

JsonApiClient createTrainingApiClient() {
  final factory = _apiFactory;
  if (factory == null) {
    throw StateError('Training API client is not configured.');
  }
  return factory();
}

void disposeTrainingApiClient(JsonApiClient client) =>
    _apiDisposer?.call(client);

String trainingErrorText(Object error) =>
    _errorText?.call(error) ?? error.toString();
int get trainingPageSize => math.max(1, _pageSize?.call() ?? 30);
Future<String> resolveTrainingMenuCaption({
  required String menuCode,
  required String routeName,
  required String fallback,
}) async =>
    await _menuCaptionResolver?.call(
      menuCode: menuCode,
      routeName: routeName,
      fallback: fallback,
    ) ??
    fallback;
TrainingUiTokens get trainingUiTokens {
  final provider = _tokens;
  if (provider == null) {
    throw StateError('Training UI tokens are not configured.');
  }
  return provider();
}

Widget buildTrainingMessage({
  required String message,
  required bool error,
  required VoidCallback onClose,
}) =>
    _message?.call(message: message, error: error, onClose: onClose) ??
    const SizedBox.shrink();

class TrainingActionDialog extends StatelessWidget {
  const TrainingActionDialog({
    required this.icon,
    required this.title,
    required this.content,
    required this.actions,
    this.iconColor,
    this.destructive = false,
    super.key,
  });
  final IconData icon;
  final String title;
  final Widget content;
  final List<Widget> actions;
  final Color? iconColor;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final tokens = trainingUiTokens;
    final primary = tokens.primaryColor;
    final error = Theme.of(context).colorScheme.error;
    final radius = tokens.workspace.radius;
    OutlineInputBorder fieldBorder(Color color, {double width = 1}) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: color, width: width),
        );
    final base = Theme.of(context);
    final popupTheme = base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        surface: Colors.white,
        onSurface: Colors.black,
      ),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: Colors.white,
        border: fieldBorder(tokens.borderColor),
        enabledBorder: fieldBorder(tokens.borderColor),
        disabledBorder: fieldBorder(tokens.borderColor),
        focusedBorder: fieldBorder(primary, width: 1.5),
        errorBorder: fieldBorder(error),
        focusedErrorBorder: fieldBorder(error, width: 1.5),
        floatingLabelStyle: TextStyle(
          color: primary,
          fontSize: (tokens.workspace.inputStyle.fontSize ?? 14) / .75,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: Size(100, tokens.workspace.buttonHeight),
          maximumSize: Size(double.infinity, tokens.workspace.buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          textStyle: tokens.workspace.buttonStyle,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: Size(84, tokens.workspace.buttonHeight),
          maximumSize: Size(double.infinity, tokens.workspace.buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          textStyle: tokens.workspace.buttonStyle,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: Size(84, tokens.workspace.buttonHeight),
          maximumSize: Size(double.infinity, tokens.workspace.buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          textStyle: tokens.workspace.buttonStyle,
        ),
      ),
    );
    return Theme(
      data: popupTheme,
      child: Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        insetPadding: EdgeInsets.all(tokens.dialogInsetPadding),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: destructive ? BorderSide(color: error) : BorderSide.none,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: math.min(
              480,
              MediaQuery.sizeOf(context).width - tokens.dialogInsetPadding * 2,
            ),
            maxHeight: math.min(
              720,
              MediaQuery.sizeOf(context).height - tokens.dialogInsetPadding * 2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: tokens.popupHeaderMinHeight,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        icon,
                        color: iconColor ?? (destructive ? error : primary),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          title,
                          style: tokens.workspace.captionStyle.copyWith(
                            color: destructive ? error : Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Divider(height: 1, color: tokens.borderColor),
              Flexible(
                child: SingleChildScrollView(
                  padding: tokens.workspace.cardPadding,
                  child: content,
                ),
              ),
              Divider(height: 1, color: tokens.borderColor),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(spacing: 8, runSpacing: 8, children: actions),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TrainingFilterField extends StatelessWidget {
  const TrainingFilterField({
    super.key,
    required this.width,
    required this.child,
  });

  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) =>
        SizedBox(width: math.min(width, constraints.maxWidth), child: child),
  );
}
