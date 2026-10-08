import 'package:flutter/material.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';
import 'host.dart';
import 'routes.dart';
import 'sport_forms.dart';

typedef SportRow = Map<String, dynamic>;
SportRow sportMap(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
List<SportRow> sportRows(dynamic value) =>
    value is List ? value.map(sportMap).toList() : <SportRow>[];

class SportPage extends StatefulWidget {
  const SportPage({super.key, required this.menuCode});
  final String menuCode;
  @override
  State<SportPage> createState() => _SportPageState();
}

class _SportPageState extends State<SportPage> {
  static const base = '/api/company/sport';
  late final api = sportApi();
  final search = TextEditingController();
  SportRow actions = {},
      paymentActions = {},
      metadata = {},
      settings = {},
      dashboard = {};
  List<SportRow> rows = [],
      people = [],
      branches = [],
      members = [],
      facilities = [],
      levels = [],
      sports = [],
      packages = [];
  bool loading = true, saving = false, cards = false;
  String? error;
  int page = 1;
  int? selectedBranchId, selectedSportId;
  DateTime from = DateTime.now().subtract(const Duration(days: 30));
  DateTime to = DateTime.now();
  String get code => widget.menuCode;
  String get title => metadata['MenuName']?.toString() ?? 'ระบบกีฬา';
  int get screenType => (metadata['ScreenType'] as num?)?.toInt() ?? 0;
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
  void dispose() {
    search.dispose();
    sportDispose(api);
    super.dispose();
  }

  String date(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  String get start => '${date(from)}T00:00:00+07:00';
  String get end => '${date(to.add(const Duration(days: 1)))}T00:00:00+07:00';

  Future<void> load() async {
    if (!mounted) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final access = sportMap(await api.get('$base/actions/$code'));
      actions = sportMap(access['actions']);
      metadata = sportMap(access['metadata']);
      if (!can('view')) throw StateError('ไม่มีสิทธิ์เปิดหน้าจอนี้');
      if (code == '54011' && branches.isEmpty && sports.isEmpty) {
        await loadOptions();
      }
      if (code == '54008') {
        try {
          paymentActions = sportMap(
            sportMap(await api.get('$base/actions/54007'))['actions'],
          );
        } catch (_) {
          paymentActions = {};
        }
      }
      dynamic result;
      switch (code) {
        case '54001':
          settings = sportMap(await api.get('$base/settings'));
          result = const [];
          break;
        case '54002':
          result = await api.get('$base/sport-types');
          break;
        case '54003':
          result = await api.get('$base/facilities');
          break;
        case '54004':
          result = await api.get('$base/levels');
          break;
        case '54005':
          result = await api.get('$base/packages');
          break;
        case '54006':
          result = await api.get(
            '$base/members',
            query: {'page': '$page', 'search': search.text},
          );
          break;
        case '54007':
          result = await api.get('$base/memberships', query: {'page': '$page'});
          break;
        case '54008':
          result = await api.get(
            '$base/bookings',
            query: {'from': start, 'to': end},
          );
          break;
        case '54009':
          result = await api.get(
            '$base/checkins',
            query: {'from': start, 'to': end},
          );
          break;
        case '54010':
          result = await api.get('$base/pos-pricing');
          break;
        case '54011':
          dashboard = sportMap(
            await api.get(
              '$base/dashboard',
              query: {
                'from': date(from),
                'to': date(to),
                if (selectedBranchId != null) 'branchId': '$selectedBranchId',
                if (selectedSportId != null) 'sportTypeId': '$selectedSportId',
              },
            ),
          );
          result = dashboard['sports'];
          break;
      }
      rows = sportRows(result);
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          error = e.toString();
        });
      }
    }
  }

  Future<void> loadOptions() async {
    if (!{
      '54003',
      '54005',
      '54006',
      '54007',
      '54008',
      '54010',
      '54011',
    }.contains(code)) {
      return;
    }
    final options = sportMap(await api.get('$base/options/$code'));
    people = sportRows(options['people']);
    branches = sportRows(options['branches']);
    sports = sportRows(options['sports']);
    levels = sportRows(options['levels']);
    facilities = sportRows(options['facilities']);
    packages = sportRows(options['packages']);
    members = sportRows(options['members']);
  }

  Future<void> openForm([SportRow? row]) async {
    if (saving || !(row == null ? can('create') || can('edit') : can('edit'))) {
      return;
    }
    try {
      await loadOptions();
      if (!mounted) return;
      final changed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialog) => SportForm(
          code: code,
          title: title,
          iconName: metadata['IconName']?.toString(),
          row: row,
          settings: settings,
          sports: sports,
          levels: levels,
          people: people,
          branches: branches,
          facilities: facilities,
          packages: packages,
          members: members,
          api: api,
          tokens: sportTokens(),
        ),
      );
      if (!mounted) return;
      if (changed == true) {
        sportMessage(context, message: 'บันทึกข้อมูลแล้ว', error: false);
        await load();
      }
    } catch (e) {
      if (mounted) sportMessage(context, message: e.toString(), error: true);
    }
  }

  Future<void> chooseDates() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(start: from, end: to),
    );
    if (range == null) return;
    from = range.start;
    to = range.end;
    await load();
  }

  String value(SportRow row, String key) {
    final v = row[key];
    if (v == null) return '—';
    if (v is bool) return v ? 'ใช้งาน' : 'ปิดใช้งาน';
    return '$v';
  }

  List<String> get columns => switch (code) {
    '54002' => ['code', 'name', 'active'],
    '54003' => ['code', 'name', 'sport', 'capacity', 'active'],
    '54004' => ['code', 'name', 'resident', 'active'],
    '54005' => ['code', 'name', 'days', 'quota', 'price', 'active'],
    '54006' => ['code', 'name', 'level', 'gender', 'active'],
    '54007' => [
      'memberName',
      'packageName',
      'startsOn',
      'endsOn',
      'price',
      'status',
    ],
    '54008' || '54009' => [
      'facility',
      'memberName',
      'startsAt',
      'endsAt',
      'status',
      'price',
    ],
    '54010' => ['level', 'priceLevel', 'active'],
    '54011' => ['name', 'bookings', 'checkIns'],
    _ => [],
  };
  String label(String key) => switch (key) {
    'code' => 'รหัส',
    'name' => 'ชื่อ',
    'active' => 'สถานะ',
    'sport' => 'ประเภทกีฬา',
    'capacity' => 'ความจุ',
    'resident' => 'ผู้พักอาศัย',
    'days' => 'จำนวนวัน',
    'quota' => 'โควตา',
    'price' => 'ราคา',
    'level' => 'ระดับสมาชิก',
    'gender' => 'เพศ',
    'packageName' => 'แพ็กเกจ',
    'startsOn' || 'startsAt' => 'เริ่ม',
    'endsOn' || 'endsAt' => 'สิ้นสุด',
    'status' => 'สถานะ',
    'facility' => 'สนาม',
    'memberName' => 'สมาชิก',
    'priceLevelCode' => 'ระดับราคา POS',
    'priceLevel' => 'ระดับราคา POS',
    'bookings' => 'จอง',
    'checkIns' => 'เข้าเล่น',
    _ => key,
  };

  Widget buildActions(SportRow row) {
    final buttons = <Widget>[];
    if (can('edit') &&
        {'54002', '54003', '54004', '54005', '54006', '54010'}.contains(code)) {
      buttons.add(
        IconButton(
          tooltip: 'แก้ไข',
          onPressed: () => openForm(row),
          icon: Icon(Icons.edit_outlined, color: sportTokens().primaryColor),
        ),
      );
    }
    if (can('delete') &&
        {'54002', '54003', '54004', '54005', '54006'}.contains(code)) {
      buttons.add(
        IconButton(
          tooltip: 'ลบ',
          onPressed: () => deleteRow(row),
          icon: const Icon(Icons.delete_outline, color: Colors.red),
        ),
      );
    }
    if (code == '54008' || code == '54009') {
      final status = '${row['status']}';
      if (status == 'PENDING_PAYMENT' &&
          paymentActions['record_payment'] == true) {
        buttons.add(
          TextButton(
            onPressed: () => bookingAction(row, 'pay'),
            child: const Text('รับเงิน'),
          ),
        );
      }
      if (status == 'CONFIRMED' && can('check_in')) {
        buttons.add(
          TextButton(
            onPressed: () => bookingAction(row, 'check-in'),
            child: const Text('เช็กอิน'),
          ),
        );
      }
      if (status == 'CONFIRMED' && can('mark_no_show')) {
        buttons.add(
          TextButton(
            onPressed: () => bookingAction(row, 'no-show'),
            child: const Text('ไม่มา'),
          ),
        );
      }
      if ((status == 'CONFIRMED' || status == 'PENDING_PAYMENT') &&
          can('cancel')) {
        buttons.add(
          TextButton(
            onPressed: () => bookingAction(row, 'cancel'),
            child: const Text('ยกเลิก'),
          ),
        );
      }
    }
    return Wrap(
      spacing: 2,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: buttons,
    );
  }

  Future<void> deleteRow(SportRow row) async {
    final ok = await sportConfirmDelete(
      context,
      '${row['code']}  ${row['name']}',
    );
    if (!ok) return;
    final path = switch (code) {
      '54002' => 'sport-types',
      '54003' => 'facilities',
      '54004' => 'levels',
      '54005' => 'packages',
      '54006' => 'members',
      _ => '',
    };
    if (path.isEmpty) return;
    try {
      await api.delete('$base/$path/${row['id']}');
      if (mounted) {
        sportMessage(context, message: 'ลบข้อมูลแล้ว', error: false);
        await load();
      }
    } catch (e) {
      if (mounted) sportMessage(context, message: e.toString(), error: true);
    }
  }

  Future<void> bookingAction(SportRow row, String action) async {
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialog) => SportBookingAction(
        api: api,
        tokens: sportTokens(),
        booking: row,
        action: action,
      ),
    );
    if (changed == true && mounted) {
      sportMessage(context, message: 'บันทึกสถานะแล้ว', error: false);
      await load();
    }
  }

  Widget tableOrCards() {
    final t = sportTokens();
    final shown = rows
        .where(
          (r) =>
              code == '54006' ||
              search.text.isEmpty ||
              columns.any(
                (key) => value(
                  r,
                  key,
                ).toLowerCase().contains(search.text.toLowerCase()),
              ),
        )
        .toList();
    final pageRows = {'54006', '54007'}.contains(code)
        ? shown
        : shown.skip((page - 1) * 10).take(10).toList();
    if (shown.isEmpty) {
      return LaooSurfaceCard(
        tokens: t,
        child: const Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: Text('ยังไม่มีรายการ')),
        ),
      );
    }
    if (cards || MediaQuery.sizeOf(context).width < 700) {
      return Column(
        children: pageRows
            .map(
              (row) => Padding(
                padding: EdgeInsets.only(bottom: t.itemSpacing),
                child: LaooSurfaceCard(
                  tokens: t,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(value(row, columns.first), style: t.sectionStyle),
                      ...columns
                          .skip(1)
                          .map(
                            (key) => Padding(
                              padding: const EdgeInsets.only(top: 5),
                              child: Text(
                                '${label(key)}: ${value(row, key)}',
                                style: t.tableStyle,
                              ),
                            ),
                          ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: buildActions(row),
                      ),
                    ],
                  ),
                ),
              ),
            )
            .toList(),
      );
    }
    return LaooTableCard(
      tokens: t,
      child: LayoutBuilder(
        builder: (context, size) => SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: size.maxWidth),
            child: DataTable(
              columns: [
                ...columns.map(
                  (key) =>
                      DataColumn(label: Text(label(key), style: t.tableStyle)),
                ),
                DataColumn(label: Text('จัดการ', style: t.tableStyle)),
              ],
              rows: pageRows
                  .map(
                    (row) => DataRow(
                      cells: [
                        ...columns.map(
                          (key) => DataCell(
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 260),
                              child: Text(
                                value(row, key),
                                overflow: TextOverflow.ellipsis,
                                style: t.tableStyle,
                              ),
                            ),
                          ),
                        ),
                        DataCell(buildActions(row)),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget settingCards() {
    final t = sportTokens();
    const labels = {
      'PaymentHoldMinutes': 'เวลารอชำระค่าจอง (นาที)',
      'CancelBeforeMinutes': 'ยกเลิกล่วงหน้าก่อนเริ่ม (นาที)',
      'CheckInGraceMinutes': 'เวลาเผื่อเช็กอิน (นาที)',
      'ExpiryNoticeDays': 'แจ้งใกล้หมดอายุ (วัน)',
    };
    return LaooSurfaceCard(
      tokens: t,
      child: Wrap(
        spacing: 24,
        runSpacing: 12,
        children: labels.entries
            .map(
              (entry) => SizedBox(
                width: 220,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.value, style: t.tableStyle),
                    Text(
                      '${settings[entry.key] ?? '—'}',
                      style: t.sectionStyle,
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget dashboardCards() {
    final t = sportTokens();
    final summary = sportMap(dashboard['summary']);
    const labels = {
      'bookings': 'การจอง',
      'checkIns': 'เข้าเล่น',
      'noShows': 'ไม่มา',
      'cancelled': 'ยกเลิก',
      'bookingRevenue': 'ยอดค่าจอง',
    };
    return Wrap(
      spacing: t.sectionSpacing,
      runSpacing: t.sectionSpacing,
      children: labels.entries
          .map(
            (entry) => SizedBox(
              width: 190,
              child: LaooSurfaceCard(
                tokens: t,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.value, style: t.tableStyle),
                    const SizedBox(height: 6),
                    Text(
                      '${summary[entry.key] ?? 0}',
                      style: t.captionStyle.copyWith(color: t.primaryColor),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget dashboardBreakdown(
    String heading,
    List<SportRow> items,
    String nameKey,
    String countKey,
  ) {
    final t = sportTokens();
    return LaooSurfaceCard(
      tokens: t,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(heading, style: t.sectionStyle),
          const SizedBox(height: 8),
          if (items.isEmpty) Text('ยังไม่มีข้อมูล', style: t.tableStyle),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(value(item, nameKey), style: t.tableStyle),
                  ),
                  Text(value(item, countKey), style: t.tableStyle),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget filters() {
    final t = sportTokens();
    return LaooFilterCard(
      tokens: t,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (code == '54006' ||
              {'54002', '54003', '54004', '54005', '54010'}.contains(code))
            SizedBox(
              width: 300,
              child: TextField(
                controller: search,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'ค้นหารายการ',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) {
                  page = 1;
                  if (code == '54006') {
                    load();
                  } else {
                    setState(() {});
                  }
                },
              ),
            ),
          if ({'54008', '54009', '54011'}.contains(code))
            OutlinedButton.icon(
              onPressed: chooseDates,
              icon: const Icon(Icons.date_range_outlined),
              label: Text('${date(from)} — ${date(to)}'),
            ),
          if (code == '54011')
            SizedBox(
              width: 210,
              child: DropdownButtonFormField<int>(
                initialValue: selectedBranchId,
                decoration: const InputDecoration(
                  labelText: 'สาขา',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<int>(
                    value: null,
                    child: Text('ทุกสาขา'),
                  ),
                  ...branches.map(
                    (b) => DropdownMenuItem<int>(
                      value: (b['id'] as num).toInt(),
                      child: Text(
                        '${b['name']}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: (id) {
                  selectedBranchId = id;
                  load();
                },
              ),
            ),
          if (code == '54011')
            SizedBox(
              width: 210,
              child: DropdownButtonFormField<int>(
                initialValue: selectedSportId,
                decoration: const InputDecoration(
                  labelText: 'กีฬา',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<int>(
                    value: null,
                    child: Text('ทุกประเภท'),
                  ),
                  ...sports.map(
                    (s) => DropdownMenuItem<int>(
                      value: (s['id'] as num).toInt(),
                      child: Text(
                        '${s['name']}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: (id) {
                  selectedSportId = id;
                  load();
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget pager() {
    final t = sportTokens();
    final hasMore = {'54006', '54007'}.contains(code)
        ? rows.length >= 20
        : page * 10 < rows.length;
    if (page == 1 && !hasMore) return const SizedBox.shrink();
    return LaooSurfaceCard(
      tokens: t,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          IconButton(
            tooltip: 'ก่อนหน้า',
            onPressed: page > 1
                ? () {
                    page--;
                    if ({'54006', '54007'}.contains(code)) {
                      load();
                    } else {
                      setState(() {});
                    }
                  }
                : null,
            icon: const Icon(Icons.chevron_left),
          ),
          Text('หน้า $page', style: t.tableStyle),
          IconButton(
            tooltip: 'ถัดไป',
            onPressed: hasMore
                ? () {
                    page++;
                    if ({'54006', '54007'}.contains(code)) {
                      load();
                    } else {
                      setState(() {});
                    }
                  }
                : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = sportTokens();
    final route = SportRoutes.all.firstWhere((r) => r.menuCode == code);
    final editable = code == '54001';
    final showAdd =
        (editable ? can('edit') : can('create')) &&
        !{'54009', '54010', '54011'}.contains(code);
    return sportShell(
      pageTitle: title,
      activeMenu: route.routeName,
      child: ColoredBox(
        color: t.backgroundColor,
        child: SingleChildScrollView(
          padding: t.contentMargin,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LaooCaptionCard(
                tokens: t,
                caption: title,
                favoriteKey: route.routeName,
                leading: Icon(
                  sportMenuIcon(metadata['IconName']?.toString()),
                  color: t.primaryColor,
                ),
                trailing: Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (!{'54001', '54011'}.contains(code))
                      IconButton(
                        tooltip: cards ? 'แสดงรายการ' : 'แสดงการ์ด',
                        onPressed: () => setState(() => cards = !cards),
                        icon: Icon(
                          cards
                              ? Icons.table_rows_outlined
                              : Icons.grid_view_outlined,
                          color: t.primaryColor,
                        ),
                      ),
                    if (showAdd)
                      FilledButton.icon(
                        onPressed: () => openForm(),
                        icon: Icon(editable ? Icons.edit_outlined : Icons.add),
                        label: Text(editable ? 'แก้ไข' : 'เพิ่ม'),
                      ),
                  ],
                ),
              ),
              SizedBox(height: t.sectionSpacing),
              if (!{'54001'}.contains(code)) ...[
                filters(),
                SizedBox(height: t.sectionSpacing),
              ],
              if (loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(48),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (error != null)
                LaooSurfaceCard(
                  tokens: t,
                  child: Column(
                    children: [
                      Text('โหลดข้อมูลไม่สำเร็จ', style: t.sectionStyle),
                      const SizedBox(height: 8),
                      Text(error!, style: t.tableStyle),
                      TextButton.icon(
                        onPressed: load,
                        icon: const Icon(Icons.refresh),
                        label: const Text('ลองอีกครั้ง'),
                      ),
                    ],
                  ),
                )
              else ...[
                if (code == '54001') settingCards(),
                if (code == '54011') ...[
                  dashboardCards(),
                  SizedBox(height: t.sectionSpacing),
                  Wrap(
                    spacing: t.sectionSpacing,
                    runSpacing: t.sectionSpacing,
                    children: [
                      SizedBox(
                        width: 280,
                        child: dashboardBreakdown(
                          'สมาชิกตามเพศ',
                          sportRows(dashboard['gender']),
                          'code',
                          'members',
                        ),
                      ),
                      SizedBox(
                        width: 280,
                        child: dashboardBreakdown(
                          'สมาชิกตามช่วงอายุ',
                          sportRows(dashboard['age']),
                          'ageRange',
                          'members',
                        ),
                      ),
                      SizedBox(
                        width: 320,
                        child: dashboardBreakdown(
                          'สมาชิกใกล้หมดอายุ (ผู้ดูแล)',
                          sportRows(dashboard['expiring']),
                          'name',
                          'endsOn',
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: t.sectionSpacing),
                ],
                if (code != '54001') tableOrCards(),
                if (code != '54001') ...[
                  SizedBox(height: t.sectionSpacing),
                  pager(),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
