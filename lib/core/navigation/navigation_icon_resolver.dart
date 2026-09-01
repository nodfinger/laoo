import 'package:flutter/material.dart';

/// Converts the data-driven `IconName` returned by the Navigation API into a
/// Material icon. Menu codes and captions must never be used to choose icons.
abstract final class NavigationIconResolver {
  static IconData resolve(
    String? value, {
    IconData fallback = Icons.menu_outlined,
  }) {
    final name = _normalize(value);
    if (name.isEmpty) return fallback;

    final mapped = _icons[name];
    if (mapped != null) return mapped;

    return fallback;
  }

  static String _normalize(String? value) {
    var name = value?.trim().toLowerCase() ?? '';
    if (name.startsWith('icons.')) name = name.substring(6);
    return name.replaceAll('-', '_').replaceAll(' ', '_');
  }

  static const Map<String, IconData> _icons = <String, IconData>{
    'home': Icons.home_outlined,
    'home_outlined': Icons.home_outlined,
    'dashboard': Icons.dashboard_outlined,
    'dashboard_outlined': Icons.dashboard_outlined,
    'apps': Icons.apps_outlined,
    'apps_outlined': Icons.apps_outlined,
    'menu': Icons.menu_outlined,
    'menu_outlined': Icons.menu_outlined,

    'people': Icons.people_outline,
    'people_outline': Icons.people_outline,
    'people_outlined': Icons.people_outline,
    'person': Icons.person_outline,
    'person_outline': Icons.person_outline,
    'person_outlined': Icons.person_outline,
    'badge': Icons.badge_outlined,
    'badge_outlined': Icons.badge_outlined,
    'groups': Icons.groups_outlined,
    'groups_outlined': Icons.groups_outlined,
    'admin_panel_settings': Icons.admin_panel_settings_outlined,
    'admin_panel_settings_outlined': Icons.admin_panel_settings_outlined,
    'manage_accounts': Icons.manage_accounts_outlined,
    'manage_accounts_outlined': Icons.manage_accounts_outlined,

    'settings': Icons.settings_outlined,
    'settings_outlined': Icons.settings_outlined,
    'settings_applications': Icons.settings_applications_outlined,
    'settings_applications_outlined': Icons.settings_applications_outlined,
    'settings_suggest': Icons.settings_suggest_outlined,
    'settings_suggest_outlined': Icons.settings_suggest_outlined,
    'tune': Icons.tune_outlined,
    'tune_outlined': Icons.tune_outlined,
    'build': Icons.build_outlined,
    'build_outlined': Icons.build_outlined,
    'construction': Icons.construction_outlined,
    'construction_outlined': Icons.construction_outlined,
    'developer_mode': Icons.developer_mode_outlined,
    'developer_mode_outlined': Icons.developer_mode_outlined,

    'account_tree': Icons.account_tree_outlined,
    'account_tree_outlined': Icons.account_tree_outlined,
    'apartment': Icons.apartment_outlined,
    'apartment_outlined': Icons.apartment_outlined,
    'business': Icons.business_outlined,
    'business_outlined': Icons.business_outlined,
    'meeting_room': Icons.meeting_room_outlined,
    'meeting_room_outlined': Icons.meeting_room_outlined,
    'location_on': Icons.location_on_outlined,
    'location_on_outlined': Icons.location_on_outlined,
    'home_work': Icons.home_work_outlined,
    'home_work_outlined': Icons.home_work_outlined,

    'inventory': Icons.inventory_outlined,
    'inventory_outlined': Icons.inventory_outlined,
    'inventory_2': Icons.inventory_2_outlined,
    'inventory_2_outlined': Icons.inventory_2_outlined,
    'warehouse': Icons.warehouse_outlined,
    'warehouse_outlined': Icons.warehouse_outlined,
    'category': Icons.category_outlined,
    'category_outlined': Icons.category_outlined,
    'sell': Icons.sell_outlined,
    'sell_outlined': Icons.sell_outlined,
    'shopping_cart': Icons.shopping_cart_outlined,
    'shopping_cart_outlined': Icons.shopping_cart_outlined,
    'point_of_sale': Icons.point_of_sale_outlined,
    'point_of_sale_outlined': Icons.point_of_sale_outlined,

    'request_quote': Icons.request_quote_outlined,
    'request_quote_outlined': Icons.request_quote_outlined,
    'receipt': Icons.receipt_outlined,
    'receipt_outlined': Icons.receipt_outlined,
    'receipt_long': Icons.receipt_long_outlined,
    'receipt_long_outlined': Icons.receipt_long_outlined,
    'local_shipping': Icons.local_shipping_outlined,
    'local_shipping_outlined': Icons.local_shipping_outlined,
    'payments': Icons.payments_outlined,
    'payments_outlined': Icons.payments_outlined,

    'assignment': Icons.assignment_outlined,
    'assignment_outlined': Icons.assignment_outlined,
    'assignment_turned_in': Icons.assignment_turned_in_outlined,
    'assignment_turned_in_outlined': Icons.assignment_turned_in_outlined,
    'checklist': Icons.checklist_outlined,
    'checklist_outlined': Icons.checklist_outlined,
    'calendar_month': Icons.calendar_month_outlined,
    'calendar_month_outlined': Icons.calendar_month_outlined,
    'engineering': Icons.engineering_outlined,
    'engineering_outlined': Icons.engineering_outlined,
    'precision_manufacturing': Icons.precision_manufacturing_outlined,
    'precision_manufacturing_outlined': Icons.precision_manufacturing_outlined,
    'qr_code': Icons.qr_code_outlined,
    'qr_code_outlined': Icons.qr_code_outlined,
    'qr_code_2': Icons.qr_code_2_outlined,
    'qr_code_2_outlined': Icons.qr_code_2_outlined,

    'list': Icons.list_alt_outlined,
    'list_alt': Icons.list_alt_outlined,
    'list_alt_outlined': Icons.list_alt_outlined,
    'view_list': Icons.view_list_outlined,
    'view_list_outlined': Icons.view_list_outlined,
    'format_list_bulleted': Icons.format_list_bulleted,
    'table_view': Icons.table_view_outlined,
    'table_view_outlined': Icons.table_view_outlined,
    'dataset': Icons.dataset_outlined,
    'dataset_outlined': Icons.dataset_outlined,
    'database': Icons.storage_outlined,
    'database_outlined': Icons.storage_outlined,
    'schema': Icons.schema_outlined,
    'schema_outlined': Icons.schema_outlined,
    'storage': Icons.storage_outlined,
    'storage_outlined': Icons.storage_outlined,
    'dns': Icons.dns_outlined,
    'dns_outlined': Icons.dns_outlined,
    'folder': Icons.folder_outlined,
    'folder_outlined': Icons.folder_outlined,
    'description': Icons.description_outlined,
    'description_outlined': Icons.description_outlined,

    'analytics': Icons.analytics_outlined,
    'analytics_outlined': Icons.analytics_outlined,
    'assessment': Icons.assessment_outlined,
    'assessment_outlined': Icons.assessment_outlined,
    'history': Icons.history_outlined,
    'history_outlined': Icons.history_outlined,
    'support': Icons.support_agent_outlined,
    'support_outlined': Icons.support_agent_outlined,
    'support_agent': Icons.support_agent_outlined,
    'support_agent_outlined': Icons.support_agent_outlined,
    'feedback': Icons.feedback_outlined,
    'feedback_outlined': Icons.feedback_outlined,
    'report': Icons.report_outlined,
    'report_outlined': Icons.report_outlined,
    'campaign': Icons.campaign_outlined,
    'campaign_outlined': Icons.campaign_outlined,
    'toggle_on': Icons.toggle_on_outlined,
    'toggle_on_outlined': Icons.toggle_on_outlined,
  };
}
