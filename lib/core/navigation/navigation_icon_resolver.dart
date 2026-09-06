import 'package:flutter/material.dart';

abstract final class NavigationIconResolver {
  static IconData resolve(
    String? value, {
    IconData fallback = Icons.menu_outlined,
  }) {
    var normalized = value?.trim().toLowerCase() ?? '';
    if (normalized.startsWith('icons.')) normalized = normalized.substring(6);
    normalized = normalized.replaceAll('-', '_').replaceAll(' ', '_');
    return resolveNavigationIcon(normalized, fallback: fallback);
  }
}

/// Resolves database `IconName` values to one consistent Material icon set.
///
/// Both legacy names (for example `people`) and the preferred outlined names
/// are supported so existing tenants keep a meaningful icon while their data
/// is being migrated.
IconData resolveNavigationIcon(
  String? name, {
  IconData fallback = Icons.apps_outlined,
}) {
  final key = name?.trim().toLowerCase();
  return switch (key) {
    'home' || 'home_outlined' => Icons.home_outlined,
    'dashboard' || 'dashboard_outlined' => Icons.dashboard_outlined,
    'admin_panel_settings' ||
    'admin_panel_settings_outlined' => Icons.admin_panel_settings_outlined,
    'manage_accounts' ||
    'manage_accounts_outlined' => Icons.manage_accounts_outlined,
    'extension' || 'extension_outlined' => Icons.extension_outlined,
    'policy' || 'policy_outlined' => Icons.policy_outlined,
    'settings' || 'settings_outlined' => Icons.settings_outlined,
    'tune' || 'tune_outlined' => Icons.tune_outlined,
    'business' || 'business_outlined' => Icons.business_outlined,
    'business_center' ||
    'business_center_outlined' => Icons.business_center_outlined,
    'corporate_fare' ||
    'corporate_fare_outlined' => Icons.corporate_fare_outlined,
    'store' || 'store_outlined' => Icons.store_outlined,
    'hub' || 'hub_outlined' => Icons.hub_outlined,
    'dns' || 'dns_outlined' => Icons.dns_outlined,
    'developer_mode' ||
    'developer_mode_outlined' => Icons.developer_mode_outlined,
    'storage' || 'storage_outlined' => Icons.storage_outlined,
    'inventory' || 'inventory_outlined' => Icons.inventory_outlined,
    'inventory_2' || 'inventory_2_outlined' => Icons.inventory_2_outlined,
    'sell' || 'sell_outlined' => Icons.sell_outlined,
    'point_of_sale' || 'point_of_sale_outlined' => Icons.point_of_sale_outlined,
    'shopping_cart_checkout' ||
    'shopping_cart_checkout_outlined' => Icons.shopping_cart_checkout_outlined,
    'request_quote' || 'request_quote_outlined' => Icons.request_quote_outlined,
    'receipt' || 'receipt_outlined' => Icons.receipt_outlined,
    'receipt_long' || 'receipt_long_outlined' => Icons.receipt_long_outlined,
    'local_shipping' ||
    'local_shipping_outlined' => Icons.local_shipping_outlined,
    'people' ||
    'people_outline' ||
    'people_outlined' ||
    'groups' ||
    'groups_outlined' => Icons.groups_outlined,
    'person' || 'person_outline' || 'person_outlined' => Icons.person_outline,
    'person_search' || 'person_search_outlined' => Icons.person_search_outlined,
    'badge' || 'badge_outlined' => Icons.badge_outlined,
    'contact_page' || 'contact_page_outlined' => Icons.contact_page_outlined,
    'handshake' || 'handshake_outlined' => Icons.handshake_outlined,
    'shield' ||
    'shield_outlined' ||
    'security' ||
    'security_outlined' => Icons.shield_outlined,
    'account_tree' || 'account_tree_outlined' => Icons.account_tree_outlined,
    'device_hub' || 'device_hub_outlined' => Icons.device_hub_outlined,
    'fact_check' || 'fact_check_outlined' => Icons.fact_check_outlined,
    'login' || 'login_outlined' => Icons.login_outlined,
    'apartment' ||
    'apartment_outlined' ||
    'location_city' ||
    'location_city_outlined' => Icons.location_city_outlined,
    'meeting_room' || 'meeting_room_outlined' => Icons.meeting_room_outlined,
    'qr_code' ||
    'qr_code_2' ||
    'qr_code_2_outlined' => Icons.qr_code_2_outlined,
    'qr_code_scanner' ||
    'qr_code_scanner_outlined' => Icons.qr_code_scanner_outlined,
    'build_circle' ||
    'home_repair_service' ||
    'home_repair_service_outlined' => Icons.home_repair_service_outlined,
    'support' ||
    'support_outlined' ||
    'support_agent' ||
    'support_agent_outlined' => Icons.support_agent_outlined,
    'event_repeat' || 'event_repeat_outlined' => Icons.event_repeat_outlined,
    'checklist' ||
    'checklist_outlined' ||
    'list' ||
    'list_alt_outlined' => Icons.checklist_outlined,
    'calendar_month' ||
    'calendar_month_outlined' => Icons.calendar_month_outlined,
    'event' ||
    'event_available' ||
    'event_available_outlined' => Icons.event_available_outlined,
    'engineering' || 'engineering_outlined' => Icons.engineering_outlined,
    'view_kanban' || 'view_kanban_outlined' => Icons.view_kanban_outlined,
    'assignment' || 'assignment_outlined' => Icons.assignment_outlined,
    'task_alt' || 'task_alt_outlined' => Icons.task_alt_outlined,
    'output' || 'output_outlined' => Icons.output_outlined,
    'analytics' || 'analytics_outlined' => Icons.analytics_outlined,
    'history' || 'history_outlined' => Icons.history_outlined,
    'star' || 'star_outline' || 'star_rate' => Icons.star_outline,
    'sentiment_satisfied_alt' || 'sentiment_satisfied_alt_outlined' =>
      Icons.sentiment_satisfied_alt_outlined,
    'add_circle' || 'add_circle_outline' => Icons.add_circle_outline,
    'track_changes' || 'track_changes_outlined' => Icons.track_changes_outlined,
    'report_problem' ||
    'report_problem_outlined' => Icons.report_problem_outlined,
    'contact_support' ||
    'contact_support_outlined' => Icons.contact_support_outlined,
    _ => fallback,
  };
}
