// ignore_for_file: curly_braces_in_flow_control_structures
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';
import 'school_feature_host.dart';

class SchoolPage extends StatefulWidget {
  const SchoolPage({
    super.key,
    required this.menuCode,
    required this.fallbackTitle,
  });
  final String menuCode;
  final String fallbackTitle;
  @override
  State<SchoolPage> createState() => _SchoolPageState();
}

class _SchoolPageState extends State<SchoolPage> {
  late final JsonApiClient api = createSchoolApi();
  String title = '';
  bool loading = true;
  Object? error;
  dynamic data;
  Map<String, dynamic> actions = {}, options = {};
  bool cards = false;
  int page = 0;
  static const pageSize = 10;
  @override
  void initState() {
    super.initState();
    title = widget.fallbackTitle;
    schoolTitle(widget.menuCode, title).then((v) {
      if (mounted) setState(() => title = v);
    });
    load();
  }

  @override
  void dispose() {
    disposeSchoolApi(api);
    super.dispose();
  }

  String get endpoint => switch (widget.menuCode) {
    '52001' => 'settings',
    '52002' => 'masters/level',
    '52003' => 'masters/round',
    '52004' => 'masters/holiday',
    '52005' => 'academics',
    '52006' => 'students',
    '52007' => 'guardians',
    '52008' => 'attendance',
    '52009' => 'roll-call?timetableId=${_firstTimetable()}',
    '52010' => 'news',
    '52011' => 'reports/daily',
    '52012' => 'reports/period',
    '52013' => 'dashboard',
    _ => 'news',
  };

  int _firstTimetable() {
    final rows = _rows(options['timetables']);
    return rows.isEmpty ? 0 : (rows.first['id'] as num).toInt();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      actions = _map(
        await api.get('/api/company/school/actions/${widget.menuCode}'),
      );
      options = _map(await api.get('/api/company/school/options'));
      data = widget.menuCode == '52014'
          ? <String, dynamic>{}
          : await api.get('/api/company/school/$endpoint');
      if (mounted) setState(() => loading = false);
    } catch (e) {
      if (mounted)
        setState(() {
          error = e;
          loading = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) => schoolShell(
    title: title,
    menu: title,
    child: Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          LaooCaptionCard(
            tokens: schoolTokens,
            caption: title,
            leading: Icon(_icon, color: schoolTokens.primaryColor),
            favoriteKey: widget.menuCode,
            trailing: _topActions(),
          ),
          SizedBox(height: schoolTokens.sectionSpacing),
          if (loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (error != null)
            Expanded(child: _error())
          else
            Expanded(child: _content()),
        ],
      ),
    ),
  );

