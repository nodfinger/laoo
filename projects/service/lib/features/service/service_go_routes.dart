import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';

import '../company/customer/pages/customer_page.dart';
import '../company/delivery_note/pages/delivery_note_page.dart';
import '../company/pre_order/pages/pre_order_page.dart';
import '../company/quotation/pages/quotation_page.dart';
import '../company/tax_invoice/pages/tax_invoice_page.dart';
import '../company/temporary_receipt/pages/temporary_receipt_page.dart';
import '../inventory/pages/inventory_pages.dart';
import '../support/presentation/widgets/support_workspace_shell.dart';
import 'service_route_contract.dart';

List<GoRoute> buildServiceFeatureRoutes() => [
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
  _page('08005', (state) => const StockReceiptPage()),
  _page('08006', (state) => const SerialRegistryPage()),
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
  '14001': 'ผังสถานที่และห้องพัก',
  '14002': 'ทะเบียนอุปกรณ์และ QR Code',
  '14003': 'ทะเบียนลูกค้าภายนอก',
  '15001': 'รายการแจ้งซ่อมทั้งหมด',
  '15002': 'จัดการ QR Code แจ้งซ่อม',
  '16001': 'แผนและรอบเวลา PM',
  '16002': 'รายการตรวจเช็กมาตรฐาน',
  '16003': 'ปฏิทินงานบำรุงรักษา',
  '17001': 'กระดานจ่ายงานช่าง',
  '17002': 'ทะเบียนใบงานทั้งหมด',
  '17003': 'บันทึกปิดงานและตรวจรับ',
  '19001': 'แดชบอร์ดภาพรวมงานบริการ',
  '19002': 'ประวัติการซ่อมและค่าใช้จ่าย',
  '19003': 'รายงานผลประเมินความพึงพอใจ',
};

const _portalPlaceholders = <String, String>{
  '20001': 'แจ้งซ่อม / ขอใช้บริการ',
  '20002': 'ติดตามสถานะงานซ่อม',
  '20003': 'ประวัติการซ่อมและค่าบริการ',
  '20004': 'รอบบำรุงรักษาของห้อง',
  '20005': 'ประเมินความพึงพอใจ',
  '20006': 'แจ้งเรื่องร้องเรียน',
};
