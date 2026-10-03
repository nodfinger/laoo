import 'package:go_router/go_router.dart';
import 'provider_page.dart';
import 'provider_portfolio_page.dart';
import 'provider_route_contract.dart';

List<GoRoute> buildProviderFeatureRoutes() => ProviderRoutes.all
    .map(
      (r) => GoRoute(
        path: r.routePath,
        name: r.routeName,
        builder: (_, __) => r.menuCode == ProviderMenuCodes.portfolio
            ? const ProviderPortfolioPage()
            : ProviderPage(
                menuCode: r.menuCode,
                fallbackTitle: _titles[r.menuCode]!,
              ),
      ),
    )
    .toList();
const _titles = <String, String>{
  '51001': 'ตั้งค่าระบบรวมช่างและผู้ให้บริการ',
  '51002': 'จังหวัด อำเภอ และตำบล',
  '51003': 'ประเภทบริการ',
  '51004': 'โปรไฟล์และพื้นที่ให้บริการ',
  '51005': 'อนุมัติผู้ให้บริการ',
  '51006': 'ลิงก์ประเมินบริการ',
  '51007': 'คะแนนและรีวิว',
  '51008': 'Dashboard และรายงาน',
  '51009': 'ผลงานที่ผ่านมา',
};
