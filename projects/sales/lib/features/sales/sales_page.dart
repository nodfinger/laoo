import 'package:flutter/material.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';
import 'sales_feature_host.dart';

class SalesPage extends StatefulWidget {
  const SalesPage({
    required this.menuCode,
    required this.title,
    required this.endpoint,
    super.key,
  });
  final String menuCode, title, endpoint;
  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  late final JsonApiClient api = createSalesApiClient();
  late Future<Map<String, dynamic>> future;
  final search = TextEditingController();
  late String title;
  String query = '';
  int page = 1;
  bool cards = false;
  bool get settings => widget.endpoint == 'settings';
  bool get reports => widget.endpoint == 'reports';
  bool get myTasks => widget.endpoint == 'my-tasks';
  @override
  void initState() {
    super.initState();
    title = widget.title;
    future = load();
    resolveSalesMenuTitle(widget.menuCode, title).then((v) {
      if (mounted) setState(() => title = v);
    });
  }

  Future<Map<String, dynamic>> load() async {
    final values = await Future.wait<dynamic>([
      api.get('/api/company/sales/${widget.endpoint}'),
      api.get('/api/company/sales/actions/${widget.menuCode}'),
      if (!reports) api.get('/api/company/sales/options'),
    ]);
    return {
      'data': values[0],
      'actions': map(values[1]),
      'options': values.length > 2 ? map(values[2]) : <String, dynamic>{},
    };
  }

