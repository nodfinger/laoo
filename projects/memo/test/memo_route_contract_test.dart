import 'package:flutter_test/flutter_test.dart';
import 'package:laoo_memo/memo_feature.dart';

void main() {
  test(
    'Memo route contract has nine implemented routes and correct ScreenTypes',
    () {
      expect(MemoRoutes.all.length, 9);
      expect(MemoRoutes.all.map((e) => e.menuCode).toSet(), {
        '50001',
        '50002',
        '50003',
        '50004',
        '50005',
        '50006',
        '50007',
        '50008',
        '50009',
      });
      expect(MemoRoutes.all.every((e) => e.isImplemented), isTrue);
      expect(MemoRoutes.all.first.screenType, 2);
      expect(
        MemoRoutes.all
            .where((e) => ['50002', '50003', '50004'].contains(e.menuCode))
            .every((e) => e.screenType == 1),
        isTrue,
      );
      expect(
        MemoRoutes.all.singleWhere((e) => e.menuCode == '50005').screenType,
        4,
      );
      expect(
        MemoRoutes.all
            .where(
              (e) => ['50006', '50007', '50008', '50009'].contains(e.menuCode),
            )
            .every((e) => e.screenType == 3),
        isTrue,
      );
      expect(MemoRoutes.all.map((e) => e.routePath).toSet().length, 9);
    },
  );
}
