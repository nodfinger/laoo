import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laoo_service/core/widgets/pinned_data_table.dart';

void _ignoreSort(int _, bool _) {}

void main() {
  testWidgets('keeps heading fixed while rows scroll', (tester) async {
    tester.view.physicalSize = const Size(720, 420);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: PinnedDataTable(
              maxBodyHeight: 260,
              sortColumnIndex: 1,
              headingRowColor: const WidgetStatePropertyAll(Color(0xFFE2F7F4)),
              columns: const [
                LaooTableColumns.id,
                DataColumn(label: Text('ชื่อรายการ'), onSort: _ignoreSort),
                DataColumn(label: Text('สถานะ')),
              ],
              rows: List.generate(
                20,
                (index) => DataRow(
                  cells: [
                    DataCell(Text('${index + 1}')),
                    DataCell(Text('รายการ ${index + 1}')),
                    const DataCell(Text('เปิด')),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/pinned_data_table.png'),
    );
    final headerTop = tester.getTopLeft(find.text('ID').first).dy;
    final verticalScroll = find.byWidgetPredicate(
      (widget) =>
          widget is SingleChildScrollView &&
          widget.scrollDirection == Axis.vertical,
    );
    await tester.drag(verticalScroll, const Offset(0, -180));
    await tester.pump();

    expect(tester.getTopLeft(find.text('ID').first).dy, headerTop);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps header and rows aligned on narrow screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PinnedDataTable(
            maxBodyHeight: 280,
            columns: const [
              LaooTableColumns.id,
              DataColumn(
                label: Text('Action'),
                columnWidth: FixedColumnWidth(116),
              ),
              DataColumn(
                label: Text('รหัสรายการ'),
                columnWidth: FixedColumnWidth(172),
              ),
              DataColumn(
                label: Text('ชื่อรายการ'),
                columnWidth: FixedColumnWidth(240),
              ),
            ],
            rows: List.generate(
              8,
              (index) => DataRow(
                cells: [
                  DataCell(Text('${index + 1}')),
                  const DataCell(Text('แก้ไข')),
                  DataCell(Text('CODE-${index + 1}')),
                  DataCell(Text('รายการทดสอบ ${index + 1}')),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final headerX = tester.getTopLeft(find.text('ID').first).dx;
    final rowX = tester.getTopLeft(find.text('1').last).dx;
    final horizontalScroll = find.byWidgetPredicate(
      (widget) =>
          widget is SingleChildScrollView &&
          widget.scrollDirection == Axis.horizontal,
    );
    await tester.drag(horizontalScroll, const Offset(-180, 0));
    await tester.pump();

    expect(
      tester.getTopLeft(find.text('ID').first).dx - headerX,
      tester.getTopLeft(find.text('1').last).dx - rowX,
    );
    expect(tester.takeException(), isNull);
  });
}
