import 'package:flutter/widgets.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';

typedef FoodShell =
    Widget Function({
      required String pageTitle,
      required String activeMenu,
      required Widget child,
    });
late FoodShell foodShell;
late JsonApiClient Function() foodApi;
late void Function(JsonApiClient) foodDispose;
late LaooWorkspaceUiTokens Function() foodTokens;
typedef FoodPortalRequest =
    Future<dynamic> Function(
      String path, {
      Map<String, dynamic>? body,
      String? token,
    });
FoodPortalRequest? foodPortalRequest;
typedef FoodReportExport =
    Future<void> Function(
      String path,
      Map<String, String> query,
      String fileName,
    );
FoodReportExport? foodReportExport;
String Function(DateTime) foodDateText = (d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
late void Function(BuildContext, {required String message, required bool error})
foodMessage;

void configureSchoolFoodFeatureHost({
  required FoodShell shell,
  required JsonApiClient Function() api,
  required void Function(JsonApiClient) dispose,
  required LaooWorkspaceUiTokens Function() tokens,
  FoodPortalRequest? portalRequest,
  FoodReportExport? reportExport,
  String Function(DateTime)? dateText,
  required void Function(
    BuildContext, {
    required String message,
    required bool error,
  })
  message,
}) {
  foodShell = shell;
  foodApi = api;
  foodDispose = dispose;
  foodTokens = tokens;
  foodPortalRequest = portalRequest;
  foodReportExport = reportExport;
  if (dateText != null) foodDateText = dateText;
  foodMessage = message;
}
