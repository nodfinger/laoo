import 'package:flutter/widgets.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';

typedef TimeWorkspaceShellBuilder =
    Widget Function({
      required String pageTitle,
      required String activeMenu,
      required Widget child,
    });

typedef TimeApiClientFactory = JsonApiClient Function();
typedef TimeApiClientDisposer = void Function(JsonApiClient client);
typedef TimeErrorText = String Function(Object error);
typedef TimeMessageBuilder =
    Widget Function({
      required String message,
      required bool error,
      required VoidCallback onClose,
    });

class TimeListLayout {
  const TimeListLayout({
    required this.contentMargin,
    required this.cardPadding,
    required this.cardSpacing,
    required this.paginationHeight,
    required this.captionStyle,
  });

  final EdgeInsets contentMargin;
  final EdgeInsets cardPadding;
  final double cardSpacing;
  final double paginationHeight;
  final TextStyle captionStyle;
}

TimeWorkspaceShellBuilder? _workspaceShellBuilder;
TimeApiClientFactory? _apiClientFactory;
TimeApiClientDisposer? _apiClientDisposer;
TimeErrorText? _errorText;
TimeMessageBuilder? _messageBuilder;
int Function()? _pageSizeProvider;
TimeListLayout? _listLayout;

void configureTimeFeatureHost(
  TimeWorkspaceShellBuilder builder, {
  TimeApiClientFactory? apiClientFactory,
  TimeApiClientDisposer? apiClientDisposer,
  TimeErrorText? errorText,
  TimeMessageBuilder? messageBuilder,
  int Function()? pageSizeProvider,
  TimeListLayout? listLayout,
}) {
  _workspaceShellBuilder = builder;
  _apiClientFactory = apiClientFactory;
  _apiClientDisposer = apiClientDisposer;
  _errorText = errorText;
  _messageBuilder = messageBuilder;
  _pageSizeProvider = pageSizeProvider;
  _listLayout = listLayout;
}

Widget buildTimeWorkspaceShell({
  required String pageTitle,
  required String activeMenu,
  required Widget child,
}) {
  final builder = _workspaceShellBuilder;
  if (builder == null) {
    throw StateError('Time feature host is not configured.');
  }
  return builder(pageTitle: pageTitle, activeMenu: activeMenu, child: child);
}

JsonApiClient createTimeApiClient() {
  final factory = _apiClientFactory;
  if (factory == null) throw StateError('Time API client is not configured.');
  return factory();
}

void disposeTimeApiClient(JsonApiClient client) =>
    _apiClientDisposer?.call(client);

String timeErrorText(Object error) =>
    _errorText?.call(error) ?? error.toString();

Widget buildTimeMessage({
  required String message,
  required bool error,
  required VoidCallback onClose,
}) {
  final builder = _messageBuilder;
  if (builder == null) return const SizedBox.shrink();
  return builder(message: message, error: error, onClose: onClose);
}

int get timePageSize {
  final value = _pageSizeProvider?.call() ?? 30;
  return value > 0 ? value : 30;
}

TimeListLayout get timeListLayout =>
    _listLayout ??
    const TimeListLayout(
      contentMargin: EdgeInsets.all(10),
      cardPadding: EdgeInsets.all(10),
      cardSpacing: 10,
      paginationHeight: 56,
      captionStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
    );
