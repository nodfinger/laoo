import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:flutter_test/flutter_test.dart';
import 'package:laoo_service/core/api/api_client.dart';
import 'package:laoo_service/features/service_request/data/service_request_api.dart';
import 'package:laoo_service/features/service_request/pages/service_request_page.dart';
import 'package:laoo_service/features/support/presentation/widgets/support_workspace_shell.dart';

void main() {
  Color? hostPrimary;
  setUpAll(() {
    configureServiceWorkspaceShell(
      ({
        required String pageTitle,
        required String activeMenu,
        required Widget child,
      }) => Theme(
        data: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: hostPrimary ?? Colors.green,
            primary: hostPrimary ?? Colors.green,
          ),
        ),
        child: Scaffold(body: child),
      ),
    );
  });

  Future<void> showPage(
    WidgetTester tester,
    _FakeRequestApi api, {
    Size size = const Size(1100, 800),
    ApiClient? subjectApi,
    bool selfService = true,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: ServiceRequestPage(
          selfService: selfService,
          api: api,
          subjectApi: subjectApi,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('selected attachment preview is visible in the add dialog', (
    tester,
  ) async {
    FilePicker.platform = _FakeImagePicker();
    await showPage(
      tester,
      _FakeRequestApi()..canCreate = true,
      size: const Size(1100, 800),
    );
    await tester.tap(find.text('แจ้งซ่อม').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('เลือกไฟล์'));
    await tester.tap(find.text('เลือกไฟล์'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('selected-test.png').hitTestable(),
      findsOneWidget,
    );
  });

  testWidgets('selected attachment preview is visible in the edit dialog', (
    tester,
  ) async {
    FilePicker.platform = _FakeImagePicker();
    await showPage(
      tester,
      _FakeRequestApi()..canEdit = true,
      size: const Size(1100, 800),
    );
    await tester.tap(find.byTooltip('แก้ไข'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('เลือกไฟล์'));
    await tester.tap(find.text('เลือกไฟล์'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('selected-test.png').hitTestable(),
      findsOneWidget,
    );
  });

  testWidgets('image larger than one MB is compressed and previewed', (
    tester,
  ) async {
    final image = img.Image(width: 700, height: 700);
    final random = Random(123);
    for (final pixel in image) {
      pixel.setRgb(
        random.nextInt(256),
        random.nextInt(256),
        random.nextInt(256),
      );
    }
    final bytes = Uint8List.fromList(img.encodePng(image));
    expect(bytes.length, greaterThan(1048576));
    FilePicker.platform = _FakeImagePicker(bytes: bytes);
    await showPage(tester, _FakeRequestApi()..canCreate = true);
    await tester.tap(find.text('แจ้งซ่อม').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('เลือกไฟล์'));
    await tester.tap(find.text('เลือกไฟล์'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('selected-test.jpg').hitTestable(),
      findsOneWidget,
    );
  });

  testWidgets('view-only subject permission opens lookup with locked actions', (
    tester,
  ) async {
    final subjects = _ViewOnlySubjectApi();
    final api = _FakeRequestApi()..canCreate = true;
    await showPage(tester, api, subjectApi: subjects);
    await tester.tap(find.text('แจ้งซ่อม').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('จัดการหัวข้อแจ้งซ่อม'));
    await tester.pumpAndSettle();
    expect(find.text('ระบบประปา'), findsOneWidget);
    expect(find.text('เพิ่ม'), findsNothing);
    expect(find.byIcon(Icons.lock_outline), findsNWidgets(2));
    final buttons = tester.widgetList<IconButton>(find.byType(IconButton));
    final locks = buttons.where(
      (b) => b.icon is Icon && (b.icon as Icon).icon == Icons.lock_outline,
    );
    expect(locks.every((b) => b.onPressed == null), isTrue);
    expect(subjects.writes, 0);
  });

  testWidgets('choosing a subject from lookup updates the combo', (
    tester,
  ) async {
    final subjects = _ViewOnlySubjectApi();
    final api = _FakeRequestApi()..canCreate = true;
    await showPage(tester, api, subjectApi: subjects);
    await tester.tap(find.text('แจ้งซ่อม').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('จัดการหัวข้อแจ้งซ่อม'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ระบบประปา').last);
    await tester.pumpAndSettle();
    expect(find.text('ระบบประปา'), findsOneWidget);
    expect(find.text('หัวข้อแจ้งซ่อม'), findsNothing);
    expect(subjects.writes, 0);
  });

  testWidgets('edit subject lookup selects value without write permission', (
    tester,
  ) async {
    final subjects = _ViewOnlySubjectApi();
    final api = _FakeRequestApi()..canEdit = true;
    await showPage(tester, api, subjectApi: subjects);
    await tester.tap(find.byTooltip('\u0e41\u0e01\u0e49\u0e44\u0e02'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byTooltip(
        '\u0e04\u0e49\u0e19\u0e2b\u0e32\u0e2b\u0e31\u0e27\u0e02\u0e49\u0e2d',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.lock_outline), findsNWidgets(2));
    await tester.tap(
      find.text('\u0e23\u0e30\u0e1a\u0e1a\u0e1b\u0e23\u0e30\u0e1b\u0e32').last,
    );
    await tester.pumpAndSettle();
    expect(
      find.text('\u0e23\u0e30\u0e1a\u0e1a\u0e1b\u0e23\u0e30\u0e1b\u0e32'),
      findsOneWidget,
    );
    expect(subjects.writes, 0);
  });

  testWidgets(
    'editing equipment supports searching and saves the selected item',
    (tester) async {
      final api = _FakeRequestApi()..canEdit = true;
      await showPage(tester, api);
      await tester.tap(find.byTooltip('\u0e41\u0e01\u0e49\u0e44\u0e02'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byTooltip(
          '\u0e04\u0e49\u0e19\u0e2b\u0e32 \u0e2d\u0e38\u0e1b\u0e01\u0e23\u0e13\u0e4c\u0e17\u0e35\u0e48\u0e41\u0e08\u0e49\u0e07\u0e0b\u0e48\u0e2d\u0e21',
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Pump');
      await tester.pumpAndSettle();
      expect(api.equipmentSearch, 'Pump');
      await tester.tap(find.text('EQ09 | Pump').last);
      await tester.pumpAndSettle();
      expect(find.text('EQ09 | Pump'), findsOneWidget);
      await tester.tap(
        find
            .widgetWithText(
              FilledButton,
              '\u0e1a\u0e31\u0e19\u0e17\u0e36\u0e01',
            )
            .last,
      );
      await tester.pumpAndSettle();
      expect(api.updatedEquipment, 9);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('requester search includes nickname and department', (
    tester,
  ) async {
    final api = _FakeRequestApi()..canCreate = true;
    await showPage(tester, api, selfService: false);
    await tester.tap(find.byIcon(Icons.add).last);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byTooltip(
        '\u0e04\u0e49\u0e19\u0e2b\u0e32 \u0e1c\u0e39\u0e49\u0e41\u0e08\u0e49\u0e07',
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Jan');
    await tester.pumpAndSettle();
    expect(api.requesterSearch, 'Jan');
    expect(
      find.textContaining('Jane Doe (Jan) | IT / Support'),
      findsOneWidget,
    );
    await tester.tap(find.textContaining('Jane Doe (Jan) | IT / Support'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Jane Doe (Jan) | IT / Support'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('subject search returns selected subject in add form', (
    tester,
  ) async {
    final api = _FakeRequestApi()..canCreate = true;
    await showPage(tester, api);
    await tester.tap(find.byIcon(Icons.add).last);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byTooltip(
        '\u0e04\u0e49\u0e19\u0e2b\u0e32 \u0e2b\u0e31\u0e27\u0e02\u0e49\u0e2d',
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).last,
      '\u0e1b\u0e23\u0e30\u0e1b\u0e32',
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.text('\u0e23\u0e30\u0e1a\u0e1a\u0e1b\u0e23\u0e30\u0e1b\u0e32').last,
    );
    await tester.pumpAndSettle();
    expect(
      find.text('\u0e23\u0e30\u0e1a\u0e1a\u0e1b\u0e23\u0e30\u0e1b\u0e32'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('priority filter sends selected code to server', (tester) async {
    final api = _FakeRequestApi();
    await showPage(tester, api);
    await tester.tap(find.byKey(const ValueKey('priority-filter-')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.text('\u0e14\u0e48\u0e27\u0e19\u0e21\u0e32\u0e01').last,
    );
    await tester.pumpAndSettle();
    expect(api.filteredPriority, '2');
  });

  testWidgets('list controls and edit popup use the hosted user theme', (
    tester,
  ) async {
    hostPrimary = Colors.deepPurple;
    addTearDown(() => hostPrimary = null);
    final api = _FakeRequestApi()..canEdit = true;
    await showPage(tester, api);
    final toggle = tester.widget<Icon>(
      find.descendant(
        of: find.byTooltip('แสดงแบบการ์ด'),
        matching: find.byType(Icon),
      ),
    );
    expect(toggle.color, Colors.deepPurple);
    final currentPage = tester.widget<FilledButton>(
      find
          .ancestor(of: find.text('1'), matching: find.byType(FilledButton))
          .first,
    );
    expect(
      currentPage.style!.backgroundColor!.resolve({WidgetState.disabled}),
      Colors.deepPurple,
    );
    final star = tester.widget<Icon>(
      find.descendant(
        of: find.byTooltip('เพิ่มหน้านี้เป็นเมนูลัดของฉัน'),
        matching: find.byType(Icon),
      ),
    );
    expect(star.color, Colors.deepPurple);
    final edit = tester.widget<Icon>(
      find.descendant(of: find.byTooltip('แก้ไข'), matching: find.byType(Icon)),
    );
    expect(edit.color, Colors.deepPurple);
    await tester.tap(find.byTooltip('แสดงแบบการ์ด'));
    await tester.pumpAndSettle();
    final cardToggle = tester.widget<Icon>(
      find.descendant(
        of: find.byTooltip('แสดงแบบตาราง'),
        matching: find.byType(Icon),
      ),
    );
    expect(cardToggle.color, Colors.deepPurple);
    await tester.tap(find.byTooltip('แก้ไข'));
    await tester.pumpAndSettle();
    final icon = tester.widget<Icon>(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byIcon(Icons.edit_outlined),
      ),
    );
    expect(icon.color, Colors.deepPurple);
  });

  testWidgets('add popup uses the hosted user theme', (tester) async {
    hostPrimary = Colors.cyan;
    addTearDown(() => hostPrimary = null);
    final api = _FakeRequestApi()..canCreate = true;
    await showPage(tester, api);
    await tester.tap(find.text('แจ้งซ่อม').last);
    await tester.pumpAndSettle();
    final icon = tester.widget<Icon>(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byIcon(Icons.build_outlined),
      ),
    );
    expect(icon.color, Colors.cyan);
    expect(tester.takeException(), isNull);
  });

  testWidgets('self page hides edit and delete without login permissions', (
    tester,
  ) async {
    final api = _FakeRequestApi();
    await showPage(tester, api);
    expect(find.byTooltip('แก้ไข'), findsNothing);
    expect(find.byTooltip('ลบ'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('self page shows edit and delete only on CRUD ScreenType', (
    tester,
  ) async {
    final api = _FakeRequestApi()
      ..canEdit = true
      ..canDelete = true;
    await showPage(tester, api);
    expect(find.byTooltip('แก้ไข'), findsOneWidget);
    expect(find.byTooltip('ลบ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('self page hides mutations when ScreenType is not CRUD', (
    tester,
  ) async {
    final api = _FakeRequestApi()
      ..screenType = 3
      ..canEdit = true
      ..canDelete = true;
    await showPage(tester, api);
    expect(find.byTooltip('แก้ไข'), findsNothing);
    expect(find.byTooltip('ลบ'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('self page honors per-row edit and delete scope', (tester) async {
    final api = _FakeRequestApi()
      ..canEdit = true
      ..canDelete = true
      ..rowCanEdit = true
      ..rowCanDelete = false;
    await showPage(tester, api);
    expect(find.byTooltip('แก้ไข'), findsOneWidget);
    expect(find.byTooltip('ลบ'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('self page shows delete only when row permits it', (
    tester,
  ) async {
    final api = _FakeRequestApi()
      ..canEdit = true
      ..canDelete = true
      ..rowCanEdit = false
      ..rowCanDelete = true;
    await showPage(tester, api);
    expect(find.byTooltip('แก้ไข'), findsNothing);
    expect(find.byTooltip('ลบ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('self delete confirms and calls owner-scoped API', (
    tester,
  ) async {
    final api = _FakeRequestApi()..canDelete = true;
    await showPage(tester, api);
    await tester.tap(find.byTooltip('ลบ'));
    await tester.pumpAndSettle();
    expect(find.text('ลบแล้วไม่สามารถเรียกคืนได้'), findsOneWidget);
    await tester.tap(find.text('ลบ').last);
    await tester.pumpAndSettle();
    expect(api.deletedId, 42);
    expect(api.deletedAsSelf, true);
    expect(tester.takeException(), isNull);
  });

  testWidgets('self edit saves through owner-scoped API', (tester) async {
    final api = _FakeRequestApi()..canEdit = true;
    await showPage(tester, api);
    await tester.tap(find.byTooltip('แก้ไข'));
    await tester.pumpAndSettle();
    expect(find.textContaining('> แก้ไข'), findsOneWidget);
    await tester.tap(find.text('บันทึก'));
    await tester.pumpAndSettle();
    expect(api.editedId, 42);
    expect(api.editedAsSelf, true);
    expect(tester.takeException(), isNull);
  });

  testWidgets('priority can be changed when editing a new request', (
    tester,
  ) async {
    final api = _FakeRequestApi()..canEdit = true;
    await showPage(tester, api);
    await tester.tap(find.byTooltip('แก้ไข'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ปกติ').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('ด่วนมาก').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('บันทึก'));
    await tester.pumpAndSettle();
    expect(api.editedPriority, '2');
  });

  testWidgets('attached images appear in list and edit without changes', (
    tester,
  ) async {
    final api = _FakeRequestApi()
      ..canEdit = true
      ..hasImages = true;
    await showPage(tester, api);
    expect(find.byTooltip('ดูรูปแนบ'), findsOneWidget);
    await tester.tap(find.byTooltip('ดูรูปแนบ'));
    await tester.pumpAndSettle();
    expect(find.text('รูปที่หนึ่ง.png'), findsOneWidget);
    expect(find.text('รูปที่สอง.png'), findsOneWidget);
    await tester.tap(find.text('ปิด').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('แก้ไข'));
    await tester.pumpAndSettle();
    expect(find.text('รูปที่หนึ่ง.png'), findsOneWidget);
    expect(find.text('รูปที่สอง.png'), findsOneWidget);
    expect(api.lastAttachmentMenuCode, '20001');
    expect(tester.takeException(), isNull);
  });

  testWidgets('request without images has no image action', (tester) async {
    await showPage(tester, _FakeRequestApi());
    expect(find.byTooltip('ดูรูปแนบ'), findsNothing);
  });

  testWidgets('editing an image requires confirmation and owner scope', (
    tester,
  ) async {
    final api = _FakeRequestApi()
      ..canEdit = true
      ..hasImages = true;
    await showPage(tester, api);
    await tester.tap(find.byTooltip('แก้ไข'));
    await tester.pumpAndSettle();
    expect(find.text('เลือกไฟล์'), findsOneWidget);
    await tester.ensureVisible(find.byIcon(Icons.delete_outline).last);
    await tester.tap(find.byIcon(Icons.delete_outline).last);
    await tester.pumpAndSettle();
    expect(find.text('ยืนยันการลบข้อมูล'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'ลบ'));
    await tester.pumpAndSettle();
    expect(api.deletedAttachmentId, 2);
    expect(api.attachmentDeleteSelf, isTrue);
    expect(find.text('รูปที่สอง.png'), findsNothing);
    expect(find.text('รูปที่หนึ่ง.png'), findsOneWidget);
  });

  testWidgets('mobile card opens image gallery without overflow', (
    tester,
  ) async {
    final api = _FakeRequestApi()
      ..canEdit = true
      ..canDelete = true
      ..hasImages = true;
    await showPage(tester, api, size: const Size(390, 700));
    await tester.tap(find.byTooltip('ดูรูปแนบ'));
    await tester.pumpAndSettle();
    expect(find.text('รูปที่หนึ่ง.png'), findsOneWidget);
    expect(find.text('รูปที่สอง.png'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile card keeps self actions without overflow', (
    tester,
  ) async {
    final api = _FakeRequestApi()
      ..canEdit = true
      ..canDelete = true;
    await showPage(tester, api, size: const Size(390, 700));
    expect(find.byTooltip('แก้ไข'), findsOneWidget);
    expect(find.byTooltip('ลบ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('switching list and card preserves the request and permissions', (
    tester,
  ) async {
    final api = _FakeRequestApi()..canEdit = true;
    await showPage(tester, api);
    expect(find.text('SR42'), findsOneWidget);
    expect(find.text('Test Printer'), findsOneWidget);
    expect(find.text('SN-123'), findsOneWidget);
    expect(find.byTooltip('แก้ไข'), findsOneWidget);
    await tester.tap(find.byTooltip('แสดงแบบการ์ด'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('แสดงแบบตาราง'), findsOneWidget);
    expect(find.text('SR42'), findsOneWidget);
    expect(find.textContaining('Test Printer'), findsOneWidget);
    expect(find.text('Serial: SN-123'), findsOneWidget);
    expect(find.byTooltip('แก้ไข'), findsOneWidget);
    await tester.tap(find.byTooltip('แสดงแบบตาราง'));
    await tester.pumpAndSettle();
    expect(find.text('SR42'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakeImagePicker extends FilePicker {
  _FakeImagePicker({this.bytes});
  final Uint8List? bytes;
  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = false,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async {
    final resultBytes =
        bytes ??
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/aZkAAAAASUVORK5CYII=',
        );
    return FilePickerResult([
      PlatformFile(
        name: 'selected-test.png',
        size: resultBytes.length,
        bytes: resultBytes,
      ),
    ]);
  }
}

class _ViewOnlySubjectApi extends ApiClient {
  int writes = 0;
  @override
  Future<dynamic> get(
    String path, {
    Map<String, String>? query,
    bool authenticated = true,
  }) async {
    if (path.endsWith('/actions')) {
      return {'view': true, 'create': false, 'edit': false, 'delete': false};
    }
    return [
      {
        'id': 1,
        'code': '001',
        'name': 'ระบบประปา',
        'seq': 1,
        'isActive': true,
        'isShared': false,
      },
    ];
  }

  @override
  Future<dynamic> put(
    String path, {
    Object? body,
    bool authenticated = true,
  }) async {
    writes++;
  }

  @override
  Future<dynamic> delete(
    String path, {
    Object? body,
    Map<String, String>? query,
    bool authenticated = true,
  }) async {
    writes++;
  }
}

class _FakeRequestApi extends ServiceRequestApi {
  @override
  Future<Map<String, dynamic>> uploadAttachment(
    int requestId, {
    required String fileName,
    required List<int> bytes,
    bool editSelf = false,
    bool editNew = false,
  }) async => {
    'attachmentId': 3,
    'fileName': fileName,
    'contentType': 'image/png',
    'fileSize': bytes.length,
  };
  int? updatedEquipment;
  String? equipmentSearch;
  String? requesterSearch;
  @override
  Future<void> editEquipment(
    int id, {
    required bool selfService,
    required String subject,
    required String detail,
    required String rowVersion,
    required String priorityCode,
    required int? equipmentItemId,
    String? equipmentSerial,
    bool updateSerial = false,
  }) async {
    updatedEquipment = equipmentItemId;
  }

  @override
  Future<List<Map<String, dynamic>>> equipmentOptions({
    required bool selfService,
    String search = '',
  }) async {
    equipmentSearch = search;
    return [
      {'itemID': 9, 'itemCode': 'EQ09', 'itemName': 'Pump'},
    ];
  }

  String? filteredPriority;
  @override
  Future<Map<String, dynamic>> filteredList({
    required String search,
    required String status,
    required bool selfService,
    required int page,
    required String menuCode,
    required String priority,
  }) async {
    filteredPriority = priority;
    return list(
      search: search,
      status: status,
      selfService: selfService,
      page: page,
      menuCode: menuCode,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> subjectOptions({
    required bool selfService,
  }) async => List<Map<String, dynamic>>.from(
    (await lookup(selfService: selfService))['subjects'] as List,
  );

  int screenType = 1;
  bool canEdit = false;
  bool rowCanEdit = true;
  bool rowCanDelete = true;
  bool canCreate = false;
  bool canDelete = false;
  bool hasImages = false;
  String? lastAttachmentMenuCode;
  int? deletedId;
  bool? deletedAsSelf;
  int? editedId;
  bool? editedAsSelf;
  String? editedPriority;
  int? deletedAttachmentId;
  bool? attachmentDeleteSelf;

  @override
  Future<void> deleteAttachment(
    int requestId,
    int attachmentId, {
    bool editSelf = false,
    bool editNew = false,
  }) async {
    deletedAttachmentId = attachmentId;
    attachmentDeleteSelf = editSelf && editNew;
  }

  @override
  Future<List<Map<String, dynamic>>> priorities() async => [
    {'code': '0', 'name': 'ปกติ'},
    {'code': '1', 'name': 'ด่วน'},
    {'code': '2', 'name': 'ด่วนมาก'},
  ];

  @override
  Future<Map<String, dynamic>> actions() async => {
    'screenType': screenType,
    'create': canCreate,
    'edit': canEdit,
    'delete': canDelete,
    'selfScreenType': screenType,
    'selfCreate': canCreate,
    'selfEdit': canEdit,
    'selfDelete': canDelete,
  };

  @override
  Future<Map<String, dynamic>> lookup({
    String search = '',
    bool selfService = false,
  }) async {
    requesterSearch = search;
    return {
      'subjects': [
        {'code': '001', 'name': 'ระบบประปา'},
      ],
      'requesters': [
        {
          'id': 55,
          'requesterType': 'EMPLOYEE',
          'name': 'Jane Doe',
          'nickName': 'Jan',
          'locationSnapshot': 'IT / Support',
        },
      ],
      'equipment': [
        {'itemID': 9, 'itemCode': 'EQ09', 'itemName': 'Pump'},
      ],
    };
  }

  @override
  Future<Map<String, dynamic>> list({
    String search = '',
    String status = '',
    bool selfService = false,
    int page = 1,
    String? menuCode,
  }) async => {
    'items': deletedId == null
        ? [
            {
              'requestId': 42,
              'requestNo': 'SR42',
              'equipmentName': 'Test Printer',
              'equipmentSerial': 'SN-123',
              'requesterName': 'ผู้แจ้ง',
              'subject': 'ไฟไม่ติด',
              'statusCode': 'NEW',
              'selfCanEdit': rowCanEdit,
              'selfCanDelete': rowCanDelete,
              'requestDate': '2026-09-29',
              'hasImages': hasImages,
            },
          ]
        : <Map<String, dynamic>>[],
    'total': deletedId == null ? 1 : 0,
  };

  @override
  Future<Map<String, dynamic>> detail(int id, {String? menuCode}) async => {
    'requestId': id,
    'requestNo': 'SR42',
    'requesterName': 'ผู้แจ้ง',
    'subject': 'ไฟไม่ติด',
    'detail': 'ห้อง 101',
    'statusCode': 'NEW',
    'rowVersion': 'version',
  };

  @override
  Future<List<Map<String, dynamic>>> attachments(
    int requestId, {
    String? menuCode,
  }) async {
    lastAttachmentMenuCode = menuCode;
    return hasImages
        ? [
            {
              'attachmentId': 1,
              'fileName': 'รูปที่หนึ่ง.png',
              'contentType': 'image/png',
            },
            {
              'attachmentId': 2,
              'fileName': 'รูปที่สอง.png',
              'contentType': 'image/png',
            },
          ]
        : [];
  }

  @override
  Future<List<int>> downloadAttachment(
    int requestId,
    int attachmentId, {
    String? menuCode,
  }) async {
    lastAttachmentMenuCode = menuCode;
    return base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/aZkAAAAASUVORK5CYII=',
    );
  }

  @override
  Future<void> delete(
    int id,
    String rowVersion, {
    required bool selfService,
  }) async {
    deletedId = id;
    deletedAsSelf = selfService;
  }

  @override
  Future<void> edit(
    int id, {
    required bool selfService,
    required String subject,
    required String detail,
    required String rowVersion,
    String? priorityCode,
  }) async {
    editedId = id;
    editedAsSelf = selfService;
    editedPriority = priorityCode;
  }
}
