import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laoo/core/widgets/list_display_preferences.dart';
import 'package:laoo/core/widgets/pinned_data_table.dart';

void main() {
  testWidgets('reorders, hides and moves actions without changing row values', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PinnedDataTable(
            columnKeys: ['id', 'action', 'name', 'status'],
            displayPreferences: ListDisplayPreferences(
              order: ['status', 'name'],
              hidden: {'status'},
              actionOnRight: true,
            ),
            columns: [
              DataColumn(label: Text('ID')),
              DataColumn(label: Text('Action')),
              DataColumn(label: Text('Name')),
              DataColumn(label: Text('Status')),
            ],
            rows: [
              DataRow(
                cells: [
                  DataCell(Text('1')),
                  DataCell(Text('Edit')),
                  DataCell(Text('Employee')),
                  DataCell(Text('Active')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.text('Status'), findsNothing);
    expect(find.text('Active'), findsNothing);
    expect(
      tester.getTopLeft(find.text('Name').first).dx,
      lessThan(tester.getTopLeft(find.text('Action').first).dx),
    );
    expect(find.text('Employee'), findsWidgets);
    expect(find.text('Edit'), findsWidgets);
  });
}
