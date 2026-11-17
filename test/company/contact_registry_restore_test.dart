import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laoo/core/api/api_client.dart';
import 'package:laoo/features/company/contact/contact_api.dart';
import 'package:laoo/features/company/contact/contact_page.dart';

class FakeRegistry implements ContactApi {
  String search = '';
  bool deleted = false;
  @override
  Future<Map<String, dynamic>> actions() async => {'create': true, 'edit': true, 'delete': true};
  @override
  Future<Map<String, dynamic>> list({required String search, required int page, int pageSize = 20}) async {
    this.search = search;
    return {'items': deleted ? [] : [{'contactId': 7, 'name': 'Test Contact', 'company': 'Test Corp', 'phone': '123', 'rowVersion': 'AA==', 'isActive': true}], 'total': deleted ? 0 : 1};
  }
  @override
  Future<Map<String, dynamic>> lookups({String search = '', int? personId, int? customerId}) async => {'persons': [], 'customers': []};
  @override
  Future<void> delete(int id, String rowVersion) async { if (id != 7 || rowVersion != 'AA==') throw StateError('wrong row'); deleted = true; }
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class RecordingClient extends ApiClient {
  String? path;
  Object? sentBody;
  @override
  Future<dynamic> put(String path, {Object? body, bool authenticated = true}) async { this.path = path; sentBody = body; }
}

void main() {
  testWidgets('contact registry retains list, search and delete', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = FakeRegistry();
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ContactRegistryPane(api: api, caption: 'Contacts'))));
    await tester.pumpAndSettle();
    expect(find.text('Test Contact'), findsOneWidget);
    expect(find.text('เพิ่ม'), findsOneWidget);
    expect(find.byTooltip('แก้ไข'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Test');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(api.search, 'Test');
    tester.testTextInput.hide();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byTooltip('ลบ'));
    await tester.tap(find.byTooltip('ลบ'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'ลบ'));
    await tester.pumpAndSettle();
    expect(api.deleted, isTrue);
    expect(find.text('Test Contact'), findsNothing);
  });

  for (final supplier in [false, true]) {
    test('draft update uses the correct endpoint and preserves association/version: supplier=$supplier', () async {
      final client = RecordingClient();
      final api = ContactApi(client: client, supplier: supplier);
      final contact = {'name': 'Name', 'customerId': 42, 'createCustomer': false, 'isActive': true, 'rowVersion': 'AQID'};
      await api.updateDraft(9, contact);
      expect(client.path, supplier ? '/api/company/supplier-contacts/ocr-drafts/9' : '/api/company/contacts/ocr-drafts/9');
      expect(client.sentBody, {'contact': contact});
      client.dispose();
    });
  }
}