  void reload() => setState(() => future = load());
  @override
  void dispose() {
    search.dispose();
    disposeSalesApiClient(api);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => buildSalesWorkspaceShell(
    pageTitle: title,
    activeMenu: widget.menuCode,
    child: Padding(
      padding: salesUiTokens.contentMargin,
      child: FutureBuilder<Map<String, dynamic>>(
        future: future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return frame(state('กำลังโหลดข้อมูล...'));
          }
          if (snap.hasError) {
            return frame(state('โหลดข้อมูลไม่สำเร็จ', retry: true));
          }
          final value = snap.data!;
          final data = value['data'];
          final actions = map(value['actions']);
          final options = map(value['options']);
          if (settings) {
            return settingsView(rows(data).firstOrNull ?? {}, actions, options);
          }
          if (reports) return reportView(map(data));
          return listView(rows(data), actions, options);
        },
      ),
    ),
  );
  Widget caption({Widget? trailing}) => LaooCaptionCard(
    tokens: salesUiTokens,
    leading: Icon(
      Icons.trending_up_outlined,
      color: salesUiTokens.primaryColor,
    ),
    caption: title,
    trailing: trailing,
  );
  Widget frame(Widget child) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      caption(),
      SizedBox(height: salesUiTokens.sectionSpacing),
      Expanded(child: child),
    ],
  );

  Widget listView(
    List<Map<String, dynamic>> source,
    Map<String, dynamic> actions,
    Map<String, dynamic> options,
  ) {
    const size = 10;
    final filtered = source
        .where((e) => e.values.join(' ').toLowerCase().contains(query))
        .toList();
    final pages = (filtered.length / size).ceil().clamp(1, 999);
    if (page > pages) page = pages;
    final visible = filtered.skip((page - 1) * size).take(size).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        caption(
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              LaooListCardToggle(
                tokens: salesUiTokens,
                cards: cards,
                onChanged: (v) => setState(() => cards = v),
              ),
              if (!myTasks && actions['create'] == true) ...[
                const SizedBox(width: 6),
                FilledButton.icon(
                  onPressed: () => edit(null, options),
                  icon: const Icon(Icons.add),
                  label: const Text('เพิ่ม'),
                ),
              ],
            ],
          ),
        ),
        SizedBox(height: salesUiTokens.sectionSpacing),
        LaooFilterCard(
          tokens: salesUiTokens,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SizedBox(
                width: 300,
                child: TextField(
                  controller: search,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    labelText: 'ค้นหารหัสหรือชื่อ',
                  ),
                  onSubmitted: (_) => applySearch(),
                ),
              ),
              FilledButton.icon(
                onPressed: applySearch,
                icon: const Icon(Icons.search),
                label: const Text('ค้นหา'),
              ),
              OutlinedButton.icon(
                onPressed: clearSearch,
                icon: const Icon(Icons.filter_alt_off),
                label: const Text('ล้าง Filter'),
              ),
            ],
          ),
        ),
        SizedBox(height: salesUiTokens.sectionSpacing),
        Expanded(
          child: LaooTableCard(
            tokens: salesUiTokens,
            child: visible.isEmpty
                ? empty()
                : cards
                ? cardRows(visible, actions, options)
                : tableRows(visible, actions, options),
          ),
        ),
        SizedBox(height: salesUiTokens.sectionSpacing),
        LaooPaginationCard(
          tokens: salesUiTokens,
          page: page,
          pageCount: pages,
          pageSize: size,
          total: filtered.length,
          onPrevious: page > 1 ? () => setState(() => page--) : null,
          onNext: page < pages ? () => setState(() => page++) : null,
        ),
      ],
    );
  }

  void applySearch() => setState(() {
    query = search.text.trim().toLowerCase();
    page = 1;
  });
  void clearSearch() {
    search.clear();
    setState(() {
      query = '';
      page = 1;
    });
  }

  Widget tableRows(
    List<Map<String, dynamic>> data,
    Map<String, dynamic> actions,
    Map<String, dynamic> options,
  ) => LaooWorkspaceDataTable(
    tokens: salesUiTokens,
    columns: const [
      LaooWorkspaceTableColumns.id,
      DataColumn(label: Text('จัดการ')),
      DataColumn(label: Text('รหัส')),
      DataColumn(label: Text('ชื่อ/หัวข้อ')),
      DataColumn(label: Text('ขั้นตอน/ประเภท')),
      DataColumn(label: Text('สถานะ')),
    ],
    rows: data
        .asMap()
        .entries
        .map(
          (e) => DataRow(
            cells: [
              DataCell(Text('${e.key + 1 + (page - 1) * 10}')),
              DataCell(rowActions(e.value, actions, options)),
              DataCell(Text(first(e.value, ['code']))),
              DataCell(
                _tableCellText(
                  first(e.value, ['name', 'title']),
                  width: 320,
                  maxLines: 2,
                ),
              ),
              DataCell(
                _tableCellText(
                  first(e.value, ['stage', 'type', 'customer']),
                  width: 180,
                ),
              ),
              DataCell(
                _tableCellText(
                  first(e.value, ['status', 'active']),
                  width: 140,
                ),
              ),
            ],
          ),
        )
        .toList(),
  );
  Widget cardRows(
    List<Map<String, dynamic>> data,
    Map<String, dynamic> actions,
    Map<String, dynamic> options,
  ) => SingleChildScrollView(
    padding: salesUiTokens.cardPadding,
    child: Wrap(
      spacing: 8,
      runSpacing: 8,
      children: data
          .map(
            (item) => SizedBox(
              width: 330,
              child: LaooSurfaceCard(
                tokens: salesUiTokens,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      first(item, ['name', 'title', 'code']),
                      style: salesUiTokens.sectionStyle,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${first(item, ['code'])} • ${first(item, ['stage', 'type', 'customer'])}',
                      style: salesUiTokens.inputStyle,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      first(item, ['status', 'active']),
                      style: salesUiTokens.tableStyle,
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: rowActions(item, actions, options),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    ),
  );
  Widget _tableCellText(
    String value, {
    required double width,
    int maxLines = 1,
  }) => SizedBox(
    width: width,
    child: Text(
      value,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      softWrap: maxLines > 1,
    ),
  );

  Widget rowActions(
    Map<String, dynamic> item,
    Map<String, dynamic> actions,
    Map<String, dynamic> options,
  ) {
    final buttons = <Widget>[
      if (actions['edit'] == true && (!myTasks || item['status'] != 'DONE'))
        _actionButton(
          tooltip: 'แก้ไข',
          onPressed: () => edit(item, options),
          icon: Icons.edit_outlined,
          color: salesUiTokens.primaryColor,
        ),
      if (!myTasks && actions['delete'] == true)
        _actionButton(
          tooltip: 'ลบ',
          onPressed: () => remove(item),
          icon: Icons.delete_outline,
          color: Theme.of(context).colorScheme.error,
        ),
      if (widget.endpoint == 'leads' &&
          item['status'] != 'CONVERTED' &&
          actions['convert'] == true)
        _actionButton(
          tooltip: 'เปลี่ยนเป็นลูกค้า',
          onPressed: () => convert(item, options),
          icon: Icons.person_add_alt_outlined,
          color: salesUiTokens.primaryColor,
        ),
      if (widget.endpoint == 'opportunities' &&
          item['status'] == 'OPEN' &&
          actions['close'] == true)
        _actionButton(
          tooltip: 'ปิดการขาย',
          onPressed: () => closeOpportunity(item),
          icon: Icons.task_alt,
          color: salesUiTokens.primaryColor,
        ),
    ];
    if (buttons.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      width: buttons.length * 36,
      child: Row(mainAxisSize: MainAxisSize.min, children: buttons),
    );
  }

  Widget _actionButton({
    required String tooltip,
    required VoidCallback onPressed,
    required IconData icon,
    required Color color,
  }) => IconButton(
    tooltip: tooltip,
    onPressed: onPressed,
    constraints: const BoxConstraints.tightFor(width: 36, height: 36),
    padding: EdgeInsets.zero,
    visualDensity: VisualDensity.compact,
    icon: Icon(icon, color: color, size: 21),
  );

  Future<void> remove(Map<String, dynamic> item) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: Colors.red),
          borderRadius: BorderRadius.circular(salesUiTokens.radius),
        ),
        title: const Row(
          children: [
            Icon(Icons.delete_outline, color: Colors.red),
            SizedBox(width: 10),
            Text('ยืนยันการลบ', style: TextStyle(color: Colors.red)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Divider(),
            Container(
              padding: salesUiTokens.cardPadding,
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(salesUiTokens.radius),
              ),
              child: Text(first(item, ['code', 'name', 'title'])),
            ),
            const SizedBox(height: 12),
            const Text('ข้อมูลที่ลบแล้วไม่สามารถเรียกคืนได้'),
            const SizedBox(height: 12),
            const Divider(height: 1),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialog, true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (accepted != true) return;
    try {
      await api.delete('/api/company/sales/${widget.endpoint}/${item['id']}');
      success('ลบข้อมูลแล้ว');
    } catch (e) {
      failure('ลบข้อมูลไม่สำเร็จ');
    }
  }

  Widget settingsView(
    Map<String, dynamic> item,
    Map<String, dynamic> actions,
    Map<String, dynamic> options,
  ) {
    final enabled = ValueNotifier<bool>(item['isEnabled'] != false);
    final idle = TextEditingController(text: '${item['leadIdleDays'] ?? 14}');
    final reminder = TextEditingController(
      text: '${item['activityReminderDays'] ?? 2}',
    );
    final stages = rows(options['stages']);
    String? defaultStage = item['defaultStageID']?.toString();
    String? won = item['wonStageID']?.toString();
    String? lost = item['lostStageID']?.toString();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        caption(),
        SizedBox(height: salesUiTokens.sectionSpacing),
        Expanded(
          child: LaooSurfaceCard(
            tokens: salesUiTokens,
            child: SingleChildScrollView(
              child: StatefulBuilder(
                builder: (context, setLocal) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ค่าการทำงานปัจจุบัน',
                      style: salesUiTokens.sectionStyle,
                    ),
                    const Divider(),
                    ValueListenableBuilder<bool>(
                      valueListenable: enabled,
                      builder: (_, value, _) => SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('เปิดใช้งานระบบขาย'),
                        value: value,
                        onChanged: actions['edit'] == true
                            ? (next) => enabled.value = next
                            : null,
                      ),
                    ),
                    Wrap(
                      spacing: 12,
                      runSpacing: 16,
                      children: [
                        field(
                          idle,
                          'แจ้งเตือน Lead ไม่เคลื่อนไหว (วัน)',
                          number: true,
                        ),
                        field(
                          reminder,
                          'แจ้งเตือนกิจกรรมล่วงหน้า (วัน)',
                          number: true,
                        ),
                        select(
                          stages,
                          defaultStage,
                          'ขั้นตอนเริ่มต้น',
                          (value) => setLocal(() => defaultStage = value),
                        ),
                        select(
                          stages,
                          won,
                          'ขั้นตอนปิดชนะ',
                          (value) => setLocal(() => won = value),
                          type: 'WON',
                        ),
                        select(
                          stages,
                          lost,
                          'ขั้นตอนปิดแพ้',
                          (value) => setLocal(() => lost = value),
                          type: 'LOST',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (actions['edit'] == true)
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.icon(
                          onPressed: () async {
                            try {
                              await api.put(
                                '/api/company/sales/settings',
                                body: {
                                  'isEnabled': enabled.value,
                                  'leadIdleDays': int.tryParse(idle.text),
                                  'activityReminderDays': int.tryParse(
                                    reminder.text,
                                  ),
                                  'defaultStageID': int.tryParse(
                                    defaultStage ?? '',
                                  ),
                                  'wonStageID': int.tryParse(won ?? ''),
                                  'lostStageID': int.tryParse(lost ?? ''),
                                },
                              );
                              success('บันทึกการตั้งค่าแล้ว');
                            } catch (_) {
                              failure('บันทึกการตั้งค่าไม่สำเร็จ');
                            }
                          },
                          icon: const Icon(Icons.save_outlined),
                          label: const Text('บันทึก'),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget reportView(Map<String, dynamic> data) {
    final summary = (rows(data['summary']).firstOrNull ?? {});
    final pipeline = rows(data['pipeline']);
    final metrics = [
      ('มูลค่า Pipeline', summary['pipelineValue']),
      ('มูลค่าถ่วงน้ำหนัก', summary['weightedValue']),
      ('Lead ทั้งหมด', summary['leadCount']),
      ('Lead ที่แปลงแล้ว', summary['convertedLeadCount']),
      ('ชนะ', summary['wonCount']),
      ('กิจกรรมเกินกำหนด', summary['overdueActivities']),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        caption(),
        SizedBox(height: salesUiTokens.sectionSpacing),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: metrics
              .map(
                (m) => SizedBox(
                  width: 210,
                  child: LaooSurfaceCard(
                    tokens: salesUiTokens,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m.$1, style: salesUiTokens.inputStyle),
                        const SizedBox(height: 6),
                        Text('${m.$2 ?? 0}', style: salesUiTokens.sectionStyle),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        SizedBox(height: salesUiTokens.sectionSpacing),
        Expanded(
          child: LaooTableCard(
            tokens: salesUiTokens,
            child: pipeline.isEmpty
                ? empty()
                : LaooWorkspaceDataTable(
                    tokens: salesUiTokens,
                    columns: const [
                      DataColumn(label: Text('ขั้นตอน')),
                      DataColumn(label: Text('จำนวน')),
                      DataColumn(label: Text('มูลค่า')),
                    ],
                    rows: pipeline
                        .map(
                          (e) => DataRow(
                            cells: [
                              DataCell(Text('${e['stage']}')),
                              DataCell(Text('${e['itemCount']}')),
                              DataCell(Text('${e['amount']}')),
                            ],
                          ),
                        )
                        .toList(),
                  ),
          ),
        ),
      ],
    );
  }

  Future<void> edit(
    Map<String, dynamic>? item,
    Map<String, dynamic> options,
  ) async {
    item ??= {};
    final code = TextEditingController(text: '${item['code'] ?? ''}');
    final name = TextEditingController(
      text: '${item['name'] ?? item['title'] ?? ''}',
    );
    final contact = TextEditingController(text: '${item['contactName'] ?? ''}');
    final phone = TextEditingController(text: '${item['phone'] ?? ''}');
    final email = TextEditingController(text: '${item['email'] ?? ''}');
    final source = TextEditingController(text: '${item['source'] ?? ''}');
    final score = TextEditingController(text: '${item['score'] ?? 0}');
    final sort = TextEditingController(text: '${item['sortOrder'] ?? 0}');
    final probability = TextEditingController(
      text: '${item['probability'] ?? 10}',
    );
    final amount = TextEditingController(text: '${item['amount'] ?? 0}');
    final date = TextEditingController(
      text:
          ('${item['expectedCloseDate'] ?? item['dueAt'] ?? DateTime.now().add(const Duration(days: 7)).toIso8601String()}')
              .split('T')
              .first,
    );
    final remark = TextEditingController(
      text: '${item['remark'] ?? item['description'] ?? ''}',
    );
    final result = TextEditingController(text: '${item['result'] ?? ''}');
    String type =
        '${item['type'] ?? (widget.endpoint == 'pipeline-stages'
                ? 'OPEN'
                : widget.endpoint == 'leads'
                ? 'COMPANY'
                : widget.endpoint == 'activities'
                ? 'CALL'
                : '')}';
    String status =
        '${item['status'] ?? (widget.endpoint == 'leads'
                ? 'NEW'
                : widget.endpoint == 'activities'
                ? 'PENDING'
                : 'OPEN')}';
    String? employee = item['assignedEmployeeID']?.toString();
    String? customer = item['customerID']?.toString();
    String? stage = item['pipelineStageID']?.toString();
    String? lead = item['leadID']?.toString();
    String? opportunity = item['opportunityID']?.toString();
    bool active = item['active'] != false;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (context, setLocal) => LaooActionDialog(
          tokens: salesUiTokens,
          width: 760,
          icon: item!.isEmpty ? Icons.add : Icons.edit_outlined,
          title: '$title > ${item.isEmpty ? 'เพิ่ม' : 'แก้ไข'}',
          content: Column(
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('สถานะ'),
                value: active,
                onChanged: (v) => setLocal(() => active = v),
              ),
              Wrap(
                spacing: 12,
                runSpacing: 16,
                children: [
                  if (!myTasks) field(code, 'รหัส (ว่างเพื่อสร้างอัตโนมัติ)'),
                  if (widget.endpoint == 'pipeline-stages') ...[
                    field(name, 'ชื่อขั้นตอน *'),
                    field(sort, 'ลำดับ *', number: true),
                    field(probability, 'ความน่าจะเป็น (%) *', number: true),
                    choice(
                      ['OPEN', 'WON', 'LOST'],
                      type,
                      'ประเภท *',
                      (v) => setLocal(() => type = v!),
                    ),
                  ],
                  if (widget.endpoint == 'leads') ...[
                    field(name, 'ชื่อบริษัท/บุคคล *'),
                    choice(
                      ['COMPANY', 'PERSON'],
                      type,
                      'ประเภท *',
                      (v) => setLocal(() => type = v!),
                    ),
                    field(contact, 'ชื่อผู้ติดต่อ'),
                    field(phone, 'โทรศัพท์'),
                    field(email, 'อีเมล'),
                    field(source, 'แหล่งที่มา'),
                    field(score, 'คะแนน 0-100', number: true),
                    choice(
                      ['NEW', 'CONTACTED', 'QUALIFIED', 'DISQUALIFIED'],
                      status,
                      'สถานะ *',
                      (v) => setLocal(() => status = v!),
                    ),
                    select(
                      rows(options['employees']),
                      employee,
                      'ผู้รับผิดชอบ',
                      (v) => setLocal(() => employee = v),
                    ),
                  ],
                  if (widget.endpoint == 'opportunities') ...[
                    field(name, 'ชื่อโอกาสการขาย *'),
                    select(
                      rows(options['customers']),
                      customer,
                      'ลูกค้า *',
                      (v) => setLocal(() => customer = v),
                    ),
                    select(
                      rows(
                        options['stages'],
                      ).where((e) => e['type'] == 'OPEN').toList(),
                      stage,
                      'ขั้นตอน *',
                      (v) => setLocal(() {
                        stage = v;
                        final selected = rows(options['stages']).firstWhere(
                          (e) => '${e['id']}' == v,
                          orElse: () => {},
                        );
                        if (selected.isNotEmpty) {
                          probability.text = '${selected['probability']}';
                        }
                      }),
                    ),
                    field(amount, 'มูลค่าคาดการณ์ *', number: true),
                    field(probability, 'ความน่าจะเป็น (%) *', number: true),
                    field(date, 'วันที่คาดว่าจะปิด (yyyy-MM-dd) *'),
                    select(
                      rows(options['employees']),
                      employee,
                      'ผู้รับผิดชอบ',
                      (v) => setLocal(() => employee = v),
                    ),
                  ],
                  if (widget.endpoint == 'activities') ...[
                    field(name, 'หัวข้อกิจกรรม *'),
                    choice(
                      ['CALL', 'MEETING', 'EMAIL', 'TASK'],
                      type,
                      'ประเภท *',
                      (v) => setLocal(() => type = v!),
                    ),
                    select(
                      rows(options['leads']),
                      lead,
                      'Lead ที่เกี่ยวข้อง',
                      (v) => setLocal(() => lead = v),
                    ),
                    select(
                      rows(options['customers']),
                      customer,
                      'ลูกค้าที่เกี่ยวข้อง',
                      (v) => setLocal(() => customer = v),
                    ),
                    select(
                      rows(options['opportunities']),
                      opportunity,
                      'โอกาสการขายที่เกี่ยวข้อง',
                      (v) => setLocal(() => opportunity = v),
                    ),
                    select(
                      rows(options['employees']),
                      employee,
                      'ผู้รับผิดชอบ *',
                      (v) => setLocal(() => employee = v),
                    ),
                    field(date, 'วันครบกำหนด (yyyy-MM-dd) *'),
                    choice(
                      ['PENDING', 'IN_PROGRESS', 'DONE', 'CANCELLED'],
                      status,
                      'สถานะ *',
                      (v) => setLocal(() => status = v!),
                    ),
                  ],
                  if (myTasks) ...[
                    choice(
                      ['PENDING', 'IN_PROGRESS', 'DONE', 'CANCELLED'],
                      status,
                      'สถานะ *',
                      (v) => setLocal(() => status = v!),
                    ),
                    field(date, 'วันครบกำหนดใหม่ (yyyy-MM-dd)'),
                    field(result, 'ผลการติดตาม', width: 572),
                  ],
                  if (!myTasks && widget.endpoint != 'pipeline-stages')
                    field(
                      remark,
                      widget.endpoint == 'activities'
                          ? 'รายละเอียด'
                          : 'หมายเหตุ',
                      width: 572,
                    ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('ยกเลิก'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialog, true),
              icon: const Icon(Icons.save_outlined),
              label: const Text('บันทึก'),
            ),
          ],
        ),
      ),
    );
    if (saved != true) return;
    try {
      final body = <String, dynamic>{};
      if (widget.endpoint == 'pipeline-stages') {
        body.addAll({
          'code': code.text,
          'name': name.text,
          'sortOrder': int.tryParse(sort.text),
          'probability': double.tryParse(probability.text),
          'type': type,
          'isActive': active,
        });
      }
      if (widget.endpoint == 'leads') {
        body.addAll({
          'code': code.text,
          'type': type,
          'name': name.text,
          'contactName': contact.text,
          'phone': phone.text,
          'email': email.text,
          'taxID': null,
          'address': null,
          'source': source.text,
          'score': int.tryParse(score.text),
          'status': status,
          'assignedEmployeeID': int.tryParse(employee ?? ''),
          'lastContactAt': null,
          'nextContactAt': null,
          'remark': remark.text,
          'isActive': active,
        });
      }
      if (widget.endpoint == 'opportunities') {
        body.addAll({
          'code': code.text,
          'name': name.text,
          'customerID': int.tryParse(customer ?? ''),
          'stageID': int.tryParse(stage ?? ''),
          'amount': double.tryParse(amount.text),
          'probability': double.tryParse(probability.text),
          'expectedCloseDate': date.text,
          'assignedEmployeeID': int.tryParse(employee ?? ''),
          'competitor': null,
          'remark': remark.text,
          'isActive': active,
        });
      }
      if (widget.endpoint == 'activities') {
        body.addAll({
          'code': code.text,
          'type': type,
          'title': name.text,
          'leadID': int.tryParse(lead ?? ''),
          'customerID': int.tryParse(customer ?? ''),
          'opportunityID': int.tryParse(opportunity ?? ''),
          'assignedEmployeeID': int.tryParse(employee ?? ''),
          'startAt': DateTime.now().toIso8601String(),
          'dueAt': '${date.text}T17:00:00',
          'status': status,
          'description': remark.text,
          'result': result.text,
          'isActive': active,
        });
      }
      if (myTasks) {
        await api.put(
          '/api/company/sales/my-tasks/${item['id']}',
          body: {
            'status': status,
            'result': result.text,
            'nextDueAt': date.text.isEmpty ? null : '${date.text}T17:00:00',
          },
        );
      } else if (item.isEmpty) {
        await api.post('/api/company/sales/${widget.endpoint}', body: body);
      } else {
        await api.put(
          '/api/company/sales/${widget.endpoint}/${item['id']}',
          body: body,
        );
      }
      success('บันทึกข้อมูลแล้ว');
    } catch (e) {
      failure('บันทึกข้อมูลไม่สำเร็จ');
    }
  }

  Widget choice(
    List<String> values,
    String value,
    String label,
    ValueChanged<String?> changed,
  ) => SizedBox(
    width: 280,
    child: DropdownButtonFormField<String>(
      initialValue: values.contains(value) ? value : null,
      decoration: InputDecoration(labelText: label),
      items: values
          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
          .toList(),
      onChanged: changed,
    ),
  );

  Future<void> convert(
    Map<String, dynamic> item,
    Map<String, dynamic> options,
  ) async {
    String? customer;
    final name = TextEditingController(text: 'โอกาสขาย ${item['name']}');
    final amount = TextEditingController(text: '0');
    final close = TextEditingController(
      text: DateTime.now()
          .add(const Duration(days: 30))
          .toIso8601String()
          .split('T')
          .first,
    );
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (context, setLocal) => LaooActionDialog(
          tokens: salesUiTokens,
          icon: Icons.person_add_alt_outlined,
          title: 'เปลี่ยน Lead เป็นลูกค้า',
          content: Wrap(
            spacing: 12,
            runSpacing: 16,
            children: [
              select(
                rows(options['customers']),
                customer,
                'เชื่อมลูกค้าเดิม (ถ้ามี)',
                (v) => setLocal(() => customer = v),
              ),
              field(name, 'ชื่อโอกาสการขาย *'),
              field(amount, 'มูลค่าคาดการณ์ *', number: true),
              field(close, 'วันที่คาดว่าจะปิด *'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('ยกเลิก'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialog, true),
              icon: const Icon(Icons.swap_horiz),
              label: const Text('เปลี่ยนเป็นลูกค้า'),
            ),
          ],
        ),
      ),
    );
    if (accepted != true) return;
    try {
      await api.post(
        '/api/company/sales/leads/${item['id']}/convert',
        body: {
          'customerID': int.tryParse(customer ?? ''),
          'opportunityName': name.text,
          'amount': double.tryParse(amount.text),
          'expectedCloseDate': close.text,
        },
      );
      success('สร้างลูกค้าและโอกาสการขายแล้ว');
    } catch (e) {
      failure('เปลี่ยน Lead ไม่สำเร็จ');
    }
  }

  Future<void> closeOpportunity(Map<String, dynamic> item) async {
    String status = 'WON';
    final reason = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (context, setLocal) => LaooActionDialog(
          tokens: salesUiTokens,
          icon: Icons.task_alt,
          title: 'ปิดโอกาสการขาย',
          content: Column(
            children: [
              choice(
                ['WON', 'LOST'],
                status,
                'ผลการขาย *',
                (v) => setLocal(() => status = v!),
              ),
              const SizedBox(height: 16),
              field(reason, 'เหตุผล *', width: 560),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('ยกเลิก'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(dialog, true),
              icon: const Icon(Icons.check),
              label: const Text('ยืนยัน'),
            ),
          ],
        ),
      ),
    );
    if (accepted != true) return;
    try {
      await api.post(
        '/api/company/sales/opportunities/${item['id']}/close',
        body: {
          'status': status,
          'closedDate': DateTime.now().toIso8601String().split('T').first,
          'reason': reason.text,
        },
      );
      success('ปิดโอกาสการขายแล้ว');
    } catch (e) {
      failure('ปิดโอกาสการขายไม่สำเร็จ');
    }
  }

  SizedBox field(
    TextEditingController c,
    String label, {
    bool number = false,
    double width = 280,
  }) => SizedBox(
    width: width,
    child: TextField(
      controller: c,
      keyboardType: number ? TextInputType.number : null,
      decoration: InputDecoration(labelText: label),
    ),
  );
  Widget select(
    List<Map<String, dynamic>> items,
    String? value,
    String label,
    ValueChanged<String?> changed, {
    String? type,
  }) {
    final filtered = type == null
        ? items
        : items.where((item) => item['type'] == type).toList();
    final uniqueById = <String, Map<String, dynamic>>{};
    for (final item in filtered) {
      final id = item['id']?.toString();
      if (id == null || id.isEmpty) continue;
      uniqueById.putIfAbsent(id, () => item);
    }
    final uniqueItems = uniqueById.values.toList();
    final selectedValue = uniqueById.containsKey(value) ? value : null;
    return SizedBox(
      width: 280,
      child: DropdownButtonFormField<String>(
        isExpanded: true,
        initialValue: selectedValue,
        decoration: InputDecoration(labelText: label),
        items: uniqueItems
            .map(
              (item) => DropdownMenuItem(
                value: '${item['id']}',
                child: Text(
                  '${item['code']} - ${item['name']}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
            .toList(),
        onChanged: changed,
      ),
    );
  }

  Widget empty() =>
      Center(child: Text('ไม่พบข้อมูล', style: salesUiTokens.inputStyle));
  Widget state(String text, {bool retry = false}) => LaooSurfaceCard(
    tokens: salesUiTokens,
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text),
          if (retry)
            TextButton(onPressed: reload, child: const Text('ลองอีกครั้ง')),
        ],
      ),
    ),
  );
  void success(String message) {
    showSalesMessage(context, message: message);
    reload();
  }

  void failure(String message) =>
      showSalesMessage(context, message: message, error: true);
  static String first(Map<String, dynamic> item, List<String> keys) {
    for (final key in keys) {
      final v = item[key];
      if (v != null && '$v'.isNotEmpty) return '$v';
    }
    return '-';
  }

  static Map<String, dynamic> map(dynamic value) => value is Map
      ? value.map((k, v) => MapEntry('$k', v))
      : <String, dynamic>{};
  static List<Map<String, dynamic>> rows(dynamic value) {
    if (value is List) {
      return value
          .whereType<Map>()
          .map((e) => e.map((k, v) => MapEntry('$k', v)))
          .toList();
    }
    final data = map(value);
    for (final key in const ['rows', 'items', 'data']) {
      if (data[key] is List) return rows(data[key]);
    }
    return const [];
  }
}
