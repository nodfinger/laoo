import '../../../core/api/api_client.dart';

class MeetingAttendanceRow {
  MeetingAttendanceRow(this.json);
  final Map<String, dynamic> json;
  int get participantId => (json['participantId'] as num).toInt();
  int get slotId => (json['slotId'] as num).toInt();
  String get participantName => json['participantName'] as String? ?? '-';
  Object? get startDateTime => json['startDateTime'];
  Object? get endDateTime => json['endDateTime'];
  Object? get checkInDate => json['checkInDate'];
  Object? get checkInByUserId => json['checkInByUserId'];
  String? get method => json['method'] as String?;
  // Fail closed: never infer a QR capability from canCheckIn or client roles.
  bool get canIssueRoomQr => json['canIssueRoomQr'] == true;
  bool get canIssuePersonalQr => json['canIssuePersonalQr'] == true;
  bool get canManualCheckIn => json['canManualCheckIn'] == true;
  bool get canScanRoomQr => json['canScanRoomQr'] == true;
  bool get canScanPersonalQr => json['canScanPersonalQr'] == true;
}

class MeetingAttendanceList {
  const MeetingAttendanceList({required this.available, required this.items});

  final bool available;
  final List<MeetingAttendanceRow> items;
}

class MeetingQrCode {
  MeetingQrCode.fromJson(Map<String, dynamic> json)
    : token = json['token'] as String,
      expiresAtUtc = DateTime.parse(json['expiresAtUtc'] as String).toUtc(),
      kind = json['kind'] as String,
      bookingId = (json['bookingId'] as num).toInt(),
      slotId = (json['slotId'] as num).toInt(),
      participantId = (json['participantId'] as num?)?.toInt();
  final String token;
  final DateTime expiresAtUtc;
  final String kind;
  final int bookingId;
  final int slotId;
  final int? participantId;
  bool get expired => !DateTime.now().toUtc().isBefore(expiresAtUtc);
}

class MeetingCheckIn {
  MeetingCheckIn.fromJson(Map<String, dynamic> json)
    : bookingId = (json['bookingId'] as num).toInt(),
      participantId = (json['participantId'] as num).toInt(),
      slotId = (json['slotId'] as num).toInt(),
      checkInDate = json['checkInDate'],
      checkInByUserId = json['checkInByUserId'],
      method = json['method'] as String?;
  final int bookingId;
  final int participantId;
  final int slotId;
  final Object? checkInDate;
  final Object? checkInByUserId;
  final String? method;
}

class MeetingFoodReceiptLine {
  MeetingFoodReceiptLine.fromJson(Map<String, dynamic> json)
    : foodOrderDetailId = (json['foodOrderDetailId'] as num).toInt(),
      foodName = json['foodName'] as String,
      orderedQuantity = (json['orderedQuantity'] as num).toInt(),
      receivedQuantity = (json['receivedQuantity'] as num).toInt(),
      receivedByUserId = (json['receivedByUserId'] as num?)?.toInt(),
      receivedAtUtc = json['receivedAtUtc'],
      receiptSlotId = (json['receiptSlotId'] as num?)?.toInt();
  final int foodOrderDetailId;
  final String foodName;
  final int orderedQuantity;
  final int receivedQuantity;
  final int? receivedByUserId;
  final Object? receivedAtUtc;
  final int? receiptSlotId;
  int get remainingQuantity => orderedQuantity - receivedQuantity;

  String? validateCumulative(String text) {
    final value = int.tryParse(text.trim());
    if (value == null || value < 0 || value > 99) {
      return 'กรอกจำนวนเต็ม 0 ถึง 99';
    }
    if (value < receivedQuantity) {
      return 'ต้องไม่น้อยกว่ายอดรับเดิม $receivedQuantity';
    }
    if (value > orderedQuantity) return 'ต้องไม่เกินยอดสั่ง $orderedQuantity';
    return null;
  }
}

