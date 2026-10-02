import 'package:flutter_test/flutter_test.dart';
import 'package:laoo_knowledge/knowledge_feature.dart';

void main() {
  test('Knowledge Hub exposes eight unique implemented routes', () {
    expect(KnowledgeRoutes.all, hasLength(8));
    expect(KnowledgeRoutes.all.map((x) => x.menuCode).toSet(), hasLength(8));
    expect(KnowledgeRoutes.all.map((x) => x.routePath).toSet(), hasLength(8));
    expect(KnowledgeRoutes.all.every((x) => x.isImplemented), isTrue);
  });
  test('Knowledge ScreenType contract matches approved flow', () {
    final types = {
      for (final x in KnowledgeRoutes.all) x.menuCode: x.screenType,
    };
    expect(types, {
      '49001': 2,
      '49002': 1,
      '49003': 4,
      '49004': 2,
      '49005': 3,
      '49006': 1,
      '49007': 3,
      '49008': 3,
    });
  });
}
