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

class TrainingUiTokens {
  const TrainingUiTokens({
    required this.workspace,
    required this.primaryColor,
    required this.borderColor,
  });
  final LaooWorkspaceUiTokens workspace;
  final Color primaryColor;
  final Color borderColor;
}

TrainingWorkspaceShellBuilder? _shell;
JsonApiClient Function()? _apiFactory;
void Function(JsonApiClient)? _apiDisposer;
String Function(Object)? _errorText;
TrainingMessageBuilder? _message;
TrainingUiTokens Function()? _tokens;
int Function()? _pageSize;

void configureTrainingFeatureHost(
  TrainingWorkspaceShellBuilder shell, {
  required JsonApiClient Function() apiClientFactory,
  required void Function(JsonApiClient) apiClientDisposer,
  required String Function(Object) errorText,
  required TrainingMessageBuilder messageBuilder,
  required TrainingUiTokens Function() uiTokensProvider,
  required int Function() pageSizeProvider,
}) {
  _shell = shell;
  _apiFactory = apiClientFactory;
  _apiDisposer = apiClientDisposer;
  _errorText = errorText;
  _message = messageBuilder;
  _tokens = uiTokensProvider;
  _pageSize = pageSizeProvider;
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
    super.key,
  });
  final IconData icon;
  final String title;
  final Widget content;
  final List<Widget> actions;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final tokens = trainingUiTokens;
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.workspace.radius),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: math.min(480, MediaQuery.sizeOf(context).width - 32),
          maxHeight: 720,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                children: [
                  Icon(icon, color: iconColor ?? tokens.primaryColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(title, style: tokens.workspace.captionStyle),
                  ),
                ],
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
    );
  }
}
