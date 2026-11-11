import 'package:flutter/foundation.dart';

/// Notifies open screens after the current user saves or resets settings.
final listDisplayPreferencesRevision = ValueNotifier<int>(0);

/// A screen's explicitly approved, user-configurable display field.
class ListDisplayField {
  const ListDisplayField({
    required this.key,
    required this.label,
    this.defaultVisible = true,
    this.requiredVisible = false,
  });

  final String key;
  final String label;
  final bool defaultVisible;
  final bool requiredVisible;
}

/// Fields that are safe to display on the AI capability registry screen.
const aiCapabilityDisplayFields = <ListDisplayField>[
  ListDisplayField(key: 'system', label: 'ระบบ'),
  ListDisplayField(key: 'menu', label: 'เมนู'),
  ListDisplayField(key: 'name', label: 'ชื่อ', requiredVisible: true),
  ListDisplayField(key: 'description', label: 'คำอธิบาย'),
  ListDisplayField(key: 'approvedBy', label: 'ผู้อนุมัติ'),
  ListDisplayField(key: 'approvedAt', label: 'วันที่-เวลาอนุมัติ'),
  ListDisplayField(key: 'status', label: 'สถานะ'),
];

/// Displayable master data fields; generated codes are intentionally hidden.
const masterDataDisplayFields = <ListDisplayField>[
  ListDisplayField(key: 'name', label: 'ชื่อ', requiredVisible: true),
  ListDisplayField(key: 'sequence', label: 'เรียงลำดับแสดง'),
  ListDisplayField(key: 'shortCode', label: 'รหัสย่อ'),
];

const travelClaimDisplayFields = <ListDisplayField>[
  ListDisplayField(key: 'number', label: 'เลขที่เอกสาร', requiredVisible: true),
  ListDisplayField(key: 'date', label: 'วันที่ทำรายการ'),
  ListDisplayField(key: 'department', label: 'แผนก'),
  ListDisplayField(key: 'claimant', label: 'ชื่อผู้ทำรายการ'),
  ListDisplayField(key: 'origin', label: 'ต้นทาง'),
  ListDisplayField(key: 'destination', label: 'ปลายทาง'),
  ListDisplayField(key: 'total', label: 'ยอดเบิกรวม'),
];

/// Preferences contain presentation keys only; authorization stays server-side.
class ListDisplayPreferences {
  const ListDisplayPreferences({
    this.order = const [],
    this.hidden = const {},
    this.actionOnRight = false,
  });

  final List<String> order;
  final Set<String> hidden;
  final bool actionOnRight;

  factory ListDisplayPreferences.fromJson(Map<String, dynamic> json) {
    Iterable<String> keys(Object? value) => value is List
        ? value.whereType<String>().where((key) => key.isNotEmpty)
        : const <String>[];
    return ListDisplayPreferences(
      order: keys(json['order']).toList(growable: false),
      hidden: keys(json['hidden']).toSet(),
      actionOnRight: json['actionOnRight'] == true,
    );
  }

  Map<String, Object> toJson() => {
    'order': order,
    'hidden': hidden.toList(growable: false),
    'actionOnRight': actionOnRight,
  };

  /// Keep existing choices while appending newly registered fields, and ignore
  /// stale or duplicate keys. Required fields can never be hidden.
  List<ListDisplayField> resolve(List<ListDisplayField> registered) {
    final fields = {for (final field in registered) field.key: field};
    final result = <ListDisplayField>[];
    final seen = <String>{};
    for (final key in [...order, ...registered.map((field) => field.key)]) {
      final field = fields[key];
      if (field != null && seen.add(key)) result.add(field);
    }
    if (identical(registered, travelClaimDisplayFields) && order.isNotEmpty) {
      var anchor = result.indexWhere((field) => field.key == 'date');
      for (final key in ['department', 'claimant']) {
        final existing = result.indexWhere((field) => field.key == key);
        if (existing < 0) continue;
        if (!order.contains(key) && anchor >= 0) {
          final field = result.removeAt(existing);
          if (existing < anchor) anchor--;
          result.insert(++anchor, field);
        } else if (existing >= 0) {
          anchor = existing;
        }
      }
    }
    return result;
  }

  bool isVisible(ListDisplayField field) {
    if (field.requiredVisible) return true;
    if (hidden.contains(field.key)) return false;
    return order.contains(field.key) || field.defaultVisible;
  }
}
