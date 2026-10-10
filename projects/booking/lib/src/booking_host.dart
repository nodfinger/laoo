import 'package:flutter/widgets.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';

typedef BookingShell =
    Widget Function({
      required String pageTitle,
      required String activeMenu,
      required Widget child,
    });

late BookingShell bookingShell;
late JsonApiClient Function() bookingApi;
late void Function(JsonApiClient) bookingDispose;
late LaooWorkspaceUiTokens Function() bookingTokens;
late IconData Function(String?) bookingMenuIcon;
late String Function(Object error, String action) bookingErrorText;
late void Function(BuildContext, {required String message, required bool error})
bookingMessage;

void configureBookingFeatureHost({
  required BookingShell shell,
  required JsonApiClient Function() api,
  required void Function(JsonApiClient) dispose,
  required LaooWorkspaceUiTokens Function() tokens,
  required IconData Function(String?) menuIcon,
  required String Function(Object error, String action) errorText,
  required void Function(
    BuildContext, {
    required String message,
    required bool error,
  })
  message,
}) {
  bookingShell = shell;
  bookingApi = api;
  bookingDispose = dispose;
  bookingTokens = tokens;
  bookingMenuIcon = menuIcon;
  bookingErrorText = errorText;
  bookingMessage = message;
}
