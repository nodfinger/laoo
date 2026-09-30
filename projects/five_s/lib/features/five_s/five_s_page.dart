import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';

import 'five_s_feature_host.dart';

class FiveSPage extends StatefulWidget {
  const FiveSPage({
    required this.menuCode,
    required this.title,
    required this.endpoint,
    super.key,
  });
  final String menuCode;
  final String title;
  final String endpoint;
  @override
  State<FiveSPage> createState() => _FiveSPageState();
}

class _FiveSPageState extends State<FiveSPage> {
  late final JsonApiClient api = createFiveSApiClient();
  final search = TextEditingController();
  late Future<Map<String, dynamic>> future;
  late String title;
  String query = '';
  int page = 1;
  bool cards = false;

  bool get settings => widget.endpoint == 'settings';
  bool get reports => widget.endpoint == 'reports';
  bool get master =>
      const ['areas', 'templates', 'teams', 'plans'].contains(widget.endpoint);

  @override
  void initState() {
    super.initState();
    title = widget.title;
    future = load();
    resolveFiveSMenuTitle(widget.menuCode, title).then((value) {
      if (mounted) setState(() => title = value);
    });
  }

  Future<Map<String, dynamic>> load() async {
    final values = await Future.wait<dynamic>([
      api.get('/api/company/five-s/${widget.endpoint}'),
      api.get('/api/company/five-s/actions/${widget.menuCode}'),
      if (master || widget.endpoint == 'findings' || settings)
        api.get('/api/company/five-s/options'),
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
    disposeFiveSApiClient(api);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => buildFiveSWorkspaceShell(
    pageTitle: title,
    activeMenu: widget.menuCode,
    child: Padding(
      padding: fiveSUiTokens.contentMargin,
      child: FutureBuilder<Map<String, dynamic>>(
        future: future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return frame(stateCard('กำลังโหลดข้อมูล...'));
          }
          if (snap.hasError) {
            return frame(stateCard('โหลดข้อมูลไม่สำเร็จ', retry: true));
          }
          final value = snap.data!;
          final actions = map(value['actions']);
          final options = map(value['options']);
          final data = rows(value['data']);
          if (settings) {
            return settingsView(
              data.isEmpty ? <String, dynamic>{} : data.first,
              actions,
              options,
            );
          }
          if (reports) {
            return reportView(data.isEmpty ? <String, dynamic>{} : data.first);
          }
          return listView(data, actions, options);
        },
      ),
    ),
  );

  Widget caption({Widget? trailing}) => LaooCaptionCard(
    tokens: fiveSUiTokens,
    leading: Icon(Icons.fact_check_outlined, color: fiveSUiTokens.primaryColor),
    caption: title,
    trailing: trailing,
  );

  Widget frame(Widget child) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      caption(),
      SizedBox(height: fiveSUiTokens.captionFilterSpacing),
      Expanded(child: child),
    ],
  );

  Widget listView(
    List<Map<String, dynamic>> source,
    Map<String, dynamic> actions,
    Map<String, dynamic> options,
  ) {
    const pageSize = 10;
    final filtered = source
        .where((item) => item.values.join(' ').toLowerCase().contains(query))
        .toList();
    final pageCount = (filtered.length / pageSize).ceil().clamp(1, 9999);
    if (page > pageCount) page = pageCount;
    final visible = filtered
        .skip((page - 1) * pageSize)
        .take(pageSize)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        caption(
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              LaooListCardToggle(
                tokens: fiveSUiTokens,
                cards: cards,
                onChanged: (value) => setState(() => cards = value),
              ),
              if (master && actions['create'] == true) ...[
                const SizedBox(width: 6),
                FilledButton.icon(
                  onPressed: () => editMaster(null, options),
                  icon: const Icon(Icons.add),
                  label: const Text('เพิ่ม'),
                ),
              ],
            ],
          ),
        ),
        SizedBox(height: fiveSUiTokens.captionFilterSpacing),
        LaooFilterCard(
          tokens: fiveSUiTokens,
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
        SizedBox(height: fiveSUiTokens.sectionSpacing),
        Expanded(
          child: LaooTableCard(
            tokens: fiveSUiTokens,
            child: visible.isEmpty
                ? empty()
                : (cards
                      ? cardRows(visible, actions, options)
                      : tableRows(visible, actions, options)),
          ),
        ),
        SizedBox(height: fiveSUiTokens.sectionSpacing),
        LaooPaginationCard(
          tokens: fiveSUiTokens,
          page: page,
          pageCount: pageCount,
          pageSize: pageSize,
          total: filtered.length,
          onPrevious: page > 1 ? () => setState(() => page--) : null,
          onNext: page < pageCount ? () => setState(() => page++) : null,
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
    tokens: fiveSUiTokens,
    columns: const [
      LaooWorkspaceTableColumns.id,
      DataColumn(label: Text('จัดการ')),
      DataColumn(label: Text('เลขที่/รหัส')),
      DataColumn(label: Text('ชื่อ/พื้นที่')),
      DataColumn(label: Text('สถานะ/คะแนน')),
    ],
    rows: data.asMap().entries.map((entry) {
      final item = entry.value;
      return DataRow(
        cells: [
          DataCell(Text((entry.key + 1 + ((page - 1) * 10)).toString())),
          DataCell(rowActions(item, actions, options)),
          DataCell(Text(first(item, ['number', 'code', 'inspection']))),
          DataCell(
            Text(first(item, ['name', 'area', 'template', 'description'])),
          ),
          DataCell(Text(first(item, ['status', 'scorePercent', 'active']))),
        ],
      );
    }).toList(),
  );

  Widget cardRows(
    List<Map<String, dynamic>> data,
    Map<String, dynamic> actions,
    Map<String, dynamic> options,
  ) => SingleChildScrollView(
    padding: fiveSUiTokens.cardPadding,
    child: Wrap(
      spacing: 8,
      runSpacing: 8,
      children: data
          .map(
            (item) => SizedBox(
              width: 330,
              child: LaooSurfaceCard(
                tokens: fiveSUiTokens,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      first(item, ['number', 'code', 'name']),
                      style: fiveSUiTokens.sectionStyle,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      first(item, ['area', 'template', 'description', 'team']),
                      style: fiveSUiTokens.inputStyle,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      first(item, ['status', 'scorePercent', 'active']),
                      style: fiveSUiTokens.tableStyle,
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

  Widget rowActions(
    Map<String, dynamic> item,
    Map<String, dynamic> actions,
    Map<String, dynamic> options,
  ) {
    final id = item['id'].toString();
    return Wrap(
      spacing: 2,
      children: [
        if (master &&
            actions['edit'] == true &&
            (widget.endpoint != 'plans' || item['status'] == 'DRAFT'))
          IconButton(
            tooltip: 'แก้ไข',
            onPressed: () => editMaster(item, options),
            icon: Icon(Icons.edit_outlined, color: fiveSUiTokens.primaryColor),
          ),
        if (master && actions['delete'] == true)
          IconButton(
            tooltip: 'ลบ',
            onPressed: () => deleteMaster(id),
            icon: const Icon(Icons.delete_outline, color: Colors.red),
          ),
        if (widget.endpoint == 'plans' &&
            item['status'] == 'DRAFT' &&
            actions['edit'] == true)
          IconButton(
            tooltip: 'เปิดแผน',
            onPressed: () => postAction(
              '/api/company/five-s/plans/$id/activate',
              'เปิดแผนตรวจแล้ว',
            ),
            icon: const Icon(Icons.play_circle_outline),
          ),
        if (widget.endpoint == 'inspections')
          IconButton(
            tooltip: 'บันทึกผลตรวจ',
            onPressed: () => inspectionDialog(id, actions),
            icon: Icon(
              Icons.fact_check_outlined,
              color: fiveSUiTokens.primaryColor,
            ),
          ),
        if (widget.endpoint == 'confirmations' &&
            item['status'] == 'SUBMITTED' &&
            actions['approve'] == true) ...[
          IconButton(
            tooltip: 'ยืนยัน',
            onPressed: () => decision(id, 'approve'),
            icon: const Icon(Icons.check_circle_outline, color: Colors.green),
          ),
          IconButton(
            tooltip: 'ส่งกลับ',
            onPressed: () => decision(id, 'return'),
            icon: const Icon(Icons.undo, color: Colors.orange),
          ),
        ],
        if (widget.endpoint == 'findings' &&
            ((const ['OPEN', 'REOPENED'].contains(item['status']) &&
                    actions['assign'] == true) ||
                (const ['ASSIGNED', 'IN_PROGRESS'].contains(item['status']) &&
                    actions['edit'] == true) ||
                (const ['PENDING_CONFIRM', 'CLOSED'].contains(item['status']) &&
                    actions['confirm'] == true)))
          IconButton(
            tooltip: 'ดำเนินการ',
            onPressed: () => findingAction(item, options),
            icon: Icon(Icons.build_outlined, color: fiveSUiTokens.primaryColor),
          ),
        if (const ['history', 'confirmations'].contains(widget.endpoint))
          IconButton(
            tooltip: 'ดูรายละเอียด',
            onPressed: () => inspectionDialog(id, const {}),
            icon: const Icon(Icons.visibility_outlined),
          ),
      ],
    );
  }

  Widget settingsView(
    Map<String, dynamic> item,
    Map<String, dynamic> actions,
    Map<String, dynamic> options,
  ) {
    final enabled = ValueNotifier<bool>(item['isEnabled'] != false);
    final selfApprove = ValueNotifier<bool>(item['allowSelfApprove'] == true);
    final failurePhoto = ValueNotifier<bool>(
      item['requireFailurePhoto'] != false,
    );
    final closurePhoto = ValueNotifier<bool>(
      item['requireClosurePhoto'] != false,
    );
    final score = TextEditingController(
      text: (item['scoreMax'] ?? 5).toString(),
    );
    final pass = TextEditingController(
      text: (item['defaultPassPercent'] ?? 80).toString(),
    );
    final files = TextEditingController(
      text: (item['maxAttachmentsPerItem'] ?? 5).toString(),
    );
    final size = TextEditingController(
      text: (item['maxAttachmentSizeMB'] ?? 1).toString(),
    );
    final lowDays = TextEditingController(
      text: (item['lowDueDays'] ?? 14).toString(),
    );
    final mediumDays = TextEditingController(
      text: (item['mediumDueDays'] ?? 7).toString(),
    );
    final highDays = TextEditingController(
      text: (item['highDueDays'] ?? 3).toString(),
    );
    final users = rows(options['users']);
    String? approver = item['defaultApproverUserID']?.toString();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        caption(),
        SizedBox(height: fiveSUiTokens.sectionSpacing),
        Expanded(
          child: LaooSurfaceCard(
            tokens: fiveSUiTokens,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ค่าการทำงานปัจจุบัน',
                    style: fiveSUiTokens.sectionStyle,
                  ),
                  const Divider(),
                  ValueListenableBuilder<bool>(
                    valueListenable: enabled,
                    builder: (_, value, _) => SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('เปิดใช้งานระบบตรวจ 5ส'),
                      value: value,
                      onChanged: actions['edit'] == true
                          ? (v) => enabled.value = v
                          : null,
                    ),
                  ),
                  StatefulBuilder(
                    builder: (context, setSettingState) => Wrap(
                      spacing: 12,
                      runSpacing: 16,
                      children: [
                        numberField(score, 'คะแนนเต็ม'),
                        numberField(pass, 'เกณฑ์ผ่าน (%)'),
                        numberField(files, 'จำนวนรูปต่อรายการ'),
                        numberField(size, 'ขนาดรูปสูงสุด (MB ไม่เกิน 1)'),
                        numberField(lowDays, 'ครบกำหนดระดับต่ำ (วัน)'),
                        numberField(mediumDays, 'ครบกำหนดระดับกลาง (วัน)'),
                        numberField(highDays, 'ครบกำหนดระดับสูง (วัน)'),
                        SizedBox(
                          width: 300,
                          child: DropdownButtonFormField<String>(
                            initialValue: approver,
                            decoration: const InputDecoration(
                              labelText: 'ผู้ยืนยันเริ่มต้น',
                            ),
                            items: users
                                .map(
                                  (user) => DropdownMenuItem(
                                    value: user['id'].toString(),
                                    child: Text(
                                      '${user['code']} - ${user['name']}',
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: actions['edit'] == true
                                ? (value) =>
                                      setSettingState(() => approver = value)
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ValueListenableBuilder<bool>(
                    valueListenable: failurePhoto,
                    builder: (_, value, _) => SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('บังคับแนบรูปเมื่อรายการตรวจไม่ผ่าน'),
                      value: value,
                      onChanged: actions['edit'] == true
                          ? (v) => failurePhoto.value = v
                          : null,
                    ),
                  ),
                  ValueListenableBuilder<bool>(
                    valueListenable: closurePhoto,
                    builder: (_, value, _) => SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'บังคับแนบรูปหลังแก้ไขก่อนปิดข้อบกพร่อง',
                      ),
                      value: value,
                      onChanged: actions['edit'] == true
                          ? (v) => closurePhoto.value = v
                          : null,
                    ),
                  ),
                  ValueListenableBuilder<bool>(
                    valueListenable: selfApprove,
                    builder: (_, value, _) => SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('อนุญาตผู้ตรวจยืนยันผลของตนเอง'),
                      value: value,
                      onChanged: actions['edit'] == true
                          ? (v) => selfApprove.value = v
                          : null,
                    ),
                  ),
                  const Divider(),
                  if (actions['edit'] == true)
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        onPressed: () async {
                          await api.put(
                            '/api/company/five-s/settings',
                            body: {
                              'isEnabled': enabled.value,
                              'scoreMax': num.tryParse(score.text) ?? 5,
                              'defaultPassPercent':
                                  num.tryParse(pass.text) ?? 80,
                              'requireFailurePhoto': failurePhoto.value,
                              'requireClosurePhoto': closurePhoto.value,
                              'maxAttachmentSizeMB':
                                  num.tryParse(size.text) ?? 1,
                              'maxAttachmentsPerItem':
                                  int.tryParse(files.text) ?? 5,
                              'lowDueDays': int.tryParse(lowDays.text) ?? 14,
                              'mediumDueDays':
                                  int.tryParse(mediumDays.text) ?? 7,
                              'highDueDays': int.tryParse(highDays.text) ?? 3,
                              'allowSelfApprove': selfApprove.value,
                              'defaultApproverUserID': approver == null
                                  ? null
                                  : int.tryParse(approver!),
                            },
                          );
                          success('บันทึกการตั้งค่าแล้ว');
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
      ],
    );
  }

  Widget reportView(Map<String, dynamic> item) {
    final metrics = [
      (
        'ผลตรวจที่ยืนยันแล้ว',
        item['confirmedCount'] ?? 0,
        Icons.verified_outlined,
      ),
      ('คะแนนเฉลี่ย', item['averageScore'] ?? 0, Icons.analytics_outlined),
      ('รายการผ่าน', item['passedCount'] ?? 0, Icons.task_alt),
      (
        'ข้อบกพร่องค้าง',
        item['openFindings'] ?? 0,
        Icons.report_problem_outlined,
      ),
      ('เกินกำหนด', item['overdueFindings'] ?? 0, Icons.timer_off_outlined),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        caption(),
        SizedBox(height: fiveSUiTokens.sectionSpacing),
        Expanded(
          child: LaooSurfaceCard(
            tokens: fiveSUiTokens,
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: metrics
                  .map(
                    (m) => SizedBox(
                      width: 210,
                      child: ListTile(
                        leading: Icon(m.$3, color: fiveSUiTokens.primaryColor),
                        title: Text(
                          m.$2.toString(),
                          style: fiveSUiTokens.captionStyle,
                        ),
                        subtitle: Text(m.$1),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> editMaster(
    Map<String, dynamic>? item,
    Map<String, dynamic> options,
  ) async {
    var header = item ?? <String, dynamic>{};
    var details = <Map<String, dynamic>>[];
    if (item != null && widget.endpoint != 'areas') {
      final detail = map(
        await api.get('/api/company/five-s/${widget.endpoint}/${item['id']}'),
      );
      header = map(detail['header']);
      details = rows(detail['details']);
    }
    final code = TextEditingController(text: (header['code'] ?? '').toString());
    final name = TextEditingController(text: (header['name'] ?? '').toString());
    final pass = TextEditingController(
      text: (header['passPercent'] ?? 80).toString(),
    );
    final version = TextEditingController(
      text: (header['version'] ?? 1).toString(),
    );
    final description = TextEditingController(
      text: (header['description'] ?? '').toString(),
    );
    final startDate = TextEditingController(
      text: dateOnly(header['startDate'] ?? DateTime.now()),
    );
    final endDate = TextEditingController(
      text: dateOnly(
        header['endDate'] ?? DateTime.now().add(const Duration(days: 30)),
      ),
    );
    var active = header['active'] != false;
    String? leader = header['leaderUserID']?.toString();
    String? template = header['templateID']?.toString();
    String? team = header['teamID']?.toString();
    String? approver = header['approverUserID']?.toString();
    var frequency = (header['frequency'] ?? 'ONCE').toString();
    final selectedMembers = details
        .map((row) => row['userID'].toString())
        .toSet();
    final selectedAreas = details
        .map((row) => row['areaID'].toString())
        .toSet();
    final templateItems = details
        .map(
          (row) => <String, dynamic>{
            'category': row['category'] ?? 'SEIRI',
            'question': row['question'] ?? '',
            'weight': row['weight'] ?? 1,
            'isCritical': row['critical'] == true,
            'requireFailurePhoto': row['requirePhoto'] != false,
          },
        )
        .toList();
    if (widget.endpoint == 'templates' && templateItems.isEmpty) {
      templateItems.add({
        'category': 'SEIRI',
        'question': '',
        'weight': 1,
        'isCritical': false,
        'requireFailurePhoto': true,
      });
    }
    final users = rows(options['users']);
    if (leader != null) selectedMembers.add(leader);
    String? validation;
    if (!mounted) return;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => LaooActionDialog(
          tokens: fiveSUiTokens,
          width: 820,
          icon: item == null ? Icons.add : Icons.edit_outlined,
          title: (item == null ? 'เพิ่ม ' : 'แก้ไข ') + title,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.endpoint != 'plans')
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('สถานะ'),
                  subtitle: Text(active ? 'เปิดใช้งาน' : 'ปิดใช้งาน'),
                  value: active,
                  onChanged: (value) => setDialogState(() => active = value),
                ),
              if (widget.endpoint != 'plans') ...[
                TextField(
                  controller: code,
                  decoration: const InputDecoration(labelText: 'รหัส *'),
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'ชื่อ *'),
              ),
              if (widget.endpoint == 'areas') ...[
                const SizedBox(height: 16),
                TextField(
                  controller: description,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'รายละเอียด'),
                ),
              ],
              if (widget.endpoint == 'templates') ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: version,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Version *',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: pass,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'เกณฑ์ผ่าน (%) *',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'รายการตรวจ (Detail)',
                        style: fiveSUiTokens.sectionStyle,
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => setDialogState(
                        () => templateItems.add({
                          'category': 'SEIRI',
                          'question': '',
                          'weight': 1,
                          'isCritical': false,
                          'requireFailurePhoto': true,
                        }),
                      ),
                      icon: const Icon(Icons.add),
                      label: const Text('เพิ่มรายการ'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...templateItems.asMap().entries.map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: LaooSurfaceCard(
                      tokens: fiveSUiTokens,
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: entry.value['category']
                                      .toString(),
                                  decoration: const InputDecoration(
                                    labelText: 'หมวด 5ส *',
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'SEIRI',
                                      child: Text('สะสาง'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'SEITON',
                                      child: Text('สะดวก'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'SEISO',
                                      child: Text('สะอาด'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'SEIKETSU',
                                      child: Text('สุขลักษณะ'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'SHITSUKE',
                                      child: Text('สร้างนิสัย'),
                                    ),
                                  ],
                                  onChanged: (value) =>
                                      entry.value['category'] = value,
                                ),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 110,
                                child: TextFormField(
                                  initialValue: entry.value['weight']
                                      .toString(),
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'น้ำหนัก *',
                                  ),
                                  onChanged: (value) => entry.value['weight'] =
                                      num.tryParse(value) ?? 0,
                                ),
                              ),
                              IconButton(
                                tooltip: 'ลบรายการ',
                                onPressed: templateItems.length == 1
                                    ? null
                                    : () => setDialogState(
                                        () => templateItems.removeAt(entry.key),
                                      ),
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            initialValue: entry.value['question'].toString(),
                            decoration: const InputDecoration(
                              labelText: 'คำถาม/เกณฑ์ตรวจ *',
                            ),
                            onChanged: (value) =>
                                entry.value['question'] = value,
                          ),
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('รายการวิกฤต'),
                            value: entry.value['isCritical'] == true,
                            onChanged: (value) => setDialogState(
                              () => entry.value['isCritical'] = value == true,
                            ),
                          ),
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('บังคับแนบรูปเมื่อไม่ผ่าน'),
                            value: entry.value['requireFailurePhoto'] == true,
                            onChanged: (value) => setDialogState(
                              () => entry.value['requireFailurePhoto'] =
                                  value == true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              if (widget.endpoint == 'teams') ...[
                const SizedBox(height: 16),
                optionField(
                  label: 'หัวหน้าทีม *',
                  value: leader,
                  source: users,
                  onChanged: (value) => setDialogState(() {
                    leader = value;
                    if (value != null) selectedMembers.add(value);
                  }),
                ),
                const SizedBox(height: 16),
                Text('สมาชิกทีม *', style: fiveSUiTokens.sectionStyle),
                ...users.map(
                  (user) => CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${user['code']} - ${user['name']}'),
                    value: selectedMembers.contains(user['id'].toString()),
                    onChanged: (value) => setDialogState(() {
                      final id = user['id'].toString();
                      value == true
                          ? selectedMembers.add(id)
                          : selectedMembers.remove(id);
                    }),
                  ),
                ),
              ],
              if (widget.endpoint == 'plans') ...[
                const SizedBox(height: 16),
                optionField(
                  label: 'แบบตรวจ *',
                  value: template,
                  source: rows(options['templates']),
                  onChanged: (value) => setDialogState(() => template = value),
                ),
                const SizedBox(height: 16),
                optionField(
                  label: 'ทีมตรวจ *',
                  value: team,
                  source: rows(options['teams']),
                  onChanged: (value) => setDialogState(() => team = value),
                ),
                const SizedBox(height: 16),
                optionField(
                  label: 'ผู้ยืนยันผล *',
                  value: approver,
                  source: users,
                  onChanged: (value) => setDialogState(() => approver = value),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: startDate,
                        decoration: const InputDecoration(
                          labelText: 'วันที่เริ่ม (yyyy-MM-dd) *',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: endDate,
                        decoration: const InputDecoration(
                          labelText: 'วันที่สิ้นสุด (yyyy-MM-dd) *',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: frequency,
                  decoration: const InputDecoration(labelText: 'ความถี่ *'),
                  items: const [
                    DropdownMenuItem(value: 'ONCE', child: Text('ครั้งเดียว')),
                    DropdownMenuItem(
                      value: 'WEEKLY',
                      child: Text('รายสัปดาห์'),
                    ),
                    DropdownMenuItem(value: 'MONTHLY', child: Text('รายเดือน')),
                    DropdownMenuItem(
                      value: 'QUARTERLY',
                      child: Text('รายไตรมาส'),
                    ),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => frequency = value ?? 'ONCE'),
                ),
                const SizedBox(height: 16),
                Text(
                  'พื้นที่ในแผน (Detail) *',
                  style: fiveSUiTokens.sectionStyle,
                ),
                ...rows(options['areas']).map(
                  (area) => CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${area['code']} - ${area['name']}'),
                    value: selectedAreas.contains(area['id'].toString()),
                    onChanged: (value) => setDialogState(() {
                      final id = area['id'].toString();
                      value == true
                          ? selectedAreas.add(id)
                          : selectedAreas.remove(id);
                    }),
                  ),
                ),
              ],
              if (validation != null) ...[
                const SizedBox(height: 12),
                Text(
                  validation!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('ยกเลิก'),
            ),
            FilledButton.icon(
              onPressed: () async {
                if (name.text.trim().isEmpty ||
                    (widget.endpoint != 'plans' && code.text.trim().isEmpty)) {
                  setDialogState(
                    () => validation = 'กรุณากรอกข้อมูลที่มีเครื่องหมาย *',
                  );
                  return;
                }
                final body = <String, dynamic>{};
                if (widget.endpoint == 'areas') {
                  body.addAll({
                    'code': code.text.trim(),
                    'name': name.text.trim(),
                    'description': description.text.trim(),
                    'isActive': active,
                  });
                } else if (widget.endpoint == 'templates') {
                  if (templateItems.any(
                    (row) =>
                        row['question'].toString().trim().isEmpty ||
                        (row['weight'] as num) <= 0,
                  )) {
                    setDialogState(
                      () => validation = 'กรอกคำถามและน้ำหนักให้ครบทุก Detail',
                    );
                    return;
                  }
                  body.addAll({
                    'code': code.text.trim(),
                    'name': name.text.trim(),
                    'version': int.tryParse(version.text) ?? 1,
                    'passPercent': num.tryParse(pass.text) ?? 80,
                    'description': description.text.trim(),
                    'isActive': active,
                    'items': templateItems,
                  });
                } else if (widget.endpoint == 'teams') {
                  if (leader == null || selectedMembers.isEmpty) {
                    setDialogState(
                      () =>
                          validation = 'เลือกหัวหน้าทีมและสมาชิกอย่างน้อย 1 คน',
                    );
                    return;
                  }
                  body.addAll({
                    'code': code.text.trim(),
                    'name': name.text.trim(),
                    'leaderUserID': int.parse(leader!),
                    'effectiveFrom': null,
                    'effectiveTo': null,
                    'isActive': active,
                    'memberUserIDs': selectedMembers.map(int.parse).toList(),
                  });
                } else {
                  final start = DateTime.tryParse(startDate.text);
                  final end = DateTime.tryParse(endDate.text);
                  if (template == null ||
                      team == null ||
                      approver == null ||
                      selectedAreas.isEmpty ||
                      start == null ||
                      end == null ||
                      end.isBefore(start)) {
                    setDialogState(
                      () => validation =
                          'เลือกแบบตรวจ ทีม ผู้ยืนยัน ช่วงวันที่ และพื้นที่ให้ครบ',
                    );
                    return;
                  }
                  body.addAll({
                    'name': name.text.trim(),
                    'templateID': int.parse(template!),
                    'teamID': int.parse(team!),
                    'approverUserID': int.parse(approver!),
                    'startDate': start.toIso8601String(),
                    'endDate': end.toIso8601String(),
                    'frequency': frequency,
                    'remark': null,
                    'areas': selectedAreas
                        .map(
                          (id) => {
                            'areaID': int.parse(id),
                            'scheduledAt': start.toIso8601String(),
                          },
                        )
                        .toList(),
                  });
                }
                final path =
                    '/api/company/five-s/${widget.endpoint}${item == null ? '' : '/${item['id']}'}';
                if (item == null) {
                  await api.post(path, body: body);
                } else {
                  await api.put(path, body: body);
                }
                if (dialogContext.mounted) Navigator.pop(dialogContext, true);
              },
              icon: const Icon(Icons.save_outlined),
              label: const Text('บันทึก'),
            ),
          ],
        ),
      ),
    );
    if (saved == true) success('บันทึกข้อมูลแล้ว');
  }

  Map<String, dynamic> masterBody(
    String code,
    String name,
    String pass,
    Map<String, dynamic> options,
  ) {
    if (widget.endpoint == 'areas') {
      return {
        'code': code,
        'name': name,
        'description': null,
        'isActive': true,
      };
    }
    if (widget.endpoint == 'templates') {
      return {
        'code': code,
        'name': name,
        'version': 1,
        'passPercent': num.tryParse(pass) ?? 80,
        'description': null,
        'isActive': true,
        'items': [
          {
            'category': 'SEIRI',
            'question': 'ตรวจสอบตามมาตรฐาน 5ส',
            'weight': 1,
            'isCritical': false,
            'requireFailurePhoto': true,
          },
        ],
      };
    }
    final users = rows(options['users']);
    final user = users.isEmpty ? 0 : users.first['id'];
    if (widget.endpoint == 'teams') {
      return {
        'code': code,
        'name': name,
        'leaderUserID': user,
        'effectiveFrom': DateTime.now().toIso8601String(),
        'effectiveTo': null,
        'isActive': true,
        'memberUserIDs': [user],
      };
    }
    final templates = rows(options['templates']);
    final teams = rows(options['teams']);
    final areas = rows(options['areas']);
    return {
      'name': name,
      'templateID': templates.isEmpty ? 0 : templates.first['id'],
      'teamID': teams.isEmpty ? 0 : teams.first['id'],
      'approverUserID': user,
      'startDate': DateTime.now().toIso8601String(),
      'endDate': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
      'frequency': 'ONCE',
      'remark': code,
      'areas': areas.isEmpty
          ? []
          : [
              {
                'areaID': areas.first['id'],
                'scheduledAt': DateTime.now().toIso8601String(),
              },
            ],
    };
  }

  DropdownButtonFormField<String> optionField({
    required String label,
    required String? value,
    required List<Map<String, dynamic>> source,
    required ValueChanged<String?> onChanged,
  }) => DropdownButtonFormField<String>(
    initialValue: source.any((row) => row['id'].toString() == value)
        ? value
        : null,
    decoration: InputDecoration(labelText: label),
    items: source
        .map(
          (row) => DropdownMenuItem(
            value: row['id'].toString(),
            child: Text('${row['code']} - ${row['name']}'),
          ),
        )
        .toList(),
    onChanged: onChanged,
  );

  static String dateOnly(dynamic value) {
    final date = value is DateTime
        ? value
        : DateTime.tryParse(value.toString()) ?? DateTime.now();
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> deleteMaster(String id) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => LaooActionDialog(
        tokens: fiveSUiTokens,
        icon: Icons.delete_outline,
        title: 'ลบรายการ',
        content: const Text('รายการจะถูกลบและไม่สามารถเรียกคืนได้'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (approved == true) {
      await api.delete('/api/company/five-s/${widget.endpoint}/$id');
      success('ลบรายการแล้ว');
    }
  }

  Future<void> postAction(String path, String message, {Object? body}) async {
    await api.post(path, body: body);
    success(message);
  }

  Future<void> decision(String id, String action) async {
    final remark = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => LaooActionDialog(
        tokens: fiveSUiTokens,
        icon: action == 'approve' ? Icons.check_circle_outline : Icons.undo,
        title: action == 'approve' ? 'ยืนยันผลตรวจ 5ส' : 'ส่งกลับแก้ไข',
        content: action == 'approve'
            ? const Text('ยืนยันว่าตรวจสอบข้อมูลและผลคะแนนเรียบร้อยแล้ว')
            : TextField(
                controller: remark,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'เหตุผลที่ส่งกลับ *',
                ),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton.icon(
            onPressed: () {
              if (action == 'return' && remark.text.trim().isEmpty) return;
              Navigator.pop(dialogContext, true);
            },
            icon: Icon(action == 'approve' ? Icons.check : Icons.undo),
            label: Text(action == 'approve' ? 'ยืนยัน' : 'ส่งกลับ'),
          ),
        ],
      ),
    );
    if (accepted != true) return;
    await postAction(
      '/api/company/five-s/confirmations/$id/$action',
      action == 'approve' ? 'ยืนยันผลตรวจแล้ว' : 'ส่งกลับผลตรวจแล้ว',
      body: {'remark': action == 'return' ? remark.text.trim() : null},
    );
  }

  Future<void> findingAction(
    Map<String, dynamic> item,
    Map<String, dynamic> options,
  ) async {
    final status = item['status'].toString();
    final action = const ['OPEN', 'REOPENED'].contains(status)
        ? 'assign'
        : status == 'ASSIGNED'
        ? 'progress'
        : status == 'IN_PROGRESS'
        ? 'submit'
        : status == 'PENDING_CONFIRM'
        ? 'close'
        : 'reopen';
    final users = rows(options['users']);
    String? assigned = item['assignedUserID']?.toString();
    final remark = TextEditingController();
    if (action == 'assign' && assigned == null && users.isNotEmpty) {
      assigned = users.first['id'].toString();
    }
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => LaooActionDialog(
          tokens: fiveSUiTokens,
          icon: Icons.build_outlined,
          title: {
            'assign': 'มอบหมายผู้รับผิดชอบ',
            'progress': 'เริ่มดำเนินการแก้ไข',
            'submit': 'ส่งยืนยันการแก้ไข',
            'close': 'ยืนยันปิดข้อบกพร่อง',
            'reopen': 'เปิดข้อบกพร่องใหม่',
          }[action]!,
          content: Column(
            children: [
              if (action == 'assign')
                DropdownButtonFormField<String>(
                  initialValue: assigned,
                  decoration: const InputDecoration(
                    labelText: 'ผู้รับผิดชอบ *',
                  ),
                  items: users
                      .map(
                        (user) => DropdownMenuItem(
                          value: user['id'].toString(),
                          child: Text('${user['code']} - ${user['name']}'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setDialogState(() => assigned = value),
                ),
              if (const ['progress', 'submit', 'reopen'].contains(action))
                TextField(
                  controller: remark,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: action == 'reopen'
                        ? 'เหตุผลที่เปิดใหม่ *'
                        : 'รายละเอียดการแก้ไข *',
                  ),
                ),
              if (action == 'submit') ...[
                const SizedBox(height: 16),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('หลังยืนยัน ระบบจะให้เลือกรูปหลังแก้ไข'),
                ),
              ],
              if (action == 'close')
                const Text('ยืนยันว่าตรวจสอบผลและรูปหลังแก้ไขเรียบร้อยแล้ว'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('ยกเลิก'),
            ),
            FilledButton.icon(
              onPressed: () {
                if (action == 'assign' && assigned == null) return;
                if (const ['progress', 'submit', 'reopen'].contains(action) &&
                    remark.text.trim().isEmpty) {
                  return;
                }
                Navigator.pop(dialogContext, true);
              },
              icon: const Icon(Icons.check),
              label: const Text('ยืนยัน'),
            ),
          ],
        ),
      ),
    );
    if (accepted != true) return;
    if (action == 'submit') {
      final selected = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (selected == null || selected.files.isEmpty) return;
      final file = selected.files.single;
      if (file.bytes == null) return;
      await uploadFiveSFile(
        '/api/company/five-s/attachments/FINDING_AFTER',
        fileName: file.name,
        bytes: file.bytes!,
        fields: {'findingId': item['id'].toString()},
      );
    }
    await postAction(
      '/api/company/five-s/findings/${item['id']}/$action',
      'อัปเดตข้อบกพร่องแล้ว',
      body: {
        'assignedUserID': assigned == null ? null : int.tryParse(assigned!),
        'remark': remark.text.trim().isEmpty ? null : remark.text.trim(),
      },
    );
  }

  Future<void> inspectionDialog(String id, Map<String, dynamic> actions) async {
    final value = map(await api.get('/api/company/five-s/inspections/$id'));
    final header = map(value['header']);
    final details = rows(value['details']);
    final editable =
        actions['edit'] == true &&
        const ['DRAFT', 'IN_PROGRESS', 'RETURNED'].contains(header['status']);
    final scores = details
        .map((item) => ValueNotifier<num?>(item['score'] as num?))
        .toList();
    final notApplicable = details
        .map((item) => ValueNotifier<bool>(item['notApplicable'] == true))
        .toList();
    if (!mounted) return;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => LaooActionDialog(
        tokens: fiveSUiTokens,
        width: 760,
        icon: Icons.fact_check_outlined,
        title: '${header['number']} • ${header['area']}',
        content: Column(
          children: details.asMap().entries.map((entry) {
            final index = entry.key;
            final detail = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${detail['sortOrder']}. ${detail['question']}',
                    style: fiveSUiTokens.sectionStyle,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ValueListenableBuilder<num?>(
                          valueListenable: scores[index],
                          builder: (_, score, _) =>
                              DropdownButtonFormField<num>(
                                initialValue: score,
                                decoration: const InputDecoration(
                                  labelText: 'คะแนน 0–5',
                                ),
                                items: List.generate(
                                  6,
                                  (v) => DropdownMenuItem(
                                    value: v,
                                    child: Text(v.toString()),
                                  ),
                                ),
                                onChanged:
                                    editable && !notApplicable[index].value
                                    ? (v) => scores[index].value = v
                                    : null,
                              ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ValueListenableBuilder<bool>(
                        valueListenable: notApplicable[index],
                        builder: (_, selected, _) => FilterChip(
                          label: const Text('N/A'),
                          selected: selected,
                          onSelected: editable
                              ? (v) => notApplicable[index].value = v
                              : null,
                        ),
                      ),
                    ],
                  ),
                  if (editable) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () =>
                          uploadInspectionPhoto(detail['id'].toString()),
                      icon: const Icon(Icons.add_a_photo_outlined),
                      label: Text(
                        detail['requirePhoto'] == true
                            ? 'แนบรูปหลักฐาน *'
                            : 'แนบรูปหลักฐาน',
                      ),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('ปิด'),
          ),
          if (editable)
            FilledButton.icon(
              onPressed: () async {
                await api.put(
                  '/api/company/five-s/inspections/$id/details',
                  body: {
                    'items': details
                        .asMap()
                        .entries
                        .map(
                          (entry) => {
                            'detailID': entry.value['id'],
                            'score': scores[entry.key].value,
                            'notApplicable': notApplicable[entry.key].value,
                            'remark': null,
                            'createFinding': false,
                          },
                        )
                        .toList(),
                  },
                );
                if (dialogContext.mounted) Navigator.pop(dialogContext, true);
              },
              icon: const Icon(Icons.save_outlined),
              label: const Text('บันทึก'),
            ),
          if (editable && actions['submit'] == true)
            FilledButton.icon(
              onPressed: () async {
                await api.put(
                  '/api/company/five-s/inspections/$id/details',
                  body: {
                    'items': details
                        .asMap()
                        .entries
                        .map(
                          (entry) => {
                            'detailID': entry.value['id'],
                            'score': scores[entry.key].value,
                            'notApplicable': notApplicable[entry.key].value,
                            'remark': entry.value['remark'],
                            'createFinding':
                                entry.value['createFinding'] == true,
                          },
                        )
                        .toList(),
                  },
                );
                await api.post(
                  '/api/company/five-s/inspections/$id/submit',
                  body: const {},
                );
                if (dialogContext.mounted) Navigator.pop(dialogContext, true);
              },
              icon: const Icon(Icons.send_outlined),
              label: const Text('บันทึกและส่งผล'),
            ),
        ],
      ),
    );
    if (saved == true) success('บันทึกผลตรวจแล้ว');
  }

  Future<void> uploadInspectionPhoto(String detailId) async {
    final selected = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (selected == null || selected.files.isEmpty) return;
    final file = selected.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      if (mounted) {
        showFiveSMessage(
          context,
          message: 'อ่านไฟล์รูปภาพไม่สำเร็จ',
          error: true,
        );
      }
      return;
    }
    await uploadFiveSFile(
      '/api/company/five-s/attachments/INSPECTION',
      fileName: file.name,
      bytes: bytes,
      fields: {'inspectionDetailId': detailId},
    );
    if (mounted) {
      showFiveSMessage(
        context,
        message: 'แนบรูปแล้ว ระบบจะลดขนาดให้ไม่เกิน 1 MB อัตโนมัติ',
      );
    }
  }

  SizedBox numberField(TextEditingController controller, String label) =>
      SizedBox(
        width: 240,
        child: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: label),
        ),
      );
  Widget empty() =>
      Center(child: Text('ไม่พบข้อมูล', style: fiveSUiTokens.inputStyle));
  Widget stateCard(String text, {bool retry = false}) => LaooSurfaceCard(
    tokens: fiveSUiTokens,
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
    showFiveSMessage(context, message: message);
    reload();
  }

  static String first(Map<String, dynamic> item, List<String> keys) {
    for (final key in keys) {
      final value = item[key];
      if (value != null && value.toString().isNotEmpty) return value.toString();
    }
    return '-';
  }

  static Map<String, dynamic> map(dynamic value) => value is Map
      ? value.map((key, item) => MapEntry(key.toString(), item))
      : <String, dynamic>{};
  static List<Map<String, dynamic>> rows(dynamic value) {
    if (value is List) {
      return value
          .whereType<Map>()
          .map(
            (item) => item.map((key, data) => MapEntry(key.toString(), data)),
          )
          .toList();
    }
    final data = map(value);
    for (final key in const ['rows', 'items', 'data']) {
      if (data[key] is List) return rows(data[key]);
    }
    return const [];
  }
}
