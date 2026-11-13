import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';
import 'sap_pms_feature_host.dart';
import 'sap_pms_route_contract.dart';

List<GoRoute> buildSapPmsFeatureRoutes() => SapPmsRoutes.all
    .map(
      (route) => GoRoute(
        path: route.routePath,
        name: route.routeName,
        builder: (_, _) => const _SapPmsPlaceholder(),
      ),
    )
    .toList();

class _SapPmsPlaceholder extends StatelessWidget {
  const _SapPmsPlaceholder();

  @override
  Widget build(BuildContext context) => sapPmsShell(
    title: 'ตรวจสอบข้อมูล API SAP-PMS',
    menu: SapPmsRouteNames.sapPms,
    child: Padding(
      padding: sapPmsTokens.contentMargin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LaooCaptionCard(
            tokens: sapPmsTokens,
            caption: 'ตรวจสอบข้อมูล API SAP-PMS',
            leading: const Icon(Icons.api_outlined),
            favoriteKey: SapPmsMenuCodes.sapPms,
          ),
          const SizedBox(height: 8),
          LaooSurfaceCard(
            tokens: sapPmsTokens,
            child: const Center(child: Text('หน้าจออยู่ระหว่างพัฒนา')),
          ),
        ],
      ),
    ),
  );
}
