import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laoo_knowledge/features/knowledge/knowledge_feature_host.dart';
import 'package:laoo_knowledge/features/knowledge/knowledge_page.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';

void main() {
  setUpAll(() {
    configureKnowledgeFeatureHost(
      ({required pageTitle, required activeMenu, required child}) => child,
      apiClientFactory: _FakeApi.new,
      apiClientDisposer: (_) {},
      uiTokensProvider: () => const LaooWorkspaceUiTokens(
        contentMargin: EdgeInsets.all(8),
        cardPadding: EdgeInsets.all(10),
        sectionSpacing: 8,
        captionFilterSpacing: 8,
        itemSpacing: 8,
        radius: 4,
        compactBreakpoint: 900,
        paginationHeight: 52,
        captionStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        sectionStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        inputStyle: TextStyle(fontSize: 14),
        tableStyle: TextStyle(fontSize: 14),
        buttonStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        buttonHeight: 48,
        primaryColor: Color(0xff087f5b),
        borderColor: Color(0xffd9dfdc),
        backgroundColor: Color(0xfff5f7f6),
      ),
      menuTitleResolver: (_, fallback) async => fallback,
      messagePresenter: (_, {required message, required error}) {},
      upload: (_, {required fileName, required bytes, fields}) async => {},
    );
  });

  Future<void> pump(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff087f5b)),
          fontFamily: 'NotoSansThai',
        ),
        home: const Scaffold(
          body: KnowledgePage(
            menuCode: '49003',
            fallbackTitle: 'จัดการองค์ความรู้',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('desktop list has no overflow', (tester) async {
    await pump(tester, const Size(1200, 800));
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile cards and popup have no overflow', (tester) async {
    await pump(tester, const Size(430, 820));
    expect(tester.takeException(), isNull);
    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakeApi implements JsonApiClient {
  @override
  Future<dynamic> get(
    String path, {
    Map<String, String>? query,
    bool authenticated = true,
  }) async {
    if (path.contains('/actions/')) {
      return {'create': true, 'edit': true, 'delete': true, 'submit': true};
    }
    if (path.endsWith('/options')) {
      return {
        'categories': [
          {'id': 1, 'code': 'TECH', 'name': 'เทคโนโลยีและระบบ'},
        ],
        'users': [],
      };
    }
    if (path.contains('/articles/')) {
      return {
        'id': 1,
        'categoryId': 1,
        'title': 'คู่มือใช้งานระบบ',
        'summary': 'ตัวอย่างเนื้อหา',
        'contentType': 'ARTICLE',
        'bodyText': 'รายละเอียดตัวอย่าง',
        'status': 'DRAFT',
      };
    }
    if (path.contains('/articles')) {
      return {
        'items': [
          {
            'id': 1,
            'code': 'KN-DEMO',
            'title': 'คู่มือการใช้งานระบบสำหรับพนักงานใหม่และสาขาต่างจังหวัด',
            'summary': 'ขั้นตอนการใช้งานที่อ่านง่ายและค้นหาได้รวดเร็ว',
            'contentType': 'ARTICLE',
            'categoryName': 'เทคโนโลยีและระบบ',
            'status': 'DRAFT',
          },
          {
            'id': 2,
            'code': 'KN-VIDEO',
            'title': 'คลิปสาธิตการรับสินค้า',
            'summary': 'วิดีโอความรู้สำหรับผู้ปฏิบัติงาน',
            'contentType': 'VIDEO_URL',
            'categoryName': 'วิธีการทำงาน',
            'status': 'PUBLISHED',
          },
        ],
        'total': 2,
        'page': 1,
        'pageSize': 20,
      };
    }
    return {};
  }

  @override
  Future<dynamic> post(
    String path, {
    Object? body,
    bool authenticated = true,
  }) async => {'id': 99};
  @override
  Future<dynamic> put(
    String path, {
    Object? body,
    bool authenticated = true,
  }) async => {'id': 99};
  @override
  Future<dynamic> delete(
    String path, {
    Object? body,
    Map<String, String>? query,
    bool authenticated = true,
  }) async => null;
}
