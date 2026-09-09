import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:laoo_meeting/core/api/api_client.dart';
import 'package:laoo_meeting/core/api/api_exception.dart';
import 'package:laoo_meeting/features/meeting/data/meeting_attendance_repository.dart';
import 'package:laoo_meeting/features/meeting/widgets/meeting_attendance_panel.dart';
import 'package:laoo_meeting/features/meeting/widgets/meeting_food_receipt_panel.dart';
import 'package:laoo_meeting/features/meeting/widgets/meeting_qr_scanner.dart';

class TestApi extends ApiClient {
  final calls = <({String method, String path, Object? body})>[];
  FutureOr<dynamic> Function(String path)? onGet;
  FutureOr<dynamic> Function(String path, Object? body)? onPut;
  FutureOr<dynamic> Function(String path, Object? body)? onPost;
  @override
  Future<dynamic> get(
    String path, {
    Map<String, String>? query,
    bool authenticated = true,
  }) async {
    expect(authenticated, isTrue);
    calls.add((method: 'GET', path: path, body: null));
    return onGet!(path);
  }

  @override
  Future<dynamic> put(
    String path, {
    Object? body,
    bool authenticated = true,
  }) async {
    expect(authenticated, isTrue);
    calls.add((method: 'PUT', path: path, body: body));
    return onPut!(path, body);
  }

  @override
  Future<dynamic> post(
    String path, {
    Object? body,
    bool authenticated = true,
  }) async {
    expect(authenticated, isTrue);
    calls.add((method: 'POST', path: path, body: body));
    return onPost!(path, body);
  }
}

Map<String, dynamic> row({
  int participant = 11,
  int slot = 7,
  bool checked = false,
  Map<String, dynamic> flags = const {},
}) => {
  'participantId': participant,
  'participantName': 'ผู้เข้าร่วม $participant',
  'slotId': slot,
  'startDateTime': '2026-09-08T09:00:00',
  'endDateTime': '2026-09-08T12:00:00',
  'checkInDate': checked ? '2026-09-08T02:00:00Z' : null,
  'checkInByUserId': checked ? 21 : null,
  'method': checked ? 'QR_SELF' : null,
  'canCheckIn': true,
  ...flags,
};

Map<String, dynamic> checkedResult() => {
  'bookingId': 3,
  'participantId': 11,
  'slotId': 7,
  'checkInDate': '2026-09-08T02:00:00Z',
  'checkInByUserId': 21,
  'method': 'SELF',
};

Map<String, dynamic> receipt({
  int received = 1,
  int ordered = 3,
  bool checked = true,
  bool canReceive = true,
}) => {
  'bookingId': 3,
  'participantId': 11,
  'slotId': 7,
  'checkInDate': checked ? '2026-09-08T02:00:00Z' : null,
  'canReceive': canReceive,
  'items': [
    {
      'foodOrderDetailId': 91,
      'foodId': 2,
      'foodName': 'ข้าวกล่อง',
      'orderedQuantity': ordered,
      'receivedQuantity': received,
      'remainingQuantity': ordered - received,
      'receivedByUserId': received > 0 ? 21 : null,
      'receivedAtUtc': received > 0 ? '2026-09-08T02:05:00Z' : null,
      'receiptSlotId': received > 0 ? 6 : null,
    },
  ],
};

