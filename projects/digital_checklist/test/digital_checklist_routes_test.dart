import 'package:flutter_test/flutter_test.dart';
import 'package:laoo_digital_checklist/digital_checklist_feature.dart';

void main() {
  test('Digital Checklist route contract covers all 10 menu ScreenTypes', () {
    expect(DigitalChecklistRoutes.all.map((r) => r.menuCode).toList(), [
      '58001',
      '58002',
      '58003',
      '58004',
      '58005',
      '58006',
      '58007',
      '58008',
      '58009',
      '58010',
    ]);
    expect(DigitalChecklistRoutes.all.map((r) => r.screenType).toList(), [
      2,
      1,
      1,
      1,
      1,
      4,
      3,
      3,
      3,
      3,
    ]);
    expect(DigitalChecklistRoutes.all.every((r) => r.isImplemented), isTrue);
  });
}
