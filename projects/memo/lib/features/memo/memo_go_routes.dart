// ignore_for_file: curly_braces_in_flow_control_structures, unnecessary_underscores

import 'package:go_router/go_router.dart';
import 'memo_page.dart';
import 'memo_route_contract.dart';

List<GoRoute> buildMemoFeatureRoutes() => MemoRoutes.all
    .map(
      (route) => GoRoute(
        path: route.routePath,
        name: route.routeName,
        builder: (_, __) => MemoPage(
          menuCode: route.menuCode,
          fallbackTitle: _titles[route.menuCode]!,
        ),
      ),
    )
    .toList();
const _titles = <String, String>{
  '50001': 'ตั้งค่าระบบ Memo',
  '50002': 'ประเภทและเลขที่ Memo',
  '50003': 'สายอนุมัติ Memo',
  '50004': 'Template Memo',
  '50005': 'จัดทำ Memo',
  '50006': 'งานรออนุมัติ',
  '50007': 'กล่องรับ Memo',
  '50008': 'Memo ที่ส่งและประวัติ',
  '50009': 'Dashboard และรายงาน',
};