  IconData get _icon => switch (widget.menuCode) {
    '52001' => Icons.settings_outlined,
    '52008' => Icons.how_to_reg_outlined,
    '52009' => Icons.fact_check_outlined,
    '52010' => Icons.campaign_outlined,
    '52013' => Icons.dashboard_outlined,
    '52014' => Icons.family_restroom_outlined,
    _ => Icons.school_outlined,
  };
  Widget _topActions() => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (const {
        '52002',
        '52003',
        '52004',
        '52005',
        '52006',
        '52007',
        '52010',
      }.contains(widget.menuCode))
        LaooListCardToggle(
          tokens: schoolTokens,
          cards: cards,
          onChanged: (v) => setState(() => cards = v),
        ),
      if (actions['create'] == true) ...[
        SizedBox(width: schoolTokens.itemSpacing),
        _button('เพิ่ม', Icons.add, _addDialog),
      ],
    ],
  );
  Widget _content() => switch (widget.menuCode) {
    '52001' => _settings(),
    '52013' => _dashboard(),
    '52008' => _attendance(),
    '52009' => _rollCall(),
    '52005' => _academics(),
    '52014' => _guardianEntry(),
    _ => _list(),
  };
  Widget _guardianEntry() => _card(
    Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.family_restroom_outlined,
              size: 56,
              color: schoolTokens.primaryColor,
            ),
            const SizedBox(height: 16),
            const Text(
              'มุมผู้ปกครอง',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'ผู้ปกครองใช้รหัสโรงเรียน Email และรหัสผ่านของตนเอง เพื่อตรวจเวลาเรียนของบุตรหลานและอ่านข่าวสารจากโรงเรียน',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            _button(
              'เปิดหน้าผู้ปกครอง',
              Icons.open_in_new,
              () => context.go('/school/guardian'),
            ),
          ],
        ),
      ),
    ),
  );
  Widget _error() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, size: 42),
        const SizedBox(height: 8),
        const Text('โหลดข้อมูลไม่สำเร็จ'),
        const SizedBox(height: 4),
        const Text('รายละเอียดเพิ่มเติม: ตรวจสอบสิทธิ์หรือการเชื่อมต่อ API'),
        const SizedBox(height: 12),
        _button('ลองอีกครั้ง', Icons.replay, load),
      ],
    ),
  );
  Widget _button(String text, IconData icon, VoidCallback? tap) => SizedBox(
    height: 48,
    child: FilledButton.icon(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      onPressed: tap,
      icon: Icon(icon),
      label: Text(text),
    ),
  );
  Widget _card(Widget child) => Card(
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    child: Padding(padding: const EdgeInsets.all(10), child: child),
  );
  Widget _list() {
    final allRows = _items(data);
    if (allRows.isEmpty)
      return _card(
        const Center(
          child: Padding(
            padding: EdgeInsets.all(28),
            child: Text('ยังไม่มีข้อมูล'),
          ),
        ),
      );
    final lastPage = (allRows.length - 1) ~/ pageSize;
    if (page > lastPage) page = lastPage;
    final rows = allRows.skip(page * pageSize).take(pageSize).toList();
    final canManage = actions['edit'] == true || actions['delete'] == true;
    final body = cards
        ? GridView.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 320,
              mainAxisExtent: 172,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
            ),
            itemCount: rows.length,
            itemBuilder: (_, i) {
              final r = rows[i];
              return _card(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _name(r),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _subtitle(r),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Divider(),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            r['active'] == false ? 'ปิดใช้งาน' : 'ใช้งาน',
                          ),
                        ),
                        if (actions['edit'] == true)
                          IconButton(
                            tooltip: 'แก้ไข',
                            onPressed: () => _editDialog(r),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                        if (widget.menuCode == '52007' &&
                            actions['edit'] == true)
                          IconButton(
                            tooltip: 'ตั้งรหัสผ่าน',
                            onPressed: () => _passwordDialog(r),
                            icon: const Icon(Icons.key_outlined),
                          ),
                        if (actions['delete'] == true)
                          IconButton(
                            tooltip: 'ลบ',
                            color: Colors.red,
                            onPressed: () => _confirmDelete(r),
                            icon: const Icon(Icons.delete_outline),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            },
          )
        : LayoutBuilder(
            builder: (context, constraints) {
              final keys = rows.first.keys
                  .where((x) => !const {'id', 'active'}.contains(x))
                  .take(6)
                  .toList();
              return _card(
                Scrollbar(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: constraints.maxWidth - 20,
                      ),
                      child: DataTable(
                        columns: [
                          if (canManage)
                            const DataColumn(label: Text('จัดการ')),
                          for (final key in keys)
                            DataColumn(label: Text(_label(key))),
                        ],
                        rows: [
                          for (final row in rows)
                            DataRow(
                              cells: [
                                if (canManage)
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (actions['edit'] == true)
                                          IconButton(
                                            tooltip: 'แก้ไข',
                                            onPressed: () => _editDialog(row),
                                            icon: const Icon(
                                              Icons.edit_outlined,
                                            ),
                                          ),
                                        if (widget.menuCode == '52007' &&
                                            actions['edit'] == true)
                                          IconButton(
                                            tooltip: 'ตั้งรหัสผ่าน',
                                            onPressed: () =>
                                                _passwordDialog(row),
                                            icon: const Icon(
                                              Icons.key_outlined,
                                            ),
                                          ),
                                        if (actions['delete'] == true)
                                          IconButton(
                                            tooltip: 'ลบ',
                                            color: Colors.red,
                                            onPressed: () =>
                                                _confirmDelete(row),
                                            icon: const Icon(
                                              Icons.delete_outline,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                for (final key in keys)
                                  DataCell(
                                    SizedBox(
                                      width: key == 'name' || key == 'title'
                                          ? 260
                                          : 130,
                                      child: Text(
                                        _text(row[key]),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
    return Column(
      children: [
        Expanded(child: body),
        const SizedBox(height: 6),
        _card(
          Row(
            children: [
              IconButton(
                tooltip: 'ก่อนหน้า',
                onPressed: page == 0 ? null : () => setState(() => page--),
                icon: const Icon(Icons.chevron_left),
              ),
              Text('หน้า ${page + 1} / ${lastPage + 1}'),
              IconButton(
                tooltip: 'ถัดไป',
                onPressed: page >= lastPage
                    ? null
                    : () => setState(() => page++),
                icon: const Icon(Icons.chevron_right),
              ),
              const Spacer(),
              Text(
                '${page * pageSize + 1}-${page * pageSize + rows.length} จาก ${allRows.length}',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _dashboard() {
    final summary = _map(_map(data)['summary']);
    final values = [
      ('นักเรียนทั้งหมด', summary['total'], Icons.groups_outlined),
      ('มาเรียนแล้ว', summary['present'], Icons.check_circle_outline),
      ('มาสาย', summary['late'], Icons.schedule_outlined),
      ('ขาดเรียน', summary['absent'], Icons.person_off_outlined),
    ];
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 300,
        mainAxisExtent: 140,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: values.length,
      itemBuilder: (_, i) => _card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(values[i].$3, color: schoolTokens.primaryColor),
            const Spacer(),
            Text(
              _text(values[i].$2),
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
            ),
            Text(values[i].$1),
          ],
        ),
      ),
    );
  }

  Widget _academics() {
    final source = _map(data);
    return ListView(
      children: [
        _academicSection(
          'วิชา',
          Icons.menu_book_outlined,
          _rows(source['subjects']),
          onAdd: _addDialog,
          onEdit: _editDialog,
          onDelete: _confirmDelete,
        ),
        const SizedBox(height: 8),
        _academicSection(
          'ห้องเรียน',
          Icons.meeting_room_outlined,
          _rows(source['classrooms']),
          onAdd: () => _classroomDialog(),
          onEdit: (row) => _classroomDialog(row: row),
          onDelete: (row) => _confirmDelete(
            row,
            path: '/api/company/school/masters/classroom/${row['id']}',
          ),
        ),
        const SizedBox(height: 8),
        _academicSection(
          'ตารางเรียน',
          Icons.calendar_month_outlined,
          _rows(source['timetables']),
          onAdd: () => _timetableDialog(),
          onEdit: (row) => _timetableDialog(row: row),
          onDelete: (row) => _confirmDelete(
            row,
            path: '/api/company/school/timetables/${row['id']}',
          ),
        ),
      ],
    );
  }

  Widget _academicSection(
    String caption,
    IconData icon,
    List<Map<String, dynamic>> rows, {
    required VoidCallback onAdd,
    required ValueChanged<Map<String, dynamic>> onEdit,
    required ValueChanged<Map<String, dynamic>> onDelete,
  }) => _card(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: schoolTokens.primaryColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                caption,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (actions['create'] == true)
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: const Text('เพิ่ม'),
              ),
          ],
        ),
        const Divider(),
        if (rows.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: Text('ยังไม่มีข้อมูล')),
          )
        else
          for (final row in rows)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_name(row)),
              subtitle: Text(_subtitle(row)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (actions['edit'] == true)
                    IconButton(
                      tooltip: 'แก้ไข',
                      onPressed: () => onEdit(row),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                  if (actions['delete'] == true)
                    IconButton(
                      tooltip: 'ลบ',
                      color: Colors.red,
                      onPressed: () => onDelete(row),
                      icon: const Icon(Icons.delete_outline),
                    ),
                ],
              ),
            ),
      ],
    ),
  );

  Widget _settings() {
    final row = _map(data);
    var mode = _text(row['attendanceMode']);
    var period = row['requirePeriodAttendance'] == true;
    var active = row['active'] != false;
    final grace = TextEditingController(text: _text(row['lateGraceMinutes']));
    return StatefulBuilder(
      builder: (context, setLocal) => _card(
        ListView(
          children: [
            const Text(
              'ค่าการทำงานปัจจุบัน',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const Divider(),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('สถานะ'),
              subtitle: Text(active ? 'เปิดใช้งาน' : 'ปิดใช้งาน'),
              value: active,
              onChanged: (v) => setLocal(() => active = v),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: mode,
              decoration: _decoration('รูปแบบเวลาเข้า–ออก'),
              items: const [
                DropdownMenuItem(
                  value: 'SINGLE',
                  child: Text('เวลาเดียวทั้งโรงเรียน'),
                ),
                DropdownMenuItem(
                  value: 'LEVEL',
                  child: Text('แยกตามระดับชั้น'),
                ),
                DropdownMenuItem(value: 'ROUND', child: Text('แยกตามรอบเรียน')),
              ],
              onChanged: (v) => setLocal(() => mode = v!),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: grace,
              keyboardType: TextInputType.number,
              decoration: _decoration('นาทีผ่อนผันก่อนมาสาย'),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('ต้องลงเวลาเรียนรายคาบ'),
              value: period,
              onChanged: (v) => setLocal(() => period = v),
            ),
            const SizedBox(height: 20),
            if (actions['edit'] == true)
              Align(
                alignment: Alignment.centerRight,
                child: _button('บันทึก', Icons.save_outlined, () async {
                  await api.put(
                    '/api/company/school/settings',
                    body: {
                      'attendanceMode': mode,
                      'requirePeriodAttendance': period,
                      'lateGraceMinutes': int.tryParse(grace.text),
                      'active': active,
                    },
                  );
                  if (!mounted) return;
                  schoolMessage(this.context, 'บันทึกค่าระบบโรงเรียนแล้ว');
                  await load();
                }),
              ),
          ],
        ),
      ),
    );
  }

  InputDecoration _decoration(String label) => InputDecoration(
    labelText: label,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(4),
      borderSide: const BorderSide(color: Color(0xFFD9DFDC)),
    ),
  );
  Widget _attendance() {
    final rows = _items(data);
    return _card(
      ListView.separated(
        itemCount: rows.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final r = rows[i];
          return ListTile(
            title: Text(_name(r)),
            subtitle: Text(
              '${_text(r['classroom'])} · ${_status(r['status'])}',
            ),
            trailing: actions['create'] == true
                ? _button('ลงเวลา', Icons.login, () async {
                    final now = DateTime.now();
                    await api.post(
                      '/api/company/school/attendance',
                      body: {
                        'studentId': r['id'],
                        'date': now.toIso8601String(),
                        'checkInAt': now.toIso8601String(),
                        'status': 'PRESENT',
                      },
                    );
                    if (!mounted) return;
                    schoolMessage(this.context, 'บันทึกเวลาแล้ว');
                    await load();
                  })
                : null,
          );
        },
      ),
    );
  }

  Widget _rollCall() {
    final rows = _rows(_map(data)['students']);
    return Column(
      children: [
        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 360,
              mainAxisExtent: 118,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
            ),
            itemCount: rows.length,
            itemBuilder: (_, i) {
              final r = rows[i];
              return _card(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _name(r),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    Wrap(
                      spacing: 4,
                      children: [
                        for (final item in const [
                          ('PRESENT', 'มา'),
                          ('LATE', 'สาย'),
                          ('LEAVE', 'ลา'),
                          ('ABSENT', 'ขาด'),
                        ])
                          ChoiceChip(
                            label: Text(item.$2),
                            selected: r['status'] == item.$1,
                            onSelected: (_) =>
                                setState(() => r['status'] = item.$1),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        if (actions['create'] == true)
          Align(
            alignment: Alignment.centerRight,
            child: _button('บันทึกการเช็กชื่อ', Icons.save_outlined, () async {
              final tables = _rows(options['timetables']);
              if (tables.isEmpty) return;
              await api.post(
                '/api/company/school/roll-call',
                body: {
                  'timetableId': tables.first['id'],
                  'date': DateTime.now().toIso8601String(),
                  'students': [
                    for (final r in rows)
                      {'studentId': r['id'], 'status': r['status']},
                  ],
                },
              );
              if (mounted) schoolMessage(context, 'บันทึกการเช็กชื่อแล้ว');
            }),
          ),
      ],
    );
  }

  String _status(dynamic v) => switch (v) {
    'PRESENT' => 'มาเรียน',
    'LATE' => 'มาสาย',
    'LEAVE' => 'ลา',
    'ABSENT' => 'ขาดเรียน',
    _ => '-',
  };
  Future<void> _addDialog() => _actionDialog();
  Future<void> _editDialog(Map<String, dynamic> row) => _actionDialog(row: row);
  Future<void> _actionDialog({Map<String, dynamic>? row}) async {
    final editing = row != null;
    var active = row?['active'] != false;
    final code = TextEditingController(
          text: _textOrEmpty(row?['code'] ?? row?['title']),
        ),
        name = TextEditingController(
          text: _textOrEmpty(row?['body'] ?? row?['name']),
        ),
        extra = TextEditingController(text: _textOrEmpty(row?['email']));
    final selectedStudents = _textOrEmpty(
      row?['studentIds'],
    ).split(',').map(int.tryParse).whereType<int>().toSet();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialog) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      Icon(_icon, color: schoolTokens.primaryColor),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          title + (editing ? ' > แก้ไข' : ' > เพิ่ม'),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      children: [
                        if (widget.menuCode != '52010') ...[
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('สถานะ'),
                            subtitle: Text(active ? 'เปิดใช้งาน' : 'ปิดใช้งาน'),
                            value: active,
                            onChanged: (value) =>
                                setDialog(() => active = value),
                          ),
                          const SizedBox(height: 16),
                        ],
                        TextField(
                          controller: code,
                          decoration: _decoration(
                            widget.menuCode == '52010' ? 'หัวข้อ' : 'รหัส *',
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: name,
                          maxLines: widget.menuCode == '52010' ? 4 : 1,
                          decoration: _decoration(
                            widget.menuCode == '52010' ? 'เนื้อหา *' : 'ชื่อ *',
                          ),
                        ),
                        if (widget.menuCode == '52007') ...[
                          const SizedBox(height: 16),
                          TextField(
                            controller: extra,
                            decoration: _decoration('Email Login *'),
                          ),
                          const SizedBox(height: 16),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'บุตรหลาน',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          StatefulBuilder(
                            builder: (context, setStudents) => Column(
                              children: [
                                for (final student in _rows(
                                  options['students'],
                                ))
                                  CheckboxListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(_name(student)),
                                    subtitle: Text(_text(student['code'])),
                                    value: selectedStudents.contains(
                                      (student['id'] as num).toInt(),
                                    ),
                                    onChanged: (checked) => setStudents(() {
                                      final id = (student['id'] as num).toInt();
                                      checked == true
                                          ? selectedStudents.add(id)
                                          : selectedStudents.remove(id);
                                    }),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      SizedBox(
                        height: 48,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          child: const Text('ยกเลิก'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _button('บันทึก', Icons.save_outlined, () async {
                        await _save(
                          row,
                          code.text,
                          name.text,
                          extra.text,
                          selectedStudents,
                          active,
                        );
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save(
    Map<String, dynamic>? row,
    String code,
    String name,
    String extra,
    Set<int> selectedStudents,
    bool active,
  ) async {
    if (code.trim().isEmpty || name.trim().isEmpty) {
      schoolMessage(context, 'กรอกข้อมูลบังคับให้ครบ', error: true);
      return;
    }
    if (widget.menuCode == '52006') {
      final rooms = _rows(options['rooms']);
      if (rooms.isEmpty) {
        schoolMessage(context, 'ต้องเพิ่มห้องเรียนก่อน', error: true);
        return;
      }
      final parts = name.trim().split(' ');
      await _write(
        '/api/company/school/students',
        row,
        body: {
          'code': code,
          'firstName': parts.first,
          'lastName': parts.skip(1).join(' ').isEmpty
              ? '-'
              : parts.skip(1).join(' '),
          'classroomId': rooms.first['id'],
          'active': active,
        },
      );
    } else if (widget.menuCode == '52007') {
      await _write(
        '/api/company/school/guardians',
        row,
        body: {
          'code': code,
          'fullName': name,
          'email': extra,
          'active': active,
          'studentIds': selectedStudents.toList(),
        },
      );
    } else if (widget.menuCode == '52010') {
      await _write(
        '/api/company/school/news',
        row,
        body: {
          'title': code,
          'body': name,
          'audienceMode': 'ALL',
          'publish': false,
        },
      );
    } else {
      final type = switch (widget.menuCode) {
        '52002' => 'level',
        '52003' => 'round',
        '52004' => 'holiday',
        _ => 'subject',
      };
      final levels = _rows(options['levels']);
      await _write(
        '/api/company/school/masters/$type',
        row,
        body: {
          'code': code,
          'name': name,
          'parentId': levels.isEmpty ? null : levels.first['id'],
          'date': DateTime.tryParse(code)?.toIso8601String(),
          'startTime': '08:00:00',
          'endTime': '16:00:00',
          'lateAfter': '08:15:00',
          'active': active,
        },
      );
    }
    if (mounted) schoolMessage(context, 'บันทึกข้อมูลแล้ว');
    await load();
  }

  Future<void> _write(
    String path,
    Map<String, dynamic>? row, {
    required Map<String, dynamic> body,
  }) => row == null
      ? api.post(path, body: body)
      : api.put('$path/${row['id']}', body: body);

  Future<void> _classroomDialog({Map<String, dynamic>? row}) async {
    final code = TextEditingController(text: _textOrEmpty(row?['code']));
    final name = TextEditingController(text: _textOrEmpty(row?['name']));
    final levels = _rows(options['levels']);
    int? levelId = row?['levelId'] is num
        ? (row!['levelId'] as num).toInt()
        : levels.firstOrNull?['id'] as int?;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          title: Text(
            'ห้องเรียน > ${row == null ? 'เพิ่ม' : 'แก้ไข'}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: levelId,
                  decoration: _decoration('ระดับชั้น *'),
                  items: [
                    for (final level in levels)
                      DropdownMenuItem(
                        value: (level['id'] as num).toInt(),
                        child: Text(_name(level)),
                      ),
                  ],
                  onChanged: (value) => setLocal(() => levelId = value),
                ),
                const SizedBox(height: 16),
                TextField(controller: code, decoration: _decoration('รหัส *')),
                const SizedBox(height: 16),
                TextField(controller: name, decoration: _decoration('ชื่อ *')),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('ยกเลิก'),
            ),
            _button('บันทึก', Icons.save_outlined, () async {
              if (levelId == null ||
                  code.text.trim().isEmpty ||
                  name.text.trim().isEmpty) {
                schoolMessage(
                  this.context,
                  'กรอกข้อมูลบังคับให้ครบ',
                  error: true,
                );
                return;
              }
              await _write(
                '/api/company/school/masters/classroom',
                row,
                body: {
                  'code': code.text,
                  'name': name.text,
                  'parentId': levelId,
                  'academicYear': DateTime.now().year + 543,
                  'active': true,
                },
              );
              if (!mounted || !dialogContext.mounted) return;
              Navigator.pop(dialogContext);
              schoolMessage(this.context, 'บันทึกห้องเรียนแล้ว');
              await load();
            }),
          ],
        ),
      ),
    );
    code.dispose();
    name.dispose();
  }

  Future<void> _timetableDialog({Map<String, dynamic>? row}) async {
    final rooms = _rows(options['rooms']);
    final subjects = _rows(options['subjects']);
    int? roomId = row?['classroomId'] is num
        ? (row!['classroomId'] as num).toInt()
        : rooms.firstOrNull?['id'] as int?;
    int? subjectId = row?['subjectId'] is num
        ? (row!['subjectId'] as num).toInt()
        : subjects.firstOrNull?['id'] as int?;
    var day = row?['dayOfWeek'] is num ? (row!['dayOfWeek'] as num).toInt() : 1;
    final period = TextEditingController(
      text: _textOrEmpty(row?['periodNo']).isEmpty
          ? '1'
          : _textOrEmpty(row?['periodNo']),
    );
    final start = TextEditingController(
      text: _textOrEmpty(row?['startTime']).isEmpty
          ? '08:30:00'
          : _textOrEmpty(row?['startTime']),
    );
    final end = TextEditingController(
      text: _textOrEmpty(row?['endTime']).isEmpty
          ? '09:20:00'
          : _textOrEmpty(row?['endTime']),
    );
    final learningRoom = TextEditingController(
      text: _textOrEmpty(row?['learningRoom']),
    );
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          title: Text(
            'ตารางเรียน > ${row == null ? 'เพิ่ม' : 'แก้ไข'}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: roomId,
                    decoration: _decoration('ห้องเรียน *'),
                    items: [
                      for (final room in rooms)
                        DropdownMenuItem(
                          value: (room['id'] as num).toInt(),
                          child: Text(_name(room)),
                        ),
                    ],
                    onChanged: (value) => setLocal(() => roomId = value),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    initialValue: subjectId,
                    decoration: _decoration('วิชา *'),
                    items: [
                      for (final subject in subjects)
                        DropdownMenuItem(
                          value: (subject['id'] as num).toInt(),
                          child: Text(_name(subject)),
                        ),
                    ],
                    onChanged: (value) => setLocal(() => subjectId = value),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    initialValue: day,
                    decoration: _decoration('วัน *'),
                    items: [
                      for (var value = 1; value <= 7; value++)
                        DropdownMenuItem(
                          value: value,
                          child: Text('วันที่ $value'),
                        ),
                    ],
                    onChanged: (value) => setLocal(() => day = value ?? 1),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: period,
                    keyboardType: TextInputType.number,
                    decoration: _decoration('คาบที่ *'),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: start,
                          decoration: _decoration('เริ่ม *'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: end,
                          decoration: _decoration('สิ้นสุด *'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: learningRoom,
                    decoration: _decoration('ห้องที่เรียน'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('ยกเลิก'),
            ),
            _button('บันทึก', Icons.save_outlined, () async {
              if (roomId == null || subjectId == null) {
                schoolMessage(
                  this.context,
                  'กรอกข้อมูลบังคับให้ครบ',
                  error: true,
                );
                return;
              }
              await _write(
                '/api/company/school/timetables',
                row,
                body: {
                  'classroomId': roomId,
                  'subjectId': subjectId,
                  'dayOfWeek': day,
                  'periodNo': int.tryParse(period.text) ?? 0,
                  'startTime': start.text,
                  'endTime': end.text,
                  'learningRoom': learningRoom.text,
                  'active': true,
                },
              );
              if (!mounted || !dialogContext.mounted) return;
              Navigator.pop(dialogContext);
              schoolMessage(this.context, 'บันทึกตารางเรียนแล้ว');
              await load();
            }),
          ],
        ),
      ),
    );
    period.dispose();
    start.dispose();
    end.dispose();
    learningRoom.dispose();
  }

  Future<void> _passwordDialog(Map<String, dynamic> row) async {
    final password = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        title: const Text(
          'ข้อมูลผู้ปกครอง > ตั้งรหัสผ่าน',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        content: SizedBox(
          width: 420,
          child: TextField(
            controller: password,
            obscureText: true,
            decoration: _decoration('รหัสผ่านใหม่ *'),
          ),
        ),
        actions: [
          SizedBox(
            height: 48,
            child: TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('ยกเลิก'),
            ),
          ),
          _button('บันทึก', Icons.save_outlined, () async {
            await api.put(
              '/api/company/school/guardians/${row['id']}/password',
              body: {'password': password.text},
            );
            if (!mounted || !dialogContext.mounted) return;
            Navigator.pop(dialogContext);
            schoolMessage(context, 'ตั้งรหัสผ่านผู้ปกครองแล้ว');
          }),
        ],
      ),
    );
    password.dispose();
  }

  Future<void> _confirmDelete(Map<String, dynamic> row, {String? path}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 40),
        title: const Text(
          'ยืนยันการลบ',
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xffffeeee),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(_name(row), textAlign: TextAlign.center),
            ),
            const SizedBox(height: 12),
            const Text('เมื่อลบแล้วจะไม่สามารถเรียกคืนข้อมูลได้'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await api.delete(path ?? _deletePath(row));
    if (!mounted) return;
    schoolMessage(context, 'ลบข้อมูลแล้ว');
    await load();
  }

  String _deletePath(Map<String, dynamic> row) {
    final id = row['id'].toString();
    if (widget.menuCode == '52006') {
      return '/api/company/school/students/$id';
    }
    if (widget.menuCode == '52007') {
      return '/api/company/school/guardians/$id';
    }
    if (widget.menuCode == '52010') {
      return '/api/company/school/news/$id';
    }
    final type = switch (widget.menuCode) {
      '52002' => 'level',
      '52003' => 'round',
      '52004' => 'holiday',
      _ => 'subject',
    };
    return '/api/company/school/masters/$type/$id';
  }

  Map<String, dynamic> _map(dynamic value) => value is Map<String, dynamic>
      ? value
      : Map<String, dynamic>.from(value as Map);
  List<Map<String, dynamic>> _rows(dynamic value) =>
      value is List ? value.map(_map).toList() : <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _items(dynamic value) =>
      value is Map ? _rows(_map(value)['items']) : _rows(value);
  String _text(dynamic value) => value?.toString() ?? '-';
  String _textOrEmpty(dynamic value) => value?.toString() ?? '';
  String _name(Map<String, dynamic> row) =>
      _text(row['name'] ?? row['title'] ?? row['code']);
  String _subtitle(Map<String, dynamic> row) => row.entries
      .where((e) => !const {'id', 'name', 'title', 'active'}.contains(e.key))
      .take(3)
      .map((e) => '${_label(e.key)}: ${_text(e.value)}')
      .join(' · ');
  String _label(String key) =>
      const {
        'code': 'รหัส',
        'name': 'ชื่อ',
        'email': 'Email',
        'telephone': 'โทรศัพท์',
        'classroom': 'ชั้น/ห้อง',
        'roundName': 'รอบเรียน',
        'status': 'สถานะ',
        'audienceMode': 'กลุ่มผู้รับ',
        'publishedAt': 'เผยแพร่เมื่อ',
        'createDate': 'สร้างเมื่อ',
        'total': 'จำนวน',
        'late': 'มาสาย',
        'absent': 'ขาด',
        'attended': 'เข้าเรียน',
      }[key] ??
      key;
}