Widget shell(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  late TestApi api;
  late MeetingAttendanceRepository repository;
  late List<({String message, bool error})> messages;

  setUp(() {
    api = TestApi();
    repository = MeetingAttendanceRepository(api: api);
    messages = [];
  });
  tearDown(() {
    repository.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  void notify(String message, bool error) =>
      messages.add((message: message, error: error));
  Widget panel({int booking = 3, int? participant, int? slot}) => shell(
    MeetingAttendancePanel(
      bookingId: booking,
      participantId: participant,
      slotId: slot,
      repository: repository,
      onMessage: notify,
    ),
  );

  testWidgets('manager detail displays only the selected booking slot', (
    tester,
  ) async {
    api.onGet = (_) => {
      'items': [row(slot: 7), row(participant: 12, slot: 8)],
    };
    await tester.pumpWidget(panel(slot: 8));
    await tester.pumpAndSettle();
    expect(find.text('ผู้เข้าร่วม 11'), findsNothing);
    expect(find.text('ผู้เข้าร่วม 12'), findsOneWidget);
  });
  Widget receiptPanel() => shell(
    MeetingFoodReceiptPanel(
      repository: repository,
      bookingId: 3,
      participantId: 11,
      slotId: 7,
      participantName: 'ผู้เข้าร่วม 11',
      onMessage: notify,
      onClose: () {},
      onSaving: (_) {},
    ),
  );

  testWidgets(
    'optional attendance panel stays hidden when schema is unavailable',
    (tester) async {
      api.onGet = (_) => {'available': false, 'items': <Object>[]};
      await tester.pumpWidget(panel());
      await tester.pumpAndSettle();
      expect(find.text('เช็กอินผู้เข้าร่วม'), findsNothing);
      expect(messages, isEmpty);
    },
  );

  testWidgets('legacy canCheckIn never grants QR or manual capabilities', (
    tester,
  ) async {
    api.onGet = (_) => {
      'items': [row()],
    };
    await tester.pumpWidget(panel());
    await tester.pumpAndSettle();
    expect(find.byType(MeetingQrScanner), findsNothing);
    expect(find.byType(MobileScanner), findsNothing);
    expect(find.byKey(const ValueKey('room-qr-7')), findsNothing);
    expect(find.byKey(const ValueKey('personal-qr-11-7')), findsNothing);
    expect(find.byKey(const ValueKey('manual-check-in-11-7')), findsNothing);
  });

  testWidgets(
    'QR flags independently gate actions and deduplicate room slots',
    (tester) async {
      api.onGet = (_) => {
        'items': [
          row(flags: {'canIssueRoomQr': true, 'canIssuePersonalQr': true}),
          row(participant: 12, flags: {'canIssueRoomQr': true}),
        ],
      };
      api.onPost = (path, body) => {
        'bookingId': 3,
        'slotId': 7,
        'participantId': 11,
        'kind': 'PERSONAL',
        'token': 'opaque-personal-qr',
        'expiresAtUtc': DateTime.now()
            .toUtc()
            .add(const Duration(minutes: 10))
            .toIso8601String(),
      };
      await tester.pumpWidget(panel());
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('room-qr-7')), findsOneWidget);
      expect(find.byKey(const ValueKey('personal-qr-12-7')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('personal-qr-11-7')));
      await tester.pumpAndSettle();
      expect(
        api.calls.last.path,
        '${MeetingAttendanceRepository.path}/3/7/qr-token',
      );
      expect(api.calls.last.body, {'kind': 'PERSONAL', 'participantId': 11});
      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.byType(MobileScanner), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('expired QR contents are hidden', (tester) async {
    api.onGet = (_) => {
      'items': [
        row(flags: {'canIssueRoomQr': true}),
      ],
    };
    api.onPost = (_, _) => {
      'bookingId': 3,
      'slotId': 7,
      'participantId': null,
      'kind': 'ROOM',
      'token': 'expired',
      'expiresAtUtc': '2020-01-01T00:00:00Z',
    };
    await tester.pumpWidget(panel());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('room-qr-7')));
    await tester.pumpAndSettle();
    expect(api.calls.last.body, {'kind': 'ROOM'});
    expect(find.byType(QrImageView), findsNothing);
    expect(find.textContaining('QR หมดอายุแล้ว'), findsOneWidget);
  });

  testWidgets('invitation participant filter prevents mixing invitations', (
    tester,
  ) async {
    api.onGet = (_) => {
      'items': [row(), row(participant: 12)],
    };
    await tester.pumpWidget(panel(participant: 11));
    await tester.pumpAndSettle();
    expect(find.text('ผู้เข้าร่วม 11'), findsOneWidget);
    expect(find.text('ผู้เข้าร่วม 12'), findsNothing);
  });

  testWidgets(
    'manual/self check-in opens independent receipt without issuing food',
    (tester) async {
      var checked = false;
      api.onGet = (path) => path.endsWith('food-receipt')
          ? receipt(received: 0)
          : {
              'items': [
                row(checked: checked, flags: {'canManualCheckIn': !checked}),
              ],
            };
      api.onPut = (_, _) {
        checked = true;
        return checkedResult();
      };
      await tester.pumpWidget(panel());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('manual-check-in-11-7')));
      await tester.pumpAndSettle();
      expect(find.byType(MeetingFoodReceiptPanel), findsOneWidget);
      final writes = api.calls.where((call) => call.method == 'PUT').toList();
      expect(writes, hasLength(1));
      expect(writes.single.path, '${MeetingAttendanceRepository.path}/3/11/7');
      expect(writes.single.body, isEmpty);
      expect(
        messages.any(
          (message) =>
              !message.error && message.message.startsWith('เช็กอินแล้ว'),
        ),
        isTrue,
      );
    },
  );

  testWidgets(
    'receipt loading failure does not misreport successful check-in',
    (tester) async {
      api.onGet = (path) {
        if (path.endsWith('food-receipt')) {
          throw const ApiException(message: 'ยังไม่พร้อม', statusCode: 503);
        }
        return {
          'items': [
            row(flags: {'canManualCheckIn': true}),
          ],
        };
      };
      api.onPut = (_, _) => checkedResult();
      await tester.pumpWidget(panel());
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('manual-check-in-11-7')));
      await tester.pumpAndSettle();
      expect(
        messages.any(
          (message) =>
              !message.error && message.message.startsWith('เช็กอินแล้ว'),
        ),
        isTrue,
      );
      expect(
        messages.where((message) => message.error).single.message,
        contains('โหลดข้อมูลรับอาหารไม่สำเร็จ'),
      );
      expect(
        messages.where((message) => message.error).single.message,
        contains('รายละเอียดเพิ่มเติม:'),
      );
    },
  );

  testWidgets(
    'actual receipt submits cumulative booking total and shows audit',
    (tester) async {
      api.onGet = (_) => receipt();
      api.onPut = (_, _) => receipt(received: 2);
      await tester.pumpWidget(receiptPanel());
      await tester.pumpAndSettle();
      expect(find.textContaining('รวมทุกรอบประชุม'), findsOneWidget);
      expect(find.textContaining('บันทึกล่าสุดโดยผู้ใช้ 21'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('receipt-quantity-91')),
        '2',
      );
      await tester.tap(find.byKey(const ValueKey('save-food-receipt')));
      await tester.pumpAndSettle();
      final call = api.calls.last;
      expect(
        call.path,
        '${MeetingAttendanceRepository.path}/3/11/7/food-receipt',
      );
      expect(call.body, {
        'items': [
          {'foodOrderDetailId': 91, 'receivedQuantity': 2},
        ],
      });
      expect(find.text('สั่ง 3 · รับแล้ว 2 · คงเหลือ 1'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('save-food-receipt')));
      await tester.pumpAndSettle();
      expect(api.calls.where((call) => call.method == 'PUT'), hasLength(1));
    },
  );

  testWidgets('receipt rejects decreases excess and noninteger quantities', (
    tester,
  ) async {
    api.onGet = (_) => receipt();
    await tester.pumpWidget(receiptPanel());
    await tester.pumpAndSettle();
    for (final value in ['0', '4', '-1', '1.5', 'abc', '']) {
      await tester.enterText(
        find.byKey(const ValueKey('receipt-quantity-91')),
        value,
      );
      await tester.tap(find.byKey(const ValueKey('save-food-receipt')));
      await tester.pumpAndSettle();
      expect(api.calls.where((call) => call.method == 'PUT'), isEmpty);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'receipt remains disabled without check-in even if capability is true',
    (tester) async {
      api.onGet = (_) => receipt(checked: false);
      await tester.pumpWidget(receiptPanel());
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('save-food-receipt')),
            )
            .onPressed,
        isNull,
      );
      expect(find.text('ต้องเช็กอินรอบนี้ก่อนรับอาหาร'), findsOneWidget);
    },
  );

  testWidgets('failed receipt save requires fresh baseline before retry', (
    tester,
  ) async {
    api.onGet = (_) => receipt();
    api.onPut = (_, _) => throw const ApiException(
      message: 'ยอดเปลี่ยนแล้ว',
      statusCode: 409,
      details: {'description': 'โหลดข้อมูลล่าสุด'},
    );
    await tester.pumpWidget(receiptPanel());
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('receipt-quantity-91')),
      '2',
    );
    await tester.tap(find.byKey(const ValueKey('save-food-receipt')));
    await tester.pumpAndSettle();
    expect(messages.single.error, isTrue);
    expect(
      messages.single.message,
      contains('รายละเอียดเพิ่มเติม: โหลดข้อมูลล่าสุด'),
    );
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('save-food-receipt')))
          .onPressed,
      isNull,
    );
    api.onGet = (_) => receipt(received: 2);
    await tester.tap(find.text('โหลดข้อมูลรับอาหารล่าสุด'));
    await tester.pumpAndSettle();
    expect(find.text('สั่ง 3 · รับแล้ว 2 · คงเหลือ 1'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('save-food-receipt')))
          .onPressed,
      isNotNull,
    );
  });

  testWidgets(
    'Windows scanner uses Enter with no native camera and guards duplicates',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        final pending = Completer<bool>();
        final tokens = <String>[];
        await tester.pumpWidget(
          shell(
            MeetingQrScanner(
              onToken: (token) {
                tokens.add(token);
                return pending.future;
              },
              onError: (_) {},
            ),
          ),
        );
        expect(find.byType(MobileScanner), findsNothing);
        expect(find.text('เปิดกล้องสแกน QR'), findsNothing);
        expect(find.textContaining('บน Windows/Linux'), findsOneWidget);
        await tester.enterText(
          find.byKey(const ValueKey('meeting-qr-input')),
          '  opaque-token  ',
        );
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();
        expect(tokens, ['opaque-token']);
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNull,
        );
        pending.complete(true);
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('meeting-qr-input')),
          'opaque-token',
        );
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        expect(tokens, hasLength(1));
        expect(find.textContaining('QR นี้เช็กอินแล้ว'), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets(
    'camera-supported platform does not create plugin until requested',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        await tester.pumpWidget(
          shell(MeetingQrScanner(onToken: (_) async => true, onError: (_) {})),
        );
        expect(find.text('เปิดกล้องสแกน QR'), findsOneWidget);
        expect(find.byType(MobileScanner), findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );

  testWidgets('late attendance response cannot overwrite another booking', (
    tester,
  ) async {
    final old = Completer<dynamic>();
    api.onGet = (path) => path.endsWith('/3')
        ? old.future
        : {
            'items': [row(participant: 12)],
          };
    await tester.pumpWidget(panel());
    await tester.pumpWidget(panel(booking: 4));
    await tester.pumpAndSettle();
    old.complete({
      'items': [row()],
    });
    await tester.pumpAndSettle();
    expect(find.text('ผู้เข้าร่วม 12'), findsOneWidget);
    expect(find.text('ผู้เข้าร่วม 11'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('narrow receipt layout supports enlarged text without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    api.onGet = (_) => receipt();
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.5)),
        child: receiptPanel(),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
