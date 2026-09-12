import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';

void main() {
  const tokens = LaooWorkspaceUiTokens(
    contentMargin: EdgeInsets.all(10),
    cardPadding: EdgeInsets.all(10),
    sectionSpacing: 10,
    captionFilterSpacing: 6,
    itemSpacing: 6,
    radius: 4,
    compactBreakpoint: 900,
    paginationHeight: 56,
    captionStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
    sectionStyle: TextStyle(fontSize: 16),
    inputStyle: TextStyle(fontSize: 14),
    tableStyle: TextStyle(fontSize: 14),
    buttonStyle: TextStyle(fontSize: 13),
    buttonHeight: 48,
    primaryColor: Colors.teal,
    borderColor: Colors.grey,
    backgroundColor: Color(0xFFF8F9FB),
  );

  testWidgets(
    'keeps caption, filter, table and pagination as separate surfaces',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 640,
              child: LaooListWorkspace(
                tokens: tokens,
                caption: LaooCaptionCard(tokens: tokens, caption: 'ทะเบียน'),
                filter: Text('ตัวกรอง'),
                table: Center(child: Text('ตารางข้อมูล')),
                pagination: LaooPaginationCard(
                  tokens: tokens,
                  page: 2,
                  pageCount: 3,
                  pageSize: 20,
                  total: 45,
                  onPrevious: null,
                  onNext: null,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.text('ทะเบียน'), findsOneWidget);
      expect(find.text('ตัวกรอง'), findsOneWidget);
      expect(find.text('ตารางข้อมูล'), findsOneWidget);
      expect(find.text('21-40 จาก 45'), findsOneWidget);
      expect(find.byType(LaooSurfaceCard), findsNWidgets(4));
    },
  );
}
