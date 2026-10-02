import 'package:flutter_test/flutter_test.dart';
import 'package:laoo_document_control/document_control_feature.dart';

void main() {
  test('Document Control exposes eight implemented unique routes', () {
    expect(DocumentControlRoutes.all, hasLength(8));
    expect(DocumentControlRoutes.all.map((x) => x.menuCode).toSet(), hasLength(8));
    expect(DocumentControlRoutes.all.map((x) => x.routeName).toSet(), hasLength(8));
    expect(DocumentControlRoutes.all.map((x) => x.routePath).toSet(), hasLength(8));
    expect(DocumentControlRoutes.all.every((x) => x.isImplemented), isTrue);
  });

  test('ScreenType contract matches approved business flow', () {
    final byCode = {for (final route in DocumentControlRoutes.all) route.menuCode: route.screenType};
    expect(byCode[DocumentControlMenuCodes.settings], 2);
    expect(byCode[DocumentControlMenuCodes.types], 1);
    expect(byCode[DocumentControlMenuCodes.controlled], 4);
    expect(byCode[DocumentControlMenuCodes.approvals], 3);
    expect(byCode[DocumentControlMenuCodes.general], 1);
    expect(byCode[DocumentControlMenuCodes.library], 3);
    expect(byCode[DocumentControlMenuCodes.acknowledgements], 3);
    expect(byCode[DocumentControlMenuCodes.reports], 3);
  });
}
