import 'package:flutter/material.dart';

/// Resolves Navigation API icon names consistently across every menu style.
abstract final class MenuIconResolver {
  static IconData resolve(String? iconName, {String? semanticName}) {
    final normalized = iconName?.trim().toLowerCase().replaceAll('-', '_');
    final configured = _icons[normalized];
    if (configured != null) return configured;
    return _fromMeaning(semanticName);
  }

  static const Map<String?, IconData> _icons = {
    'home': Icons.home_outlined,
    'business': Icons.business_center_outlined,
    'business_center': Icons.business_center_outlined,
    'handshake': Icons.handshake_outlined,
    'domain': Icons.domain_outlined,
    'apartment': Icons.apartment_outlined,
    'account_tree': Icons.account_tree_outlined,
    'group': Icons.groups_outlined,
    'groups': Icons.groups_outlined,
    'groups_3': Icons.groups_3_outlined,
    'people': Icons.groups_outlined,
    'person': Icons.person_outline,
    'badge': Icons.badge_outlined,
    'manage_accounts': Icons.manage_accounts_outlined,
    'supervisor_account': Icons.supervisor_account_outlined,
    'support': Icons.support_outlined,
    'support_agent': Icons.support_agent_outlined,
    'admin_panel_settings': Icons.admin_panel_settings_outlined,
    'verified_user': Icons.verified_user_outlined,
    'shield': Icons.shield_outlined,
    'rule': Icons.rule_outlined,
    'widgets': Icons.view_module_outlined,
    'view_module': Icons.view_module_outlined,
    'extension': Icons.extension_outlined,
    'receipt_long': Icons.receipt_long_outlined,
    'fact_check': Icons.fact_check_outlined,
    'login': Icons.login_outlined,
    'settings': Icons.settings_outlined,
    'settings_suggest': Icons.settings_suggest_outlined,
    'tune': Icons.tune_outlined,
    'code': Icons.data_object_outlined,
    'data_object': Icons.data_object_outlined,
    'developer_mode': Icons.terminal_outlined,
    'terminal': Icons.terminal_outlined,
    'meeting_room': Icons.meeting_room_outlined,
    'event_available': Icons.event_available_outlined,
    'approval': Icons.approval_outlined,
    'approval_outlined': Icons.approval_outlined,
    'calendar_month': Icons.calendar_month_outlined,
    'mark_email_read': Icons.mark_email_read_outlined,
    'sensor_door': Icons.sensor_door_outlined,
    'how_to_reg': Icons.how_to_reg_outlined,
    'handyman': Icons.handyman_outlined,
    'report_problem': Icons.report_problem_outlined,
    'devices_other': Icons.devices_other_outlined,
    'analytics': Icons.analytics_outlined,
    'person_off': Icons.person_off_outlined,
    'reviews': Icons.reviews_outlined,
    'list': Icons.list_alt_outlined,
    'inventory_2': Icons.inventory_2_outlined,
    'restaurant_menu': Icons.restaurant_menu_outlined,
    'room_service': Icons.room_service_outlined,
    'sell': Icons.sell_outlined,
  };

  static IconData _fromMeaning(String? value) {
    final text = value?.trim().toLowerCase() ?? '';
    if (text.contains('อนุมัติ') || text.contains('approval')) {
      return Icons.approval_outlined;
    }
    if (text.contains('ปฏิทิน') || text.contains('calendar')) {
      return Icons.calendar_month_outlined;
    }
    if (text.contains('คำเชิญ') || text.contains('invitation')) {
      return Icons.mark_email_read_outlined;
    }
    if (text.contains('เช็กอิน') || text.contains('check-in')) {
      return Icons.how_to_reg_outlined;
    }
    if (text.contains('เตรียมห้อง') || text.contains('support task')) {
      return Icons.handyman_outlined;
    }
    if (text.contains('ปัญหา') || text.contains('issue')) {
      return Icons.report_problem_outlined;
    }
    if (text.contains('อุปกรณ์') || text.contains('facility')) {
      return Icons.devices_other_outlined;
    }
    if (text.contains('อาหาร') || text.contains('food')) {
      return Icons.restaurant_menu_outlined;
    }
    if (text.contains('no-show') || text.contains('ไม่มา')) {
      return Icons.person_off_outlined;
    }
    if (text.contains('ประเมิน') || text.contains('feedback')) {
      return Icons.reviews_outlined;
    }
    if (text.contains('รายงาน') || text.contains('report')) {
      return Icons.analytics_outlined;
    }
    if (text.contains('ห้องประชุม') || text.contains('meeting room')) {
      return Icons.meeting_room_outlined;
    }
    if (text.contains('อาคาร') || text.contains('building')) {
      return Icons.apartment_outlined;
    }
    if (text.contains('สาขา') || text.contains('โครงสร้าง')) {
      return Icons.account_tree_outlined;
    }
    if (text.contains('พนักงาน') || text.contains('employee')) {
      return Icons.badge_outlined;
    }
    if (text.contains('ผู้ใช้งาน') || text.contains('user')) {
      return Icons.manage_accounts_outlined;
    }
    if (text.contains('สิทธิ์') || text.contains('permission')) {
      return Icons.verified_user_outlined;
    }
    if (text.contains('ตั้งค่า') || text.contains('setup')) {
      return Icons.settings_suggest_outlined;
    }
    if (text.contains('audit') || text.contains('ตรวจสอบ')) {
      return Icons.fact_check_outlined;
    }
    return Icons.apps_outlined;
  }
}
