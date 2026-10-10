import 'package:flutter/material.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';

import 'booking_forms.dart';
import 'booking_capabilities.dart';
import 'booking_host.dart';
import 'booking_routes.dart';

typedef BookingRow = Map<String, dynamic>;
BookingRow bookingMap(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
List<BookingRow> bookingRows(dynamic value) =>
    value is List ? value.map(bookingMap).toList() : <BookingRow>[];

class BookingPage extends StatefulWidget {
  const BookingPage({super.key, required this.menuCode});
  final String menuCode;
  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  static const base = '/api/company/booking';
  late final api = bookingApi();
  final search = TextEditingController();
  BookingRow metadata = {},
      actions = {},
      settings = {},
      dashboard = {},
      options = {};
  List<BookingRow> rows = [];
  bool loading = true, cards = false, acting = false;
  String? error;
  int page = 1, total = 0;
  int? memberId;
  DateTime from = DateTime.now().subtract(const Duration(days: 7));
  DateTime to = DateTime.now().add(const Duration(days: 7));

  String get code => widget.menuCode;
  String get title => metadata['MenuName']?.toString() ?? 'ระบบจองคิว';
  int get screenType => (metadata['ScreenType'] as num?)?.toInt() ?? 0;
  LaooWorkspaceUiTokens get tokens => bookingTokens();
  bool can(String action) {
    if (actions[action] != true) return false;
    if (action == 'create' || action == 'delete') {
      return screenType == 1 || screenType == 4;
    }
    if (action == 'edit') {
      return screenType == 1 || screenType == 2 || screenType == 4;
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(covariant BookingPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.menuCode != code) {
      page = 1;
      rows = [];
      load();
    }
  }

  @override
  void dispose() {
    search.dispose();
    bookingDispose(api);
    super.dispose();
  }

  String day(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  String get start =>
      DateTime(from.year, from.month, from.day).toUtc().toIso8601String();
  String get end =>
      DateTime(to.year, to.month, to.day + 1).toUtc().toIso8601String();

  Future<void> load() async {
    if (!mounted) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final access = bookingMap(await api.get('$base/actions/$code'));
      metadata = bookingMap(access['metadata']);
      actions = bookingMap(access['actions']);
      if (!can('view')) throw StateError('ไม่มีสิทธิ์เปิดหน้าจอนี้');
      if (['61007', '61008', '61009', '61010'].contains(code)) {
        options = bookingMap(await api.get('$base/options/$code'));
      }
      dynamic result;
      switch (code) {
        case '61001':
          settings = bookingMap(await api.get('$base/settings'));
          result = const [];
          break;
        case '61002':
          result = await api.get('$base/services', query: {'page': '$page'});
          break;
        case '61003':
          result = await api.get('$base/providers', query: {'page': '$page'});
          break;
        case '61004':
          result = await api.get('$base/resources', query: {'page': '$page'});
          break;
        case '61005':
          result = await api.get(
            '$base/members',
            query: {'page': '$page', 'q': search.text},
          );
          break;
        case '61006':
          result = await api.get('$base/promotions', query: {'page': '$page'});
          break;
        case '61007':
        case '61008':
          result = await api.get(
            '$base/bookings',
            query: {
              'from': start,
              'to': end,
              'menu': code,
              'page': '$page',
              'pageSize': '20',
            },
          );
          break;
        case '61009':
          result = memberId == null
              ? const []
              : await api.get('$base/members/$memberId/history');
          break;
        case '61010':
          dashboard = bookingMap(
            bookingRows(
              await api.get(
                '$base/dashboard',
                query: {'from': start, 'to': end},
              ),
            ).firstOrNull,
          );
          result = const [];
          break;
        default:
          result = const [];
      }
      final data = bookingMap(result);
      rows = bookingRows(result is Map ? data['items'] : result);
      total = result is Map
          ? (data['total'] as num?)?.toInt() ?? rows.length
          : rows.length;
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          error = bookingErrorText(e, 'โหลดข้อมูล');
        });
      }
    }
  }

  Future<void> openForm([BookingRow? row]) async {
    final permission = code == '61001'
        ? 'edit'
        : row == null
        ? 'create'
        : 'edit';
    if (!can(permission) || acting) return;
    try {
      final formOptions =
          ['61003', '61004', '61005', '61006', '61007'].contains(code)
          ? bookingMap(await api.get('$base/options/$code'))
          : <String, dynamic>{};
      if (!mounted) return;
      final saved = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => BookingForm(
          code: code,
          title: title,
          row: row,
          options: formOptions,
          settings: settings,
          api: api,
          tokens: tokens,
          icon: bookingMenuIcon(metadata['IconName']?.toString()),
        ),
      );
      if (saved == true && mounted) {
        bookingMessage(context, message: 'บันทึกข้อมูลแล้ว', error: false);
        await load();
      }
    } catch (e) {
      if (mounted) {
        bookingMessage(
          context,
          message: bookingErrorText(e, 'เปิดแบบฟอร์ม'),
          error: true,
        );
      }
    }
  }

  Future<void> act(BookingRow row, String action) async {
    if (acting || !can(action)) return;
    final id = (row['id'] as num?)?.toInt();
    if (id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => LaooActionDialog(
        tokens: tokens,
        icon: Icons.event_available_outlined,
        title: '$title > ยืนยัน',
        content: Text(
          action == 'cancel'
              ? 'ยืนยันยกเลิกคิว ${row['number'] ?? id}?'
              : action == 'noshow'
              ? 'ยืนยันว่าไม่มา?'
              : 'ยืนยันการใช้บริการ?',
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ยืนยัน'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => acting = true);
    try {
      final path = action == 'cancel'
          ? 'cancel'
          : action == 'noshow'
          ? 'no-show'
          : 'use';
      await api.post('$base/bookings/$id/$path');
      if (mounted) {
        bookingMessage(context, message: 'อัปเดตสถานะแล้ว', error: false);
        await load();
      }
    } catch (e) {
      if (mounted) {
        bookingMessage(
          context,
          message: bookingErrorText(e, 'เปลี่ยนสถานะ'),
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => acting = false);
    }
  }

  Future<void> pickDates() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(start: from, end: to),
    );
    if (range == null) return;
    from = range.start;
    to = range.end;
    page = 1;
    await load();
  }

  Widget caption() => LayoutBuilder(
    builder: (context, constraints) => LaooCaptionCard(
      tokens: tokens,
      caption: title,
      favoriteKey: BookingRoutes.all
          .firstWhere((r) => r.menuCode == code)
          .routeName,
      leading: Icon(
        bookingMenuIcon(metadata['IconName']?.toString()),
        color: tokens.primaryColor,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (constraints.maxWidth >= tokens.compactBreakpoint &&
              code != '61001' &&
              code != '61010')
            LaooListCardToggle(
              tokens: tokens,
              cards: cards,
              onChanged: (v) => setState(() => cards = v),
            ),
          if ((code == '61001' && can('edit')) ||
              ([
                    '61002',
                    '61003',
                    '61004',
                    '61005',
                    '61006',
                    '61007',
                  ].contains(code) &&
                  can('create')))
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: FilledButton.icon(
                onPressed: () => openForm(),
                icon: Icon(code == '61001' ? Icons.edit_outlined : Icons.add),
                label: Text(code == '61001' ? 'แก้ไข' : 'เพิ่ม'),
                style: FilledButton.styleFrom(
                  minimumSize: Size(0, tokens.buttonHeight),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(tokens.radius),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );

  Widget filter() => Wrap(
    spacing: 8,
    runSpacing: 8,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      if (code == '61005')
        SizedBox(
          width: 270,
          child: TextField(
            controller: search,
            decoration: const InputDecoration(
              labelText: 'ค้นหาสมาชิก',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) {
              page = 1;
              load();
            },
          ),
        ),
      if (['61007', '61008', '61010'].contains(code))
        OutlinedButton.icon(
          onPressed: pickDates,
          icon: const Icon(Icons.date_range_outlined),
          label: Text('${day(from)} – ${day(to)}'),
        ),
      if (code == '61009')
        SizedBox(
          width: 300,
          child: DropdownButtonFormField<int>(
            initialValue: memberId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'สมาชิก',
              border: OutlineInputBorder(),
            ),
            items: bookingRows(options['members'])
                .map(
                  (m) => DropdownMenuItem<int>(
                    value: (m['id'] as num).toInt(),
                    child: Text(
                      '${m['code']} — ${m['name']}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: (v) {
              memberId = v;
              load();
            },
          ),
        ),
    ],
  );

  List<MapEntry<String, String>> get columns => switch (code) {
    '61002' => const [
      MapEntry('code', 'รหัส'),
      MapEntry('name', 'บริการ'),
      MapEntry('durationMinutes', 'นาที'),
      MapEntry('price', 'ราคา'),
      MapEntry('active', 'สถานะ'),
    ],
    '61003' => const [
      MapEntry('name', 'ผู้ให้บริการ'),
      MapEntry('personId', 'รหัสบุคคล'),
      MapEntry('active', 'สถานะ'),
    ],
    '61004' => const [
      MapEntry('name', 'ห้อง/ทรัพยากร'),
      MapEntry('type', 'ประเภท'),
      MapEntry('branchId', 'สาขา'),
      MapEntry('active', 'สถานะ'),
    ],
    '61005' => const [
      MapEntry('code', 'รหัสสมาชิก'),
      MapEntry('name', 'ชื่อ'),
      MapEntry('tierCode', 'ระดับ'),
      MapEntry('expiresOn', 'หมดอายุ'),
      MapEntry('active', 'สถานะ'),
    ],
    '61006' => const [
      MapEntry('code', 'รหัส'),
      MapEntry('name', 'โปรโมชั่น'),
      MapEntry('discountValue', 'ส่วนลด'),
      MapEntry('endsAt', 'สิ้นสุด'),
      MapEntry('active', 'สถานะ'),
    ],
    '61007' || '61008' => const [
      MapEntry('number', 'เลขที่จอง'),
      MapEntry('name', 'ลูกค้า'),
      MapEntry('startsAt', 'เริ่ม'),
      MapEntry('status', 'สถานะ'),
      MapEntry('amount', 'ยอดเงิน'),
    ],
    '61009' => const [
      MapEntry('number', 'เลขที่จอง'),
      MapEntry('service', 'บริการ'),
      MapEntry('startsAt', 'วันที่'),
      MapEntry('status', 'สถานะ'),
      MapEntry('amount', 'ยอดเงิน'),
    ],
    _ => const [],
  };

  String cell(BookingRow row, String key) {
    final value = row[key];
    if (value == null) return '—';
    if (key == 'status') {
      return switch (value.toString()) {
        'BOOKED' => 'จองแล้ว',
        'CONFIRMED' => 'ยืนยันแล้ว',
        'IN_SERVICE' => 'กำลังใช้บริการ',
        'COMPLETED' => 'เสร็จสิ้น',
        'CANCELLED' => 'ยกเลิก',
        'NO_SHOW' => 'ไม่มาใช้บริการ',
        _ => value.toString(),
      };
    }
    if (key == 'startsAt' || key == 'endsAt') {
      final parsed = DateTime.tryParse(value.toString())?.toLocal();
      if (parsed != null) {
        String two(int number) => number.toString().padLeft(2, '0');
        return '${parsed.year}-${two(parsed.month)}-${two(parsed.day)} '
            '${two(parsed.hour)}:${two(parsed.minute)}';
      }
    }
    if (value is bool) return value ? 'ใช้งาน' : 'ปิด';
    if (key == 'price' || key == 'amount') {
      return (value as num).toStringAsFixed(2);
    }
    return value.toString();
  }

  Widget rowActions(BookingRow row) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (['61007', '61008'].contains(code))
        IconButton(
          tooltip: 'ดูรายละเอียด',
          onPressed: () => viewBooking(row),
          icon: const Icon(Icons.visibility_outlined),
        ),
      if (['61003', '61004'].contains(code) && can('edit'))
        IconButton(
          tooltip: code == '61003' ? 'จัดตารางและบริการ' : 'จัดบริการที่รองรับ',
          onPressed: () => editCapabilities(row),
          icon: Icon(
            code == '61003'
                ? Icons.schedule_outlined
                : Icons.room_preferences_outlined,
          ),
        ),
      if (['61002', '61004', '61005', '61006'].contains(code) && can('edit'))
        IconButton(
          tooltip: 'แก้ไข',
          onPressed: () => openForm(row),
          icon: const Icon(Icons.edit_outlined),
        ),
      if (code == '61005' && can('edit'))
        IconButton(
          tooltip: 'ตั้งรหัสผ่านสมาชิก',
          onPressed: () => setMemberPassword(row),
          icon: const Icon(Icons.key_outlined),
        ),
      if (['61002', '61003', '61004', '61005', '61006'].contains(code) &&
          can('delete') &&
          row['active'] == true)
        IconButton(
          tooltip: 'ปิดใช้งาน',
          onPressed: () => disableRow(row),
          icon: const Icon(Icons.delete_outline),
          color: Theme.of(context).colorScheme.error,
        ),
      if (code == '61007' &&
          can('cancel') &&
          ['BOOKED', 'CONFIRMED'].contains(row['status']))
        IconButton(
          tooltip: 'ยกเลิก',
          onPressed: () => act(row, 'cancel'),
          icon: const Icon(Icons.event_busy_outlined),
        ),
      if (code == '61008' &&
          can('use') &&
          ['BOOKED', 'CONFIRMED', 'IN_SERVICE'].contains(row['status']))
        IconButton(
          tooltip: 'ใช้บริการ',
          onPressed: () => act(row, 'use'),
          icon: const Icon(Icons.check_circle_outline),
        ),
      if (code == '61008' &&
          can('noshow') &&
          ['BOOKED', 'CONFIRMED'].contains(row['status']))
        IconButton(
          tooltip: 'ไม่มาใช้บริการ',
          onPressed: () => act(row, 'noshow'),
          icon: const Icon(Icons.person_off_outlined),
        ),
      if (code == '61008' &&
          can('sale') &&
          !['CANCELLED', 'NO_SHOW'].contains(row['status']))
        IconButton(
          tooltip: 'เชื่อมใบขาย POS',
          onPressed: () => linkSale(row),
          icon: const Icon(Icons.point_of_sale_outlined),
        ),
    ],
  );

  Future<void> viewBooking(BookingRow row) async {
    final id = (row['id'] as num?)?.toInt();
    if (id == null) return;
    try {
      final data = bookingMap(
        await api.get('$base/bookings/$id', query: {'menu': code}),
      );
      if (!mounted) return;
      final header = bookingMap(data['header']);
      final lines = bookingRows(data['lines']);
      final sales = bookingRows(data['sales']);
      final changed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => LaooActionDialog(
          tokens: tokens,
          icon: Icons.event_note_outlined,
          title: '$title > ${header['number']}',
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ลูกค้า: ${header['name'] ?? '—'}'),
              Text('เริ่ม: ${cell(header, 'startsAt')}'),
              Text('สถานะ: ${cell(header, 'status')}'),
              Text('ยอดรวม: ${header['amount'] ?? 0}'),
              const SizedBox(height: 16),
              Text('รายการบริการ', style: tokens.sectionStyle),
              for (final line in lines)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${line['service'] ?? '—'} · ${line['netAmount'] ?? 0}',
                      ),
                      Text(
                        'ผู้ให้บริการ: ${line['provider'] ?? 'ไม่ระบุ'} · ห้อง: ${line['resource'] ?? 'ไม่ระบุ'}',
                      ),
                      if (line['usedAt'] != null)
                        Text('ใช้บริการแล้ว: ${line['usedAt']}'),
                      if (code == '61008' &&
                          can('use') &&
                          line['usedAt'] == null &&
                          [
                            'BOOKED',
                            'CONFIRMED',
                            'IN_SERVICE',
                          ].contains(header['status']))
                        TextButton.icon(
                          onPressed: () async {
                            try {
                              await api.post(
                                '$base/bookings/$id/lines/${line['id']}/use',
                              );
                              if (dialogContext.mounted) {
                                Navigator.pop(dialogContext, true);
                              }
                            } catch (e) {
                              if (mounted) {
                                bookingMessage(
                                  context,
                                  message: bookingErrorText(
                                    e,
                                    'บันทึกใช้บริการ',
                                  ),
                                  error: true,
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('บันทึกใช้บริการรายการนี้'),
                        ),
                    ],
                  ),
                ),
              if (sales.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('ใบขาย POS ที่เชื่อม', style: tokens.sectionStyle),
                for (final sale in sales)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${sale['receipt'] ?? sale['saleId']} · ${cell(sale, 'status')} · ${sale['amount'] ?? 0}',
                    ),
                  ),
              ],
            ],
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('ปิด'),
            ),
          ],
        ),
      );
      if (changed == true && mounted) {
        bookingMessage(context, message: 'บันทึกใช้บริการแล้ว', error: false);
        await load();
      }
    } catch (e) {
      if (mounted) {
        bookingMessage(
          context,
          message: bookingErrorText(e, 'ดูรายละเอียดการจอง'),
          error: true,
        );
      }
    }
  }

  Future<void> editCapabilities(BookingRow row) async {
    final id = (row['id'] as num?)?.toInt();
    if (id == null) return;
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => BookingCapabilitiesDialog(
        provider: code == '61003',
        id: id,
        title: title,
        api: api,
        tokens: tokens,
      ),
    );
    if (changed == true && mounted) {
      bookingMessage(context, message: 'บันทึกข้อมูลแล้ว', error: false);
    }
  }

  Future<void> linkSale(BookingRow row) async {
    final id = (row['id'] as num?)?.toInt();
    if (id == null) return;
    late final List<BookingRow> sales;
    try {
      sales = bookingRows(
        await api.get('/api/company/pos/sales'),
      ).where((sale) => sale['status'] == 'COMPLETED').toList();
    } catch (e) {
      if (mounted) {
        bookingMessage(
          context,
          message: bookingErrorText(e, 'โหลดใบขาย POS'),
          error: true,
        );
      }
      return;
    }
    if (!mounted) return;
    int? selectedSaleId;
    final saleId = await showDialog<int>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, updateDialog) => LaooActionDialog(
          tokens: tokens,
          icon: Icons.point_of_sale_outlined,
          title: '$title > เชื่อมใบขาย POS',
          content: sales.isEmpty
              ? const Text('ยังไม่มีใบขาย POS ที่ชำระเสร็จแล้ว')
              : DropdownButtonFormField<int>(
                  initialValue: selectedSaleId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'ใบขาย POS *',
                    border: OutlineInputBorder(),
                  ),
                  items: sales
                      .map(
                        (sale) => DropdownMenuItem<int>(
                          value: (sale['id'] as num).toInt(),
                          child: Text(
                            '${sale['receipt']} · ${sale['branch']} · ${sale['net']}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) =>
                      updateDialog(() => selectedSaleId = value),
                ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('ยกเลิก'),
            ),
            FilledButton.icon(
              onPressed: selectedSaleId == null
                  ? null
                  : () => Navigator.pop(dialogContext, selectedSaleId),
              icon: const Icon(Icons.link),
              label: const Text('เชื่อมใบขาย'),
            ),
          ],
        ),
      ),
    );
    if (saleId == null || !mounted) return;
    try {
      await api.post('$base/bookings/$id/sales', body: {'saleId': saleId});
      if (mounted) {
        bookingMessage(context, message: 'เชื่อมใบขายแล้ว', error: false);
      }
    } catch (e) {
      if (mounted) {
        bookingMessage(
          context,
          message: bookingErrorText(e, 'เชื่อมใบขาย'),
          error: true,
        );
      }
    }
  }

  Future<void> setMemberPassword(BookingRow row) async {
    final id = (row['id'] as num?)?.toInt();
    if (id == null) return;
    final password = TextEditingController();
    final confirm = TextEditingController();
    String? validation;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, updateDialog) => LaooActionDialog(
          tokens: tokens,
          icon: Icons.key_outlined,
          title: '$title > ตั้งรหัสผ่าน',
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('สมาชิก ${row['code']} — ${row['name']}'),
              const SizedBox(height: 16),
              TextField(
                controller: password,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'รหัสผ่านใหม่ *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: confirm,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'ยืนยันรหัสผ่าน *',
                  border: OutlineInputBorder(),
                ),
              ),
              if (validation != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    validation!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('ยกเลิก'),
            ),
            FilledButton.icon(
              onPressed: () async {
                final value = password.text;
                if (value.length < 12 ||
                    value.length > 256 ||
                    !RegExp(r'[A-Z]').hasMatch(value) ||
                    !RegExp(r'[a-z]').hasMatch(value) ||
                    !RegExp(r'[0-9]').hasMatch(value) ||
                    !RegExp(r'[^A-Za-z0-9]').hasMatch(value) ||
                    value != confirm.text) {
                  updateDialog(
                    () => validation =
                        'ใช้ 12–256 ตัว มีพิมพ์ใหญ่ พิมพ์เล็ก ตัวเลข อักขระพิเศษ และยืนยันให้ตรงกัน',
                  );
                  return;
                }
                try {
                  await api.put(
                    '$base/members/$id/credential',
                    body: {'newPassword': value, 'isActive': true},
                  );
                  if (dialogContext.mounted) Navigator.pop(dialogContext, true);
                } catch (e) {
                  updateDialog(
                    () =>
                        validation = bookingErrorText(e, 'ตั้งรหัสผ่านสมาชิก'),
                  );
                }
              },
              icon: const Icon(Icons.save_outlined),
              label: const Text('บันทึก'),
            ),
          ],
        ),
      ),
    );
    password.dispose();
    confirm.dispose();
    if (saved == true && mounted) {
      bookingMessage(context, message: 'ตั้งรหัสผ่านสมาชิกแล้ว', error: false);
    }
  }

  Future<void> disableRow(BookingRow row) async {
    final id = (row['id'] as num?)?.toInt();
    if (id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => LaooActionDialog(
        tokens: tokens,
        icon: Icons.delete_outline,
        title: '$title > ปิดใช้งาน',
        content: Text('ยืนยันปิดใช้งาน ${row['name']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ยืนยัน'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final path = switch (code) {
        '61002' => 'services',
        '61003' => 'providers',
        '61004' => 'resources',
        '61005' => 'members',
        _ => 'promotions',
      };
      await api.delete('$base/$path/$id');
      if (mounted) {
        bookingMessage(context, message: 'ปิดใช้งานแล้ว', error: false);
        await load();
      }
    } catch (e) {
      if (mounted) {
        bookingMessage(
          context,
          message: bookingErrorText(e, 'ปิดใช้งาน'),
          error: true,
        );
      }
    }
  }

  Widget listBody({required double availableWidth}) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(error!),
            OutlinedButton(onPressed: load, child: const Text('ลองใหม่')),
          ],
        ),
      );
    }
    if (rows.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('ยังไม่มีรายการ'),
        ),
      );
    }
    if (cards || availableWidth < tokens.compactBreakpoint) {
      return LayoutBuilder(
        builder: (context, constraints) => Wrap(
          spacing: tokens.itemSpacing,
          runSpacing: tokens.itemSpacing,
          children: rows
              .map(
                (row) => SizedBox(
                  width: constraints.maxWidth < 700
                      ? constraints.maxWidth
                      : (constraints.maxWidth - tokens.itemSpacing) / 2,
                  child: LaooSurfaceCard(
                    tokens: tokens,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cell(row, columns.first.key),
                          style: tokens.sectionStyle,
                        ),
                        const SizedBox(height: 8),
                        ...columns
                            .skip(1)
                            .map(
                              (c) => Padding(
                                padding: const EdgeInsets.only(bottom: 5),
                                child: Text(
                                  '${c.value}: ${cell(row, c.key)}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: rowActions(row),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      );
    }
    return LaooSurfaceCard(
      tokens: tokens,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: DataTable(
              columns: [
                for (final c in columns) DataColumn(label: Text(c.value)),
                const DataColumn(label: Text('จัดการ')),
              ],
              rows: [
                for (final row in rows)
                  DataRow(
                    cells: [
                      for (final c in columns)
                        DataCell(
                          Text(
                            cell(row, c.key),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      DataCell(rowActions(row)),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget content() {
    if (code == '61001') {
      return LaooSurfaceCard(
        tokens: tokens,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('กติกาการจอง', style: tokens.sectionStyle),
            const SizedBox(height: 16),
            Text('จองล่วงหน้า ${settings['advanceDays'] ?? 90} วัน'),
            Text(
              'ยกเลิกก่อนเริ่ม ${settings['cancelBeforeHours'] ?? 2} ชั่วโมง',
            ),
            Text('รอผู้ใช้บริการ ${settings['noShowGraceMinutes'] ?? 15} นาที'),
          ],
        ),
      );
    }
    if (code == '61010') {
      return LaooSurfaceCard(
        tokens: tokens,
        child: Wrap(
          spacing: 24,
          runSpacing: 16,
          children: [
            for (final e in const [
              MapEntry('bookings', 'การจอง'),
              MapEntry('completed', 'ใช้บริการแล้ว'),
              MapEntry('bookedAmount', 'มูลค่าการจอง'),
            ])
              SizedBox(
                width: 190,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.value),
                    Text(
                      '${dashboard[e.key] ?? 0}',
                      style: tokens.sectionStyle,
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) =>
          listBody(availableWidth: constraints.maxWidth),
    );
  }

  @override
  Widget build(BuildContext context) {
    final route = BookingRoutes.all.firstWhere((r) => r.menuCode == code);
    return bookingShell(
      pageTitle: title,
      activeMenu: route.routeName,
      child: ColoredBox(
        color: tokens.backgroundColor,
        child: SingleChildScrollView(
          padding: tokens.contentMargin,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              caption(),
              if (code != '61001') ...[
                SizedBox(height: tokens.sectionSpacing),
                LaooFilterCard(tokens: tokens, child: filter()),
              ],
              SizedBox(height: tokens.sectionSpacing),
              content(),
              if ([
                '61002',
                '61003',
                '61004',
                '61005',
                '61006',
                '61007',
                '61008',
              ].contains(code)) ...[
                SizedBox(height: tokens.sectionSpacing),
                LaooPaginationCard(
                  tokens: tokens,
                  page: page,
                  pageCount: total == 0 ? 1 : (total / 20).ceil(),
                  pageSize: 20,
                  total: total,
                  onPrevious: page > 1
                      ? () {
                          page--;
                          load();
                        }
                      : null,
                  onNext: page * 20 < total
                      ? () {
                          page++;
                          load();
                        }
                      : null,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
