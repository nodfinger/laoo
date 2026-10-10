import 'package:flutter/material.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';

import 'rental_forms.dart';
import 'rental_host.dart';
import 'rental_routes.dart';

typedef RentalRow = Map<String, dynamic>;
RentalRow rentalMap(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
List<RentalRow> rentalRows(dynamic value) =>
    value is List ? value.map(rentalMap).toList() : <RentalRow>[];

class RentalPage extends StatefulWidget {
  const RentalPage({super.key, required this.menuCode});
  final String menuCode;

  @override
  State<RentalPage> createState() => _RentalPageState();
}

class _RentalPageState extends State<RentalPage> {
  static const base = '/api/company/rental';
  late final api = rentalApi();
  final search = TextEditingController();
  RentalRow access = {}, metadata = {}, settings = {}, dashboard = {};
  RentalRow options = {};
  List<RentalRow> rows = [];
  bool loading = true, cards = false, saving = false;
  String? error;
  int page = 1, total = 0;
  int? selectedBranch;
  String selectedStatus = '';
  DateTime periodStart = DateTime.now().add(const Duration(days: 1));
  DateTime periodEnd = DateTime.now().add(const Duration(days: 2));
  DateTime reportStart = DateTime.now().subtract(const Duration(days: 30));
  DateTime reportEnd = DateTime.now();

  String get code => widget.menuCode;
  String get title => metadata['MenuName']?.toString() ?? 'ระบบร้านเช่า';
  int get screenType => (metadata['ScreenType'] as num?)?.toInt() ?? 0;
  bool can(String action) => access[action.toLowerCase()] == true;
  LaooWorkspaceUiTokens get tokens => rentalTokens();
  bool get isItems => code == '60002';
  bool get isAvailability => code == '60003';
  bool get isHistory => code == '60009';
  bool get isDashboard => code == '60010';

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    search.dispose();
    rentalDispose(api);
    super.dispose();
  }

  String day(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  Future<void> load() async {
    if (!mounted) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = rentalMap(await api.get('$base/actions/$code'));
      metadata = rentalMap(result['metadata']);
      access = rentalMap(result['actions']);
      if (!can('view')) throw StateError('ไม่มีสิทธิ์เปิดหน้าจอนี้');
      if (code == '60001') {
        settings = rentalMap(await api.get('$base/settings'));
        rows = [];
      } else if (isItems) {
        await loadOptions();
        final q = <String, String>{
          if (selectedBranch != null) 'branchId': '$selectedBranch',
        };
        rows = rentalRows(await api.get('$base/items', query: q));
        total = rows.length;
      } else if (isAvailability) {
        await loadOptions();
        if (selectedBranch == null &&
            rentalRows(options['branches']).isNotEmpty) {
          selectedBranch = (rentalRows(options['branches']).first['id'] as num)
              .toInt();
        }
        rows = selectedBranch == null
            ? <RentalRow>[]
            : rentalRows(
                await api.get(
                  '$base/availability',
                  query: {
                    'branchId': '$selectedBranch',
                    'startAt': '${day(periodStart)}T09:00:00+07:00',
                    'endAt': '${day(periodEnd)}T18:00:00+07:00',
                  },
                ),
              );
        total = rows.length;
      } else if (isDashboard) {
        await loadOptions();
        dashboard = rentalMap(
          await api.get(
            '$base/dashboard',
            query: {
              if (selectedBranch != null) 'branchId': '$selectedBranch',
              'from': day(reportStart),
              'to': day(reportEnd),
            },
          ),
        );
        rows = rentalRows(dashboard['popular']);
        total = rows.length;
      } else {
        if (options.isEmpty) await loadOptions();
        final result = rentalMap(
          await api.get(
            '$base/history',
            query: {
              'menu': code,
              'page': '$page',
              'pageSize': '20',
              if (selectedBranch != null) 'branchId': '$selectedBranch',
              if (selectedStatus.isNotEmpty) 'status': selectedStatus,
            },
          ),
        );
        rows = rentalRows(result['items']);
        total = (result['total'] as num?)?.toInt() ?? rows.length;
      }
      if (mounted) setState(() => loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          error = rentalErrorText(e, 'โหลดข้อมูล$title');
        });
      }
    }
  }

  Future<void> loadOptions() async {
    options = rentalMap(await api.get('$base/options/$code'));
  }

  Future<void> choosePeriod() async {
    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(start: periodStart, end: periodEnd),
    );
    if (result == null) return;
    periodStart = result.start;
    periodEnd = result.end;
    await load();
  }

  Future<void> chooseReportPeriod() async {
    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(start: reportStart, end: reportEnd),
    );
    if (result == null) return;
    reportStart = result.start;
    reportEnd = result.end;
    await load();
  }

  Future<void> openForm({
    String mode = 'create',
    RentalRow? row,
    String? action,
  }) async {
    if (saving) return;
    final formAction = action ?? (mode == 'edit' ? 'edit' : 'create');
    final permissionAction = switch (formAction) {
      'detail' => 'view',
      'transfer' => 'edit',
      'payment' || 'handover' || 'return' => 'create',
      'approve-settlement' => 'approve',
      _ => formAction,
    };
    if (!can(permissionAction)) return;
    if (options.isEmpty && code != '60001') {
      try {
        await loadOptions();
      } catch (e) {
        if (!mounted) return;
        rentalMessage(
          context,
          message: rentalErrorText(e, 'เตรียมข้อมูลแบบฟอร์ม'),
          error: true,
        );
        return;
      }
    }
    if (!mounted) return;
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => RentalActionForm(
        menuCode: code,
        mode: mode,
        action: action,
        title: title,
        iconName: metadata['IconName']?.toString(),
        row: row,
        settings: settings,
        options: options,
        api: api,
        tokens: tokens,
      ),
    );
    if (changed == true && mounted) {
      rentalMessage(context, message: 'บันทึกรายการแล้ว', error: false);
      await load();
    }
  }

  Future<void> cancelBooking(RentalRow row) async {
    await openForm(row: row, action: 'cancel');
  }

  Widget caption() {
    final trailing = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (MediaQuery.sizeOf(context).width >= 900 &&
            !isDashboard &&
            !isAvailability)
          LaooListCardToggle(
            tokens: tokens,
            cards: cards,
            onChanged: (value) => setState(() => cards = value),
          ),
        if (_canCreate)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: FilledButton.icon(
              onPressed: () => openForm(),
              icon: const Icon(Icons.add),
              label: Text(isItems ? 'เพิ่มของเช่า' : 'จองเช่า'),
              style: FilledButton.styleFrom(
                minimumSize: Size(0, tokens.buttonHeight),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(tokens.radius),
                ),
              ),
            ),
          ),
      ],
    );
    return LaooCaptionCard(
      tokens: tokens,
      caption: title,
      favoriteKey: RentalRoutes.all
          .firstWhere((r) => r.menuCode == code)
          .routeName,
      leading: Icon(
        rentalMenuIcon(metadata['IconName']?.toString()),
        color: tokens.primaryColor,
      ),
      trailing: trailing.children.isEmpty ? null : trailing,
    );
  }

  bool get _canCreate =>
      (screenType == 1 && can('create') && isItems) ||
      (screenType == 4 && can('create') && code == '60004');

  Widget filter() => Wrap(
    spacing: 8,
    runSpacing: 8,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      if (isItems ||
          isDashboard ||
          isHistory ||
          ['60004', '60005', '60006', '60007', '60008'].contains(code))
        SizedBox(
          width: 250,
          child: DropdownButtonFormField<int?>(
            initialValue: selectedBranch,
            decoration: rentalField(tokens, 'สาขา'),
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text('ทุกสาขา')),
              ...rentalRows(options['branches']).map(
                (b) => DropdownMenuItem<int?>(
                  value: (b['id'] as num).toInt(),
                  child: Text(
                    '${b['code'] ?? ''} ${b['name'] ?? ''}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
            onChanged: (value) {
              selectedBranch = value;
              page = 1;
              load();
            },
          ),
        ),
      if (!isItems && !isAvailability && !isDashboard && code != '60001')
        SizedBox(
          width: 220,
          child: DropdownButtonFormField<String>(
            initialValue: selectedStatus,
            decoration: rentalField(tokens, 'สถานะ'),
            items: [
              const DropdownMenuItem(value: '', child: Text('ทุกสถานะ')),
              ..._statuses.map(
                (s) => DropdownMenuItem(value: s, child: Text(_statusLabel(s))),
              ),
            ],
            onChanged: (value) {
              selectedStatus = value ?? '';
              page = 1;
              load();
            },
          ),
        ),
      if (isAvailability)
        OutlinedButton.icon(
          onPressed: choosePeriod,
          icon: const Icon(Icons.date_range_outlined),
          label: Text('${day(periodStart)} – ${day(periodEnd)}'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 40),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(tokens.radius),
            ),
          ),
        ),
      if (isDashboard)
        OutlinedButton.icon(
          onPressed: chooseReportPeriod,
          icon: const Icon(Icons.date_range_outlined),
          label: Text('${day(reportStart)} – ${day(reportEnd)}'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 40),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(tokens.radius),
            ),
          ),
        ),
      if (isItems || isHistory || code == '60004')
        SizedBox(
          width: 250,
          child: TextField(
            controller: search,
            decoration: rentalField(
              tokens,
              'ค้นหารหัสหรือชื่อลูกค้า',
            ).copyWith(prefixIcon: const Icon(Icons.search)),
            onSubmitted: (_) => setState(() {}),
          ),
        ),
      if (isItems || isHistory || code == '60004')
        FilledButton.icon(
          onPressed: () {
            page = 1;
            load();
          },
          icon: const Icon(Icons.search),
          label: const Text('ค้นหา'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 40),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(tokens.radius),
            ),
          ),
        ),
    ],
  );

  static const _statuses = <String>[
    'RESERVED',
    'PAID',
    'OUT',
    'PARTIAL_RETURN',
    'RETURNED',
    'SETTLEMENT',
    'CLOSED',
    'CANCELLED',
  ];
  String _statusLabel(String value) => switch (value) {
    'RESERVED' => 'รอชำระ',
    'PAID' => 'ชำระแล้ว',
    'OUT' => 'ส่งมอบแล้ว',
    'PARTIAL_RETURN' => 'คืนบางส่วน',
    'RETURNED' => 'คืนครบแล้ว',
    'SETTLEMENT' => 'รอคืนมัดจำ',
    'CLOSED' => 'ปิดรายการ',
    'CANCELLED' => 'ยกเลิก',
    _ => value,
  };

  List<String> get _columns => isItems
      ? [
          'id',
          'code',
          'name',
          'branchId',
          'rentalStock',
          'rateUnit',
          'rentalRate',
          'depositAmount',
          'isActive',
        ]
      : isAvailability
      ? ['code', 'name', 'stock', 'reserved', 'available', 'rate', 'deposit']
      : [
          'code',
          'branchName',
          'customerName',
          'startAt',
          'endAt',
          'rent',
          'deposit',
          'status',
        ];
  String _label(String key) => switch (key) {
    'id' => 'ID',
    'code' => isItems ? 'รหัสสินค้า' : 'เลขที่จอง',
    'name' => 'รายการ',
    'branchId' => 'สาขา',
    'branchName' => 'สาขา',
    'customerId' => 'ลูกค้า',
    'customerName' => 'ลูกค้า',
    'rentalStock' => 'คงเหลือ',
    'rateUnit' => 'หน่วย',
    'rentalRate' => 'ค่าเช่า',
    'depositAmount' || 'deposit' => 'มัดจำ',
    'isActive' => 'สถานะ',
    'stock' => 'สต๊อก',
    'reserved' => 'จองแล้ว',
    'available' => 'ว่าง',
    'rate' => 'ค่าเช่า',
    'startAt' => 'เริ่มเช่า',
    'endAt' => 'กำหนดคืน',
    'rent' => 'ค่าเช่า',
    'status' => 'สถานะ',
    _ => key,
  };
  String _value(RentalRow row, String key) {
    final value = row[key];
    if (value == null) return '—';
    if (value is bool) return value ? 'ใช้งาน' : 'ปิดใช้งาน';
    if (key == 'status') return _statusLabel(value.toString());
    if (key == 'rateUnit') {
      return value == 'HOUR'
          ? 'ชั่วโมง'
          : value == 'DAY'
          ? 'วัน'
          : '$value';
    }
    if (value is DateTime) return value.toLocal().toString().substring(0, 16);
    if (key.endsWith('At')) {
      final text = value.toString();
      final utc = DateTime.tryParse(text.endsWith('Z') ? text : '${text}Z');
      if (utc != null) {
        final local = utc.toLocal();
        return '${day(local)} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
      }
      return text;
    }
    return '$value';
  }

  List<RentalRow> get visibleRows {
    final query = search.text.trim().toLowerCase();
    if (query.isEmpty) return rows;
    return rows
        .where(
          (row) => _columns.any(
            (key) => _value(row, key).toLowerCase().contains(query),
          ),
        )
        .toList();
  }

  Widget rowActions(RentalRow row) {
    final actions = <Widget>[];
    if (code == '60002' && can('edit')) {
      actions.add(
        IconButton(
          tooltip: 'แก้ไข',
          onPressed: () => openForm(mode: 'edit', row: row),
          icon: Icon(Icons.edit_outlined, color: tokens.primaryColor),
        ),
      );
      actions.add(
        IconButton(
          tooltip: 'ย้ายสต๊อก',
          onPressed: () => openForm(row: row, action: 'transfer'),
          icon: Icon(Icons.swap_horiz, color: tokens.primaryColor),
        ),
      );
      if (can('delete')) {
        actions.add(
          IconButton(
            tooltip: 'ลบ',
            onPressed: () => confirmDelete(row),
            icon: const Icon(Icons.delete_outline, color: Colors.red),
          ),
        );
      }
    }
    if (code == '60004' &&
        ['RESERVED', 'PAID'].contains(row['status']) &&
        can('cancel')) {
      actions.add(
        TextButton(
          onPressed: () => cancelBooking(row),
          child: const Text('ยกเลิก'),
        ),
      );
    }
    if (code == '60005' &&
        can('create') &&
        ['RESERVED', 'SETTLEMENT'].contains(row['status'])) {
      actions.add(
        TextButton.icon(
          onPressed: () => openForm(row: row, action: 'payment'),
          icon: const Icon(Icons.payments_outlined),
          label: const Text('รับเงิน'),
        ),
      );
    }
    if (code == '60005' && can('view')) {
      actions.add(
        IconButton(
          tooltip: 'รายละเอียด/พิมพ์ใบรับเงิน',
          onPressed: () => openForm(row: row, action: 'detail'),
          icon: Icon(Icons.receipt_long_outlined, color: tokens.primaryColor),
        ),
      );
    }
    if (code == '60006' &&
        can('create') &&
        (row['status'] == 'PAID' ||
            (row['status'] == 'RESERVED' &&
                row['rent'] == 0 &&
                row['deposit'] == 0))) {
      actions.add(
        TextButton.icon(
          onPressed: () => openForm(row: row, action: 'handover'),
          icon: const Icon(Icons.outbox_outlined),
          label: const Text('ส่งมอบ'),
        ),
      );
    }
    if (code == '60007' &&
        can('create') &&
        ['OUT', 'PARTIAL_RETURN'].contains(row['status'])) {
      actions.add(
        TextButton.icon(
          onPressed: () => openForm(row: row, action: 'return'),
          icon: const Icon(Icons.assignment_return_outlined),
          label: const Text('รับคืน'),
        ),
      );
    }
    if (code == '60008' && ['RETURNED', 'SETTLEMENT'].contains(row['status'])) {
      if (row['status'] == 'RETURNED' && can('approve')) {
        actions.add(
          TextButton(
            onPressed: () => openForm(row: row, action: 'approve-settlement'),
            child: const Text('อนุมัติหัก'),
          ),
        );
      }
      if (row['status'] == 'SETTLEMENT' && can('refund')) {
        actions.add(
          TextButton(
            onPressed: () => openForm(row: row, action: 'refund'),
            child: const Text('คืนมัดจำ'),
          ),
        );
      }
    }
    if (code == '60008' && can('view')) {
      actions.add(
        IconButton(
          tooltip: 'รายละเอียด/พิมพ์ใบคืนเงิน',
          onPressed: () => openForm(row: row, action: 'detail'),
          icon: Icon(Icons.receipt_long_outlined, color: tokens.primaryColor),
        ),
      );
    }
    if (code == '60009') {
      actions.add(
        IconButton(
          tooltip: 'รายละเอียด',
          onPressed: () => openForm(row: row, action: 'detail'),
          icon: Icon(Icons.visibility_outlined, color: tokens.primaryColor),
        ),
      );
    }
    return Wrap(spacing: 2, children: actions);
  }

  Future<void> confirmDelete(RentalRow row) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) => _DeleteRentalDialog(
        tokens: tokens,
        value: '${row['code']} ${row['name']}',
      ),
    );
    if (accepted != true) return;
    try {
      await api.delete('$base/items/${row['id']}');
      if (mounted) {
        rentalMessage(context, message: 'ลบของเช่าแล้ว', error: false);
        await load();
      }
    } catch (e) {
      if (mounted) {
        rentalMessage(
          context,
          message: rentalErrorText(e, 'ลบของเช่า'),
          error: true,
        );
      }
    }
  }

  Widget tableContent() {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 32),
              const SizedBox(height: 8),
              Text(error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: load,
                icon: const Icon(Icons.refresh),
                label: const Text('ลองโหลดอีกครั้ง'),
              ),
            ],
          ),
        ),
      );
    }
    final filtered = visibleRows;
    final shown = (isItems || isAvailability)
        ? filtered.skip((page - 1) * 20).take(20).toList()
        : filtered;
    if (shown.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isItems ? Icons.inventory_2_outlined : Icons.event_busy_outlined,
              size: 36,
              color: tokens.primaryColor,
            ),
            const SizedBox(height: 8),
            Text(
              isItems
                  ? 'ยังไม่มีทะเบียนของเช่า'
                  : isAvailability
                  ? 'ไม่พบของว่างในช่วงเวลานี้'
                  : 'ยังไม่มีรายการตามตัวกรอง',
              style: tokens.sectionStyle,
            ),
            if (_canCreate) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => openForm(),
                icon: const Icon(Icons.add),
                label: const Text('เริ่มทำรายการ'),
              ),
            ],
          ],
        ),
      );
    }
    final cardMode = cards || MediaQuery.sizeOf(context).width < 900;
    if (cardMode) {
      return ListView.separated(
        padding: const EdgeInsets.all(10),
        itemCount: shown.length,
        separatorBuilder: (_, _) => SizedBox(height: tokens.itemSpacing),
        itemBuilder: (context, index) {
          final row = shown[index];
          return LaooSurfaceCard(
            tokens: tokens,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_value(row, _columns.first), style: tokens.sectionStyle),
                ..._columns
                    .skip(1)
                    .map(
                      (key) => Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Text(
                          '${_label(key)}: ${_value(row, key)}',
                          style: tokens.tableStyle,
                        ),
                      ),
                    ),
                if (!isAvailability)
                  Align(
                    alignment: Alignment.centerRight,
                    child: rowActions(row),
                  ),
              ],
            ),
          );
        },
      );
    }
    final cols = <DataColumn>[
      DataColumn(label: Text('ID', style: tokens.tableStyle)),
      DataColumn(label: Text('Action', style: tokens.tableStyle)),
      ..._columns.map(
        (key) => DataColumn(label: Text(_label(key), style: tokens.tableStyle)),
      ),
    ];
    return LaooWorkspaceDataTable(
      tokens: tokens,
      columns: cols,
      rows: shown.asMap().entries.map((entry) {
        final row = entry.value;
        return DataRow(
          cells: [
            DataCell(Text('${(page - 1) * 20 + entry.key + 1}')),
            DataCell(
              isAvailability ? const SizedBox.shrink() : rowActions(row),
            ),
            ..._columns.map(
              (key) => DataCell(
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 240),
                  child: Text(
                    _value(row, key),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget pagination() => LaooPaginationCard(
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
  );

  Widget settingsBody() => SingleChildScrollView(
    padding: tokens.contentMargin,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        caption(),
        SizedBox(height: tokens.sectionSpacing),
        if (loading) const LinearProgressIndicator(),
        if (error != null) ...[
          Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: load,
              icon: const Icon(Icons.refresh),
              label: const Text('ลองโหลดอีกครั้ง'),
            ),
          ),
        ],
        if (!loading && error == null)
          LaooSurfaceCard(
            tokens: tokens,
            child: _SettingsPanel(
              tokens: tokens,
              settings: settings,
              editable: can('edit') && screenType == 2,
              onSave: (next) async {
                setState(() => saving = true);
                try {
                  await api.put('$base/settings', body: next);
                  if (!mounted) return;
                  rentalMessage(
                    context,
                    message: 'บันทึกค่าระบบแล้ว',
                    error: false,
                  );
                  await load();
                } catch (e) {
                  if (mounted) {
                    rentalMessage(
                      context,
                      message: rentalErrorText(e, 'บันทึกค่าระบบ'),
                      error: true,
                    );
                  }
                } finally {
                  if (mounted) setState(() => saving = false);
                }
              },
              saving: saving,
            ),
          ),
      ],
    ),
  );

  Widget dashboardBody() {
    final summary = rentalRows(dashboard['summary']);
    final bookingCount = summary.fold<int>(
      0,
      (sum, item) => sum + ((item['bookings'] as num?)?.toInt() ?? 0),
    );
    final rent = summary.fold<double>(
      0,
      (sum, item) => sum + ((item['rent'] as num?)?.toDouble() ?? 0),
    );
    final active = summary
        .where((item) => !['CANCELLED', 'CLOSED'].contains(item['status']))
        .fold<int>(
          0,
          (sum, item) => sum + ((item['bookings'] as num?)?.toInt() ?? 0),
        );
    return SingleChildScrollView(
      padding: tokens.contentMargin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          caption(),
          SizedBox(height: tokens.sectionSpacing),
          LaooFilterCard(tokens: tokens, child: filter()),
          SizedBox(height: tokens.sectionSpacing),
          if (loading) const LinearProgressIndicator(),
          if (error != null)
            Row(
              children: [
                Expanded(
                  child: Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('ลองใหม่'),
                ),
              ],
            ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _Metric(
                tokens: tokens,
                label: 'รายการจอง',
                value: '$bookingCount',
                icon: Icons.event_note_outlined,
              ),
              _Metric(
                tokens: tokens,
                label: 'รายการที่ยังดำเนินการ',
                value: '$active',
                icon: Icons.pending_actions_outlined,
              ),
              _Metric(
                tokens: tokens,
                label: 'ยอดค่าเช่า',
                value: rent.toStringAsFixed(2),
                icon: Icons.payments_outlined,
              ),
            ],
          ),
          SizedBox(height: tokens.sectionSpacing),
          LaooSurfaceCard(
            tokens: tokens,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ของที่มีการจองสูง', style: tokens.sectionStyle),
                const SizedBox(height: 10),
                if (rows.isEmpty)
                  Text('ยังไม่มีข้อมูลในช่วงที่เลือก', style: tokens.tableStyle)
                else
                  ...rows.asMap().entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 32,
                            child: Text(
                              '${entry.key + 1}.',
                              style: tokens.sectionStyle,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              '${entry.value['code'] ?? ''} ${entry.value['name'] ?? ''}',
                              style: tokens.tableStyle,
                            ),
                          ),
                          Text(
                            '${entry.value['bookedUnits'] ?? 0} ชิ้น',
                            style: tokens.tableStyle,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget listBody() => LaooListWorkspace(
    tokens: tokens,
    caption: caption(),
    filter: filter(),
    table: tableContent(),
    pagination: pagination(),
  );

  @override
  Widget build(BuildContext context) {
    final route = RentalRoutes.all.firstWhere((r) => r.menuCode == code);
    return rentalShell(
      pageTitle: title,
      activeMenu: route.routeName,
      child: ColoredBox(
        color: tokens.backgroundColor,
        child: code == '60001'
            ? settingsBody()
            : isDashboard
            ? dashboardBody()
            : listBody(),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.tokens,
    required this.label,
    required this.value,
    required this.icon,
  });
  final LaooWorkspaceUiTokens tokens;
  final String label, value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 230,
    child: LaooSurfaceCard(
      tokens: tokens,
      child: Row(
        children: [
          Icon(icon, color: tokens.primaryColor, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: tokens.tableStyle),
                Text(value, style: tokens.sectionStyle),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _SettingsPanel extends StatefulWidget {
  const _SettingsPanel({
    required this.tokens,
    required this.settings,
    required this.editable,
    required this.onSave,
    required this.saving,
  });
  final LaooWorkspaceUiTokens tokens;
  final RentalRow settings;
  final bool editable, saving;
  final Future<void> Function(RentalRow) onSave;
  @override
  State<_SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<_SettingsPanel> {
  late final hold = TextEditingController(
    text: '${widget.settings['bookingHoldHours'] ?? 24}',
  );
  late final cancel = TextEditingController(
    text: '${widget.settings['cancelBeforeHours'] ?? 2}',
  );
  @override
  void dispose() {
    hold.dispose();
    cancel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text('เงื่อนไขการจอง', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 16),
      Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          SizedBox(
            width: 260,
            child: TextField(
              controller: hold,
              enabled: widget.editable,
              keyboardType: TextInputType.number,
              decoration: rentalField(
                widget.tokens,
                'หมดสิทธิ์จองที่ยังไม่ชำระ (ชั่วโมง) *',
              ),
            ),
          ),
          SizedBox(
            width: 260,
            child: TextField(
              controller: cancel,
              enabled: widget.editable,
              keyboardType: TextInputType.number,
              decoration: rentalField(
                widget.tokens,
                'ยกเลิกก่อนเริ่มอย่างน้อย (ชั่วโมง) *',
              ),
            ),
          ),
        ],
      ),
      if (widget.editable) ...[
        const SizedBox(height: 18),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: widget.saving
                ? null
                : () => widget.onSave({
                    'bookingHoldHours': int.tryParse(hold.text) ?? 0,
                    'cancelBeforeHours': int.tryParse(cancel.text) ?? -1,
                  }),
            icon: widget.saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(widget.saving ? 'กำลังบันทึก' : 'บันทึก'),
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ],
    ],
  );
}

class _DeleteRentalDialog extends StatelessWidget {
  const _DeleteRentalDialog({required this.tokens, required this.value});
  final LaooWorkspaceUiTokens tokens;
  final String value;
  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(4),
      side: const BorderSide(color: Colors.red),
    ),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.delete_outline, color: Colors.red),
                const SizedBox(width: 8),
                Text(
                  'ยืนยันการลบข้อมูล',
                  style: tokens.captionStyle.copyWith(color: Colors.red),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(value),
            ),
            const SizedBox(height: 8),
            const Text('ข้อมูลที่ลบแล้วไม่สามารถเรียกคืนได้'),
            const SizedBox(height: 12),
            Divider(color: tokens.borderColor),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('ยกเลิก'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () => Navigator.pop(context, true),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('ลบ'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
