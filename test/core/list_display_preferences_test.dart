import 'package:flutter_test/flutter_test.dart';
import 'package:laoo/core/widgets/list_display_preferences.dart';

void main() {
  const fields = [
    ListDisplayField(key: 'name', label: 'ชื่อ', requiredVisible: true),
    ListDisplayField(key: 'status', label: 'สถานะ'),
    ListDisplayField(key: 'date', label: 'วันที่', defaultVisible: false),
  ];

  test('preserves order and adds new fields while ignoring stale keys', () {
    const preferences = ListDisplayPreferences(
      order: ['status', 'removed', 'status', 'name'],
      hidden: {'status', 'name'},
    );
    final resolved = preferences.resolve(fields);
    expect(resolved.map((field) => field.key), ['status', 'name', 'date']);
    expect(preferences.isVisible(fields[0]), isTrue);
    expect(preferences.isVisible(fields[1]), isFalse);
    expect(preferences.isVisible(fields[2]), isFalse);
  });

  test('empty preferences restore central defaults', () {
    const preferences = ListDisplayPreferences();
    expect(preferences.resolve(fields).map((field) => field.key), [
      'name',
      'status',
      'date',
    ]);
    expect(preferences.isVisible(fields[0]), isTrue);
    expect(preferences.isVisible(fields[1]), isTrue);
    expect(preferences.isVisible(fields[2]), isFalse);
    expect(preferences.actionOnRight, isFalse);
  });

  test(
    'preferences survive JSON conversion and invalid values are ignored',
    () {
      final preferences = ListDisplayPreferences.fromJson({
        'order': ['status', 42, 'name'],
        'hidden': ['status', null],
        'actionOnRight': true,
      });
      expect(preferences.order, ['status', 'name']);
      expect(preferences.hidden, {'status'});
      expect(preferences.actionOnRight, isTrue);
      expect(
        ListDisplayPreferences.fromJson(preferences.toJson()).order,
        preferences.order,
      );
    },
  );
}