class MeetingFoodReceipt {
  MeetingFoodReceipt.fromJson(Map<String, dynamic> json)
    : bookingId = (json['bookingId'] as num).toInt(),
      participantId = (json['participantId'] as num).toInt(),
      slotId = (json['slotId'] as num).toInt(),
      checkInDate = json['checkInDate'],
      canReceive = json['canReceive'] == true,
      items = [
        for (final item in json['items'] as List)
          MeetingFoodReceiptLine.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
      ];
  final int bookingId;
  final int participantId;
  final int slotId;
  final Object? checkInDate;
  final bool canReceive;
  final List<MeetingFoodReceiptLine> items;
}

class MeetingAttendanceRepository {
  MeetingAttendanceRepository({ApiClient? api}) : _api = api ?? ApiClient();
  final ApiClient _api;
  static const path = '/api/company/meeting-attendance';

  Future<MeetingAttendanceList> list(int bookingId, {int? slotId}) async {
    final result =
        await _api.get(
              '$path/$bookingId',
              query: {if (slotId != null) 'slotId': '$slotId'},
            )
            as Map;
    return MeetingAttendanceList(
      available: result['available'] != false,
      items: [
        for (final item in result['items'] as List? ?? const [])
          MeetingAttendanceRow(Map<String, dynamic>.from(item as Map)),
      ],
    );
  }

  Future<Map<String, dynamic>> bookingSlots({
    required DateTime dateFrom,
    required DateTime dateTo,
    String? search,
    int page = 1,
    int pageSize = 20,
  }) async => Map<String, dynamic>.from(
    await _api.get(
          path,
          query: {
            'dateFrom': _dateOnly(dateFrom),
            'dateTo': _dateOnly(dateTo),
            'page': '$page',
            'pageSize': '$pageSize',
            if (search != null && search.trim().isNotEmpty)
              'search': search.trim(),
          },
        )
        as Map,
  );

  static String _dateOnly(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  Future<MeetingQrCode> issueQr(
    int bookingId,
    int slotId, {
    int? participantId,
  }) async => MeetingQrCode.fromJson(
    Map<String, dynamic>.from(
      await _api.post(
            '$path/$bookingId/$slotId/qr-token',
            body: {
              'kind': participantId == null ? 'ROOM' : 'PERSONAL',
              'participantId': ?participantId,
            },
          )
          as Map,
    ),
  );

  Future<MeetingCheckIn> consumeQr(String token) async =>
      MeetingCheckIn.fromJson(
        Map<String, dynamic>.from(
          await _api.post('$path/qr-check-in', body: {'token': token}) as Map,
        ),
      );

  Future<MeetingCheckIn> manualCheckIn(
    int bookingId,
    int participantId,
    int slotId,
  ) async => MeetingCheckIn.fromJson(
    Map<String, dynamic>.from(
      await _api.put(
            '$path/$bookingId/$participantId/$slotId',
            body: <String, dynamic>{},
          )
          as Map,
    ),
  );

  Future<MeetingFoodReceipt> receipt(
    int bookingId,
    int participantId,
    int slotId,
  ) async => MeetingFoodReceipt.fromJson(
    Map<String, dynamic>.from(
      await _api.get('$path/$bookingId/$participantId/$slotId/food-receipt')
          as Map,
    ),
  );

  /// Values are cumulative per order detail across the entire booking, not a
  /// delta per slot. Repeating the same request must not issue more food.
  Future<MeetingFoodReceipt> saveReceipt(
    MeetingFoodReceipt receipt,
    Map<int, int> quantities,
  ) async => MeetingFoodReceipt.fromJson(
    Map<String, dynamic>.from(
      await _api.put(
            '$path/${receipt.bookingId}/${receipt.participantId}/${receipt.slotId}/food-receipt',
            body: {
              'items': [
                for (final entry in quantities.entries)
                  {
                    'foodOrderDetailId': entry.key,
                    'receivedQuantity': entry.value,
                  },
              ],
            },
          )
          as Map,
    ),
  );

  void dispose() => _api.dispose();
}
