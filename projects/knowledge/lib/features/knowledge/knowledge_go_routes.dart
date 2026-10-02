import 'package:go_router/go_router.dart';
import 'knowledge_page.dart';
import 'knowledge_route_contract.dart';

List<GoRoute> buildKnowledgeFeatureRoutes() => KnowledgeRoutes.all
    .map(
      (r) => GoRoute(
        path: r.routePath,
        name: r.routeName,
        builder: (_, _) => KnowledgePage(
          menuCode: r.menuCode,
          fallbackTitle: _fallback(r.menuCode),
        ),
      ),
    )
    .toList();

String _fallback(String code) => const {
  '49001': 'ตั้งค่าระบบความรู้',
  '49002': 'หมวดความรู้และผู้เชี่ยวชาญ',
  '49003': 'จัดการองค์ความรู้',
  '49004': 'งานตรวจทานความรู้',
  '49005': 'คลังความรู้',
  '49006': 'ถาม–ตอบผู้เชี่ยวชาญ',
  '49007': 'ความรู้ของฉัน',
  '49008': 'Dashboard และรายงาน',
}[code]!;
