import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';

import '../company/customer/pages/customer_page.dart';
import '../company/person/pages/service_person_page.dart';
import '../service_request/pages/service_request_page.dart';
import '../service_request_qr/pages/service_request_qr_page.dart';
import '../service_settings/pages/service_settings_page.dart';
import '../job_dispatch/pages/job_dispatch_page.dart';
import '../job_work_orders/pages/job_work_orders_page.dart';
import '../pm/pages/pm_pages.dart';
import '../service_dashboard/pages/service_dashboard_page.dart';
import '../repair_history/pages/repair_history_page.dart';
import '../company/delivery_note/pages/delivery_note_page.dart';
import '../company/pre_order/pages/pre_order_page.dart';
import '../company/quotation/pages/quotation_page.dart';
import '../company/tax_invoice/pages/tax_invoice_page.dart';
import '../company/temporary_receipt/pages/temporary_receipt_page.dart';
import '../inventory/pages/inventory_pages.dart';
import '../inventory/pages/stock_receipt_page.dart';
import '../support/presentation/widgets/support_workspace_shell.dart';
import 'service_route_contract.dart';

List<GoRoute> buildServiceFeatureRoutes({
  ReceiptVendorCreator? onCreateReceiptVendor,
}) => [
  _page('09001', (state) => const CustomerPage()),
  _page(
    '09003',
    (state) => QuotationPage(
      action:
          state.uri.queryParameters['action'] == 'new' ||
          state.uri.queryParameters['action'] == 'edit',
      quotationId: int.tryParse(state.uri.queryParameters['id'] ?? ''),
    ),
  ),
  _page(
    '09004',
    (state) => PreOrderPage(
      action:
          state.uri.queryParameters['action'] == 'new' ||
          state.uri.queryParameters['action'] == 'edit',
      preOrderId: int.tryParse(state.uri.queryParameters['id'] ?? ''),
    ),
  ),
  _page(
    '09005',
    (state) => TemporaryReceiptPage(
      action:
          state.uri.queryParameters['action'] == 'new' ||
          state.uri.queryParameters['action'] == 'edit',
      receiptId: int.tryParse(state.uri.queryParameters['id'] ?? ''),
    ),
  ),
  _page(
    '09006',
    (state) => DeliveryNotePage(
      action:
          state.uri.queryParameters['action'] == 'new' ||
          state.uri.queryParameters['action'] == 'edit',
      deliveryNoteId: int.tryParse(state.uri.queryParameters['id'] ?? ''),
    ),
  ),
  _page(
    '09007',
    (state) => TaxInvoicePage(
      action:
          state.uri.queryParameters['action'] == 'new' ||
          state.uri.queryParameters['action'] == 'edit',
      taxInvoiceId: int.tryParse(state.uri.queryParameters['id'] ?? ''),
    ),
  ),
  _page('08002', (state) => const InventoryItemCatalogPage()),
  _page('08003', (state) => const InventoryIssuePage()),
  _page('08004', (state) => const WarehousePage()),
  _page(
    '08005',
    (state) => StockReceiptPage(onCreateVendor: onCreateReceiptVendor),
  ),
  _page('08006', (state) => const SerialRegistryPage()),
  _page(
    '14002',
    (state) =>
        const SerialRegistryPage(menuCode: '14002', routeName: 'assetItems'),
  ),
  _page(
    '14005',
    (state) => const ServicePersonPage(role: ServicePersonRole.customer),
  ),
  _page(
    '14006',
    (state) => const ServicePersonPage(role: ServicePersonRole.resident),
  ),
  _page('15001', (state) => const ServiceRequestPage()),
  _page('15002', (state) => const ServiceRequestQrPage()),
  _page(
    '20001',
    (state) => ServiceRequestPage(
      selfService: true,
      qrToken: state.uri.queryParameters['qr'],
    ),
  ),
  _page(
    '20002',
    (state) => const ServiceRequestPage(
      selfService: true,
      readOnly: true,
      menuCode: '20002',
      routeName: 'portalTracking',
    ),
  ),
  _page(
    '20003',
    (state) => const ServiceRequestPage(
      selfService: true,
      readOnly: true,
      menuCode: '20003',
      routeName: 'portalHistory',
      fixedStatus: 'COMPLETED',
    ),
  ),
  _page('18001', (state) => const ServiceSettingsPage()),
  _page('17001', (state) => const JobDispatchPage()),
  _page(
    '17002',
    (state) => JobWorkOrdersPage(
      initialStatus: state.uri.queryParameters['status'] ?? 'OPEN',
    ),
  ),
  _page(
    '17003',
    (state) => JobWorkOrdersPage(
      initialStatus: state.uri.queryParameters['status'] ?? 'OPEN',
    ),
  ),
  _page('19001', (state) => const ServiceDashboardPage()),
  _page('19002', (state) => const RepairHistoryPage()),
  _page('16001', (state) => const PmPlansPage()),
  _page('16002', (state) => const PmChecklistsPage()),
  _page('16003', (state) => const PmCalendarPage()),
  _page(
    '20004',
    (state) => const PmCalendarPage(
      menuCode: '20004',
      routeName: 'portalPmSchedule',
      pageTitle: 'รอบบำรุงรักษาของห้อง',
      portalSchedule: true,
    ),
  ),
  ..._workspacePlaceholders.entries.map(
    (entry) =>
        _workspacePlaceholder(ServiceRoutes.byMenuCode(entry.key), entry.value),
  ),
  ..._portalPlaceholders.entries.map(
    (entry) =>
        _portalPlaceholder(ServiceRoutes.byMenuCode(entry.key), entry.value),
  ),
];

GoRoute _page(String menuCode, Widget Function(GoRouterState state) builder) {
  final route = ServiceRoutes.byMenuCode(menuCode);
  return GoRoute(
    path: route.routePath,
    name: route.effectiveGoRouteName,
    builder: (context, state) => builder(state),
  );
}

GoRoute _workspacePlaceholder(FeatureRouteContract route, String title) =>
    GoRoute(
      path: route.routePath,
      name: route.effectiveGoRouteName,
      builder: (context, state) => SupportWorkspaceShell(
        pageTitle: title,
        activeMenu: route.routeName,
        menuScope: WorkspaceMenuScope.company,
        child: Center(child: Text('$title จะพัฒนาต่อในขั้นตอนถัดไป')),
      ),
    );

GoRoute _portalPlaceholder(FeatureRouteContract route, String title) => GoRoute(
  path: route.routePath,
  name: route.effectiveGoRouteName,
  builder: (context, state) => Scaffold(
    appBar: AppBar(title: const Text('Laoo Service')),
    body: Center(child: Text('$title อยู่ในแผนพัฒนา Phase 1')),
  ),
);

const _workspacePlaceholders = <String, String>{
  '14001': 'ผังสถานที่และพื้นที่',
  '14003': 'ทะเบียนลูกค้าภายนอก',
  '19003': 'รายงานผลประเมินความพึงพอใจ',
};

const _portalPlaceholders = <String, String>{
  '20005': 'ประเมินความพึงพอใจ',
  '20006': 'แจ้งเรื่องร้องเรียน',
};
