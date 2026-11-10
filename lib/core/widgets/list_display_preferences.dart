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
    return result;
  }

  bool isVisible(ListDisplayField field) {
    if (field.requiredVisible) return true;
    if (hidden.contains(field.key)) return false;
    return order.contains(field.key) || field.defaultVisible;
  }
}
