import 'package:flutter/material.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';
import 'project_feature_host.dart';

enum ProjectPageMode { settings, categories, projects, myTasks, reports }

class ProjectPage extends StatefulWidget {
  const ProjectPage({
    required this.menuCode,
    required this.fallbackTitle,
    required this.mode,
    super.key,
  });
  final String menuCode, fallbackTitle;
  final ProjectPageMode mode;
  @override
  State<ProjectPage> createState() => _S();
}

class _S extends State<ProjectPage> {
  late final JsonApiClient api = createProjectApiClient();
  late Future<Map<String, dynamic>> f;
  String title = '';
  int page = 1;
  int? reportYear, reportMonth, reportDepartmentId, reportManagerId;
  String? reportStatus;
  final q = TextEditingController();
  @override
  void initState() {
    super.initState();
    title = widget.fallbackTitle;
    f = load();
    resolveProjectMenuTitle(widget.menuCode, title).then((v) {
      if (mounted) setState(() => title = v);
    });
  }

  @override
  void dispose() {
    q.dispose();
    disposeProjectApiClient(api);
    super.dispose();
  }

  Future<Map<String, dynamic>> load() async {
    final a = map(
      await api.get(
        '/api/company/project-management/actions/' + widget.menuCode,
      ),
    );
    final search = Uri.encodeQueryComponent(q.text.trim());
    final path = switch (widget.mode) {
      ProjectPageMode.settings => 'settings',
      ProjectPageMode.categories => 'budget-categories',
      ProjectPageMode.projects =>
        'projects?search=$search&page=$page&pageSize=10',
      ProjectPageMode.myTasks => 'my-tasks?search=$search',
      ProjectPageMode.reports => reportPath(),
    };
    final result = <String, dynamic>{
      'a': a,
      'd': await api.get('/api/company/project-management/' + path),
    };
    if (widget.mode == ProjectPageMode.reports) {
      result['o'] = await api.get('/api/company/project-management/options');
    }
    return result;
  }

  String reportPath() {
    final p = <String, String>{};
    if (reportYear != null) p['year'] = '';
    if (reportMonth != null) p['month'] = '';
    if (reportStatus != null) p['status'] = reportStatus!;
    if (reportDepartmentId != null) p['departmentId'] = '';
    if (reportManagerId != null) p['managerId'] = '';
    final query = Uri(queryParameters: p).query;
    return query.isEmpty ? 'reports' : 'reports?';
  }

  void reload() => setState(() => f = load());
  @override
  Widget build(BuildContext c) => buildProjectWorkspaceShell(
    pageTitle: title,
    activeMenu: widget.menuCode,
    child: Padding(
      padding: projectUiTokens.contentMargin,
      child: FutureBuilder<Map<String, dynamic>>(
        future: f,
        builder: (_, s) {
          if (s.connectionState != ConnectionState.done)
            return frame(const Center(child: CircularProgressIndicator()));
          if (s.hasError)
            return frame(
              Center(
                child: OutlinedButton.icon(
                  onPressed: reload,
                  icon: const Icon(Icons.replay),
                  label: const Text('โหลดไม่สำเร็จ ลองอีกครั้ง'),
                ),
              ),
            );
          final v = s.data!;
          return switch (widget.mode) {
            ProjectPageMode.settings => Settings(
              api: api,
              title: title,
              data: map(v['d']),
              edit: map(v['a'])['edit'] == true,
              done: reload,
            ),
            ProjectPageMode.categories => listPage(
              rows(v['d']),
              map(v['a']),
              true,
            ),
            ProjectPageMode.projects => listPage(
              rows(map(v['d'])['items']),
              map(v['a']),
              false,
              pageData: map(v['d']),
            ),
            ProjectPageMode.myTasks => tasks(rows(v['d']), map(v['a'])),
            ProjectPageMode.reports => reports(map(v['d']), map(v['o'])),
          };
        },
      ),
    ),
  );
  Widget caption({Widget? x}) => LaooCaptionCard(
    tokens: projectUiTokens,
    leading: Icon(
      Icons.account_tree_outlined,
      color: projectUiTokens.primaryColor,
    ),
    caption: title,
    trailing: x,
  );
  Widget frame(Widget x) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      caption(),
      SizedBox(height: projectUiTokens.sectionSpacing),
      Expanded(
        child: LaooSurfaceCard(tokens: projectUiTokens, child: x),
      ),
    ],
  );
  Widget filter() => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      SizedBox(
        width: 280,
        child: TextField(
          controller: q,
          decoration: inp('ค้นหารหัสหรือชื่อ', Icons.search),
        ),
      ),
      FilledButton.icon(
        onPressed: () {
          page = 1;
          reload();
        },
        icon: const Icon(Icons.search),
        label: const Text('ค้นหา'),
      ),
      OutlinedButton.icon(
        onPressed: () {
          q.clear();
          page = 1;
          reload();
        },
        icon: const Icon(Icons.filter_alt_off_outlined),
        label: const Text('ล้าง Filter'),
      ),
    ],
  );
  Widget listPage(
    List<Map<String, dynamic>> r,
    Map<String, dynamic> a,
    bool cat, {
    Map<String, dynamic>? pageData,
  }) {
    final visible = cat && q.text.trim().isNotEmpty
        ? r
              .where(
                (x) => ('${x['code']} ${x['name']}').toLowerCase().contains(
                  q.text.trim().toLowerCase(),
                ),
              )
              .toList()
        : r;
    final total = (pageData?['total'] as num?)?.toInt() ?? visible.length;
    final size =
        (pageData?['pageSize'] as num?)?.toInt() ??
        (visible.isEmpty ? 1 : visible.length);
    final pageCount = total == 0 ? 1 : (total / size).ceil();
    return LaooListWorkspace(
      tokens: projectUiTokens,
      caption: caption(
        x: a['create'] == true
            ? FilledButton.icon(
                onPressed: () => cat ? category(null) : project(null),
                icon: const Icon(Icons.add),
                label: const Text('เพิ่ม'),
              )
            : null,
      ),
      filter: filter(),
      table: LayoutBuilder(
        builder: (_, b) => b.maxWidth < 900
            ? ListView.builder(
                itemCount: visible.length,
                itemBuilder: (_, i) => ListTile(
                  title: Text(
                    txt(visible[i][cat ? 'code' : 'code']) +
                        ' - ' +
                        txt(visible[i][cat ? 'name' : 'name']),
                  ),
                  subtitle: Text(
                    cat
                        ? (visible[i]['active'] == true
                              ? 'ใช้งาน'
                              : 'ปิดใช้งาน')
                        : 'ผู้จัดการ ' +
                              txt(visible[i]['manager']) +
                              ' • ' +
                              status(txt(visible[i]['status'])),
                  ),
                  trailing: actions(visible[i], a, cat),
                ),
              )
            : LaooWorkspaceDataTable(
                tokens: projectUiTokens,
                columns: [
                  const DataColumn(label: Text('ID')),
                  const DataColumn(label: Text('จัดการ')),
                  const DataColumn(label: Text('รหัส')),
                  DataColumn(label: Text(cat ? 'ชื่อหมวด' : 'ชื่อโครงการ')),
                  DataColumn(label: Text(cat ? 'ลำดับ' : 'ผู้จัดการ')),
                  const DataColumn(label: Text('สถานะ')),
                ],
                rows: List.generate(
                  visible.length,
                  (i) => DataRow(
                    cells: [
                      DataCell(Text((i + 1).toString())),
                      DataCell(actions(visible[i], a, cat)),
                      DataCell(Text(txt(visible[i]['code']))),
                      DataCell(Text(txt(visible[i]['name']))),
                      DataCell(
                        Text(txt(visible[i][cat ? 'sortOrder' : 'manager'])),
                      ),
                      DataCell(
                        Text(
                          cat
                              ? (visible[i]['active'] == true
                                    ? 'ใช้งาน'
                                    : 'ปิดใช้งาน')
                              : status(txt(visible[i]['status'])),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
      pagination: LaooPaginationCard(
        tokens: projectUiTokens,
        page: page,
        pageCount: pageCount,
        pageSize: size,
        total: total,
        onPrevious: !cat && page > 1
            ? () {
                page--;
                reload();
              }
            : null,
        onNext: !cat && page < pageCount
            ? () {
                page++;
                reload();
              }
            : null,
      ),
    );
  }

  Widget actions(Map<String, dynamic> r, Map<String, dynamic> a, bool cat) =>
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (a['edit'] == true && (cat || txt(r['status']) == 'DRAFT'))
            IconButton(
              tooltip: 'แก้ไข',
              onPressed: () => cat ? category(r) : project(r),
              icon: const Icon(Icons.edit_outlined),
            ),
          if (a['delete'] == true && (cat || txt(r['status']) == 'DRAFT'))
            IconButton(
              tooltip: 'ลบ',
              color: Colors.red,
              onPressed: () => del(
                cat
                    ? '/api/company/project-management/budget-categories/' +
                          txt(r['id'])
                    : '/api/company/project-management/projects/' +
                          txt(r['id']),
                txt(r['code']) + ' - ' + txt(r['name']),
              ),
              icon: const Icon(Icons.delete_outline),
            ),
          if (!cat && a['close'] == true && txt(r['status']) == 'ACTIVE')
            IconButton(
              tooltip: 'ปิดโครงการ',
              onPressed: () => closeProject(r),
              icon: const Icon(Icons.task_alt_outlined),
            ),
        ],
      );

  Future<void> closeProject(Map<String, dynamic> row) async {
    try {
      await api.post(
        '/api/company/project-management/projects/' + txt(row['id']) + '/close',
      );
      showProjectMessage(context, message: 'ปิดโครงการแล้ว');
      reload();
    } catch (e) {
      showProjectMessage(context, message: e.toString(), error: true);
    }
  }

  Future<void> category(Map<String, dynamic>? r) async {
    final c = TextEditingController(text: txt(r?['code'])),
        n = TextEditingController(text: txt(r?['name'])),
        o = TextEditingController(text: txt(r?['sortOrder'] ?? 10));
    await dialog(
      title + ' > ' + (r == null ? 'เพิ่ม' : 'แก้ไข'),
      Icons.category_outlined,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: c, decoration: inp('รหัส *')),
          const SizedBox(height: 16),
          TextField(controller: n, decoration: inp('ชื่อหมวด *')),
          const SizedBox(height: 16),
          TextField(controller: o, decoration: inp('ลำดับ')),
        ],
      ),
      () async {
        final b = {
          'code': c.text.trim(),
          'name': n.text.trim(),
          'sortOrder': int.tryParse(o.text) ?? 0,
          'remark': '',
          'isActive': true,
        };
        if (r == null)
          await api.post(
            '/api/company/project-management/budget-categories',
            body: b,
          );
        else
          await api.put(
            '/api/company/project-management/budget-categories/' + txt(r['id']),
            body: b,
          );
      },
    );
    c.dispose();
    n.dispose();
    o.dispose();
  }

  Future<void> project(Map<String, dynamic>? row) async {
    final options = map(
      await api.get('/api/company/project-management/options'),
    );
    Map<String, dynamic> detail = {};
    if (row != null) {
      detail = map(
        await api.get(
          '/api/company/project-management/projects/' + txt(row['id']),
        ),
      );
    }
    final key = GlobalKey<ProjectFormState>();
    await dialog(
      title + ' > ' + (row == null ? 'เพิ่ม' : 'แก้ไข'),
      Icons.account_tree_outlined,
      ProjectForm(key: key, options: options, detail: detail),
      () async {
        final body = key.currentState?.payload();
        if (body == null) throw Exception('กรุณากรอกข้อมูลโครงการให้ครบ');
        if (row == null) {
          await api.post(
            '/api/company/project-management/projects',
            body: body,
          );
        } else {
          await api.put(
            '/api/company/project-management/projects/' + txt(row['id']),
            body: body,
          );
        }
      },
    );
  }

  Widget tasks(List<Map<String, dynamic>> r, Map<String, dynamic> a) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      caption(),
      SizedBox(height: projectUiTokens.sectionSpacing),
      LaooSurfaceCard(tokens: projectUiTokens, child: filter()),
      SizedBox(height: projectUiTokens.sectionSpacing),
      Expanded(
        child: LaooSurfaceCard(
          tokens: projectUiTokens,
          child: r.isEmpty
              ? const Center(child: Text('ไม่พบงานที่ได้รับมอบหมาย'))
              : ListView.separated(
                  itemCount: r.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (_, i) => TaskRow(
                    api: api,
                    row: r[i],
                    edit: a['edit'] == true,
                    done: reload,
                  ),
                ),
        ),
      ),
    ],
  );
  Widget reports(Map<String, dynamic> d, Map<String, dynamic> options) {
    final s = map(d['summary']), late = rows(d['delayed']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        caption(),
        SizedBox(height: projectUiTokens.sectionSpacing),
        LaooSurfaceCard(
          tokens: projectUiTokens,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SizedBox(
                width: 120,
                child: DropdownButtonFormField<int?>(
                  initialValue: reportYear,
                  decoration: inp('ปี'),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('ทั้งหมด'),
                    ),
                    ...List.generate(6, (i) {
                      final y = DateTime.now().year - i;
                      return DropdownMenuItem<int?>(
                        value: y,
                        child: Text('$y'),
                      );
                    }),
                  ],
                  onChanged: (v) => setState(() => reportYear = v),
                ),
              ),
              SizedBox(
                width: 120,
                child: DropdownButtonFormField<int?>(
                  initialValue: reportMonth,
                  decoration: inp('เดือน'),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('ทั้งหมด'),
                    ),
                    ...List.generate(
                      12,
                      (i) => DropdownMenuItem<int?>(
                        value: i + 1,
                        child: Text('${i + 1}'),
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() => reportMonth = v),
                ),
              ),
              SizedBox(
                width: 170,
                child: DropdownButtonFormField<String?>(
                  initialValue: reportStatus,
                  decoration: inp('สถานะ'),
                  items: const [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text('ทั้งหมด'),
                    ),
                    DropdownMenuItem(value: 'DRAFT', child: Text('ร่าง')),
                    DropdownMenuItem(
                      value: 'ACTIVE',
                      child: Text('กำลังดำเนินการ'),
                    ),
                    DropdownMenuItem(
                      value: 'COMPLETED',
                      child: Text('เสร็จสิ้น'),
                    ),
                  ],
                  onChanged: (v) => setState(() => reportStatus = v),
                ),
              ),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<int?>(
                  initialValue: reportDepartmentId,
                  isExpanded: true,
                  decoration: inp('แผนก'),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('ทั้งหมด'),
                    ),
                    ...rows(options['departments']).map(
                      (x) => DropdownMenuItem<int?>(
                        value: (x['id'] as num).toInt(),
                        child: Text(
                          txt(x['name']),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() => reportDepartmentId = v),
                ),
              ),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<int?>(
                  initialValue: reportManagerId,
                  isExpanded: true,
                  decoration: inp('ผู้จัดการ'),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('ทั้งหมด'),
                    ),
                    ...rows(options['employees']).map(
                      (x) => DropdownMenuItem<int?>(
                        value: (x['id'] as num).toInt(),
                        child: Text(
                          txt(x['name']),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() => reportManagerId = v),
                ),
              ),
              FilledButton.icon(
                onPressed: reload,
                icon: const Icon(Icons.search),
                label: const Text('แสดงผล'),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    reportYear = null;
                    reportMonth = null;
                    reportStatus = null;
                    reportDepartmentId = null;
                    reportManagerId = null;
                  });
                  reload();
                },
                icon: const Icon(Icons.filter_alt_off_outlined),
                label: const Text('ล้าง Filter'),
              ),
            ],
          ),
        ),
        SizedBox(height: projectUiTokens.sectionSpacing),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    kpi('โครงการ', s['total']),
                    kpi('เสร็จ', s['completed']),
                    kpi('ล่าช้า', s['delayed']),
                    kpi('งบประมาณ', s['budget']),
                    kpi('ใช้จริง', s['actual']),
                    kpi('คงเหลือ', s['balance']),
                  ],
                ),
                const SizedBox(height: 6),
                LaooSurfaceCard(
                  tokens: projectUiTokens,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'โครงการล่าช้า',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (late.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('ไม่มีโครงการล่าช้า'),
                        ),
                      ...late.map(
                        (x) => ListTile(
                          title: Text(txt(x['code']) + ' - ' + txt(x['name'])),
                          trailing: Text(txt(x['progress']) + '%'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget kpi(String l, dynamic v) => SizedBox(
    width: 190,
    child: LaooSurfaceCard(
      tokens: projectUiTokens,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l),
          Text(txt(v ?? 0), style: Theme.of(context).textTheme.headlineSmall),
        ],
      ),
    ),
  );
  Future<void> dialog(
    String t,
    IconData icon,
    Widget body,
    Future<void> Function() save,
  ) async {
    await showDialog(
      context: context,
      builder: (dc) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480, maxHeight: 700),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    Icon(icon, color: projectUiTokens.primaryColor),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        t,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(color: projectUiTokens.borderColor),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(10),
                  child: body,
                ),
              ),
              Divider(color: projectUiTokens.borderColor),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(dc),
                        child: const Text('ยกเลิก'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 48,
                      child: FilledButton.icon(
                        onPressed: () async {
                          try {
                            await save();
                            if (dc.mounted) Navigator.pop(dc);
                            showProjectMessage(
                              context,
                              message: 'บันทึกข้อมูลแล้ว',
                            );
                            reload();
                          } catch (e) {
                            showProjectMessage(
                              context,
                              message: e.toString(),
                              error: true,
                            );
                          }
                        },
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('บันทึก'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> del(String path, String key) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dc) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: const BorderSide(color: Colors.red),
        ),
        title: const Text('ยืนยันการลบ', style: TextStyle(color: Colors.red)),
        content: Text(key + '\nข้อมูลที่ลบไม่สามารถเรียกคืนได้'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dc, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dc, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (ok == true)
      try {
        await api.delete(path);
        showProjectMessage(context, message: 'ลบข้อมูลแล้ว');
        reload();
      } catch (e) {
        showProjectMessage(context, message: e.toString(), error: true);
      }
  }
}

class ProjectForm extends StatefulWidget {
  const ProjectForm({required this.options, required this.detail, super.key});
  final Map<String, dynamic> options, detail;
  @override
  State<ProjectForm> createState() => ProjectFormState();
}

class ProjectFormState extends State<ProjectForm> {
  late final List<Map<String, dynamic>> employees;
  late final List<Map<String, dynamic>> departments;
  late final List<Map<String, dynamic>> categories;
  late final List<Map<String, dynamic>> members;
  late final List<Map<String, dynamic>> tasks;
  late final List<Map<String, dynamic>> budgets;
  late final TextEditingController code,
      name,
      start,
      end,
      budget,
      description,
      remark;
  int? managerId, departmentId;
  String statusCode = 'DRAFT';

  @override
  void initState() {
    super.initState();
    employees = _unique(rows(widget.options['employees']));
    departments = _unique(rows(widget.options['departments']));
    categories = _unique(rows(widget.options['categories']));
    final h = map(widget.detail['header']);
    code = TextEditingController(text: txt(h['code']));
    name = TextEditingController(text: txt(h['name']));
    final now = DateTime.now();
    start = TextEditingController(text: _date(h['startDate'], now));
    end = TextEditingController(
      text: _date(h['endDate'], now.add(const Duration(days: 30))),
    );
    budget = TextEditingController(text: txt(h['budget'] ?? 0));
    description = TextEditingController(text: txt(h['description']));
    remark = TextEditingController(text: txt(h['remark']));
    managerId = (h['managerId'] as num?)?.toInt();
    managerId ??= employees.isEmpty
        ? null
        : (employees.first['id'] as num).toInt();
    departmentId = (h['departmentId'] as num?)?.toInt();
    statusCode = txt(h['status']).isEmpty ? 'DRAFT' : txt(h['status']);
    members = rows(
      widget.detail['members'],
    ).map((e) => Map<String, dynamic>.from(e)).toList();
    tasks = rows(
      widget.detail['tasks'],
    ).map((e) => Map<String, dynamic>.from(e)).toList();
    budgets = rows(
      widget.detail['budgets'],
    ).map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static List<Map<String, dynamic>> _unique(List<Map<String, dynamic>> source) {
    final seen = <int>{};
    return source.where((e) {
      final id = (e['id'] as num?)?.toInt();
      return id != null && seen.add(id);
    }).toList();
  }

  static String _date(dynamic value, DateTime fallback) {
    final raw = txt(value);
    return raw.length >= 10
        ? raw.substring(0, 10)
        : fallback.toIso8601String().substring(0, 10);
  }

  @override
  void dispose() {
    for (final c in [code, name, start, end, budget, description, remark]) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic>? payload() {
    final s = DateTime.tryParse(start.text.trim());
    final e = DateTime.tryParse(end.text.trim());
    final amount = double.tryParse(budget.text.trim());
    if (name.text.trim().isEmpty ||
        managerId == null ||
        s == null ||
        e == null ||
        e.isBefore(s) ||
        amount == null ||
        amount < 0) {
      return null;
    }
    if (members.any((v) => (v['employeeId'] as num?) == null) ||
        tasks.any(
          (v) =>
              txt(v['name']).isEmpty ||
              (v['assigneeId'] as num?) == null ||
              DateTime.tryParse(txt(v['startDate'])) == null ||
              DateTime.tryParse(txt(v['dueDate'])) == null,
        ) ||
        budgets.any(
          (v) =>
              (v['categoryId'] as num?) == null ||
              (double.tryParse(txt(v['amount'])) ?? -1) < 0,
        )) {
      return null;
    }
    return {
      'code': code.text.trim(),
      'name': name.text.trim(),
      'managerId': managerId,
      'departmentId': departmentId,
      'startDate': s.toIso8601String(),
      'endDate': e.toIso8601String(),
      'budget': amount,
      'status': statusCode,
      'description': description.text.trim(),
      'remark': remark.text.trim(),
      'members': members,
      'tasks': tasks,
      'budgets': budgets
          .map((v) => {...v, 'amount': double.tryParse(txt(v['amount'])) ?? 0})
          .toList(),
    };
  }

  InputDecoration field(String label) => InputDecoration(
    labelText: label,
    border: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(4)),
    ),
  );

  Widget gap() => const SizedBox(height: 16);
  Widget section(String label, VoidCallback add) => Row(
    children: [
      Expanded(
        child: Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      OutlinedButton.icon(
        onPressed: add,
        icon: const Icon(Icons.add),
        label: const Text('เพิ่ม'),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      DropdownButtonFormField<String>(
        initialValue: statusCode,
        decoration: field('สถานะ *'),
        items: const [
          DropdownMenuItem(value: 'DRAFT', child: Text('ร่าง')),
          DropdownMenuItem(value: 'ACTIVE', child: Text('กำลังดำเนินการ')),
        ],
        onChanged: (v) => statusCode = v ?? 'DRAFT',
      ),
      gap(),
      TextField(
        controller: code,
        decoration: field('รหัสโครงการ (สร้างอัตโนมัติเมื่อเว้นว่าง)'),
      ),
      gap(),
      TextField(controller: name, decoration: field('ชื่อโครงการ *')),
      gap(),
      DropdownButtonFormField<int>(
        initialValue: managerId,
        isExpanded: true,
        decoration: field('ผู้จัดการ *'),
        items: employees
            .map(
              (e) => DropdownMenuItem(
                value: (e['id'] as num).toInt(),
                child: Text(txt(e['name']), overflow: TextOverflow.ellipsis),
              ),
            )
            .toList(),
        onChanged: (v) => managerId = v,
      ),
      gap(),
      DropdownButtonFormField<int?>(
        initialValue: departmentId,
        isExpanded: true,
        decoration: field('แผนก'),
        items: [
          const DropdownMenuItem<int?>(value: null, child: Text('ไม่กำหนด')),
          ...departments.map(
            (e) => DropdownMenuItem<int?>(
              value: (e['id'] as num).toInt(),
              child: Text(txt(e['name']), overflow: TextOverflow.ellipsis),
            ),
          ),
        ],
        onChanged: (v) => departmentId = v,
      ),
      gap(),
      TextField(
        controller: start,
        decoration: field('วันที่เริ่ม (YYYY-MM-DD) *'),
      ),
      gap(),
      TextField(
        controller: end,
        decoration: field('วันที่สิ้นสุด (YYYY-MM-DD) *'),
      ),
      gap(),
      TextField(
        controller: budget,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: field('วงเงินโครงการ *'),
      ),
      gap(),
      TextField(
        controller: description,
        maxLines: 3,
        decoration: field('รายละเอียด'),
      ),
      gap(),
      TextField(controller: remark, maxLines: 2, decoration: field('หมายเหตุ')),
      gap(),
      section(
        'ทีมโครงการ',
        () => setState(
          () => members.add({
            'employeeId': employees.isEmpty ? null : employees.first['id'],
            'role': 'สมาชิก',
            'joinDate': start.text,
          }),
        ),
      ),
      ...List.generate(members.length, (i) => _member(i)),
      gap(),
      section(
        'งานโครงการ',
        () => setState(
          () => tasks.add({
            'name': '',
            'assigneeId': employees.isEmpty ? null : employees.first['id'],
            'startDate': start.text,
            'dueDate': end.text,
            'plannedHours': 0,
            'weight': 0,
          }),
        ),
      ),
      ...List.generate(tasks.length, (i) => _task(i)),
      gap(),
      section(
        'แผนงบประมาณ',
        () => setState(
          () => budgets.add({
            'categoryId': categories.isEmpty ? null : categories.first['id'],
            'description': '',
            'amount': 0,
          }),
        ),
      ),
      ...List.generate(budgets.length, (i) => _budget(i)),
    ],
  );

  Widget box(int i, List<Map<String, dynamic>> list, List<Widget> children) =>
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'รายการ ${i + 1}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    IconButton(
                      color: Colors.red,
                      tooltip: 'ลบ',
                      onPressed: () => setState(() => list.removeAt(i)),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
                ...children,
              ],
            ),
          ),
        ),
      );

  Widget _member(int i) {
    final v = members[i];
    return box(i, members, [
      DropdownButtonFormField<int>(
        initialValue: (v['employeeId'] as num?)?.toInt(),
        isExpanded: true,
        decoration: field('พนักงาน *'),
        items: employees
            .map(
              (e) => DropdownMenuItem(
                value: (e['id'] as num).toInt(),
                child: Text(txt(e['name']), overflow: TextOverflow.ellipsis),
              ),
            )
            .toList(),
        onChanged: (x) => v['employeeId'] = x,
      ),
      gap(),
      TextFormField(
        initialValue: txt(v['role']),
        decoration: field('บทบาท *'),
        onChanged: (x) => v['role'] = x,
      ),
    ]);
  }

  Widget _task(int i) {
    final v = tasks[i];
    return box(i, tasks, [
      TextFormField(
        initialValue: txt(v['name']),
        decoration: field('ชื่องาน *'),
        onChanged: (x) => v['name'] = x,
      ),
      gap(),
      DropdownButtonFormField<int>(
        initialValue: (v['assigneeId'] as num?)?.toInt(),
        isExpanded: true,
        decoration: field('ผู้รับผิดชอบ *'),
        items: employees
            .map(
              (e) => DropdownMenuItem(
                value: (e['id'] as num).toInt(),
                child: Text(txt(e['name']), overflow: TextOverflow.ellipsis),
              ),
            )
            .toList(),
        onChanged: (x) => v['assigneeId'] = x,
      ),
      gap(),
      TextFormField(
        initialValue: _date(v['startDate'], DateTime.now()),
        decoration: field('วันที่เริ่ม *'),
        onChanged: (x) => v['startDate'] = x,
      ),
      gap(),
      TextFormField(
        initialValue: _date(v['dueDate'], DateTime.now()),
        decoration: field('วันครบกำหนด *'),
        onChanged: (x) => v['dueDate'] = x,
      ),
      gap(),
      TextFormField(
        initialValue: txt(v['plannedHours'] ?? 0),
        keyboardType: TextInputType.number,
        decoration: field('ชั่วโมงแผน'),
        onChanged: (x) => v['plannedHours'] = double.tryParse(x) ?? 0,
      ),
      gap(),
      TextFormField(
        initialValue: txt(v['weight'] ?? 0),
        keyboardType: TextInputType.number,
        decoration: field('น้ำหนักงาน (%)'),
        onChanged: (x) => v['weight'] = double.tryParse(x) ?? 0,
      ),
    ]);
  }

  Widget _budget(int i) {
    final v = budgets[i];
    return box(i, budgets, [
      DropdownButtonFormField<int>(
        initialValue: (v['categoryId'] as num?)?.toInt(),
        isExpanded: true,
        decoration: field('หมวดงบประมาณ *'),
        items: categories
            .map(
              (e) => DropdownMenuItem(
                value: (e['id'] as num).toInt(),
                child: Text(txt(e['name']), overflow: TextOverflow.ellipsis),
              ),
            )
            .toList(),
        onChanged: (x) => v['categoryId'] = x,
      ),
      gap(),
      TextFormField(
        initialValue: txt(v['description']),
        decoration: field('รายละเอียด'),
        onChanged: (x) => v['description'] = x,
      ),
      gap(),
      TextFormField(
        initialValue: txt(v['amount'] ?? 0),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: field('จำนวนเงิน *'),
        onChanged: (x) => v['amount'] = x,
      ),
    ]);
  }
}

class Settings extends StatefulWidget {
  const Settings({
    required this.api,
    required this.title,
    required this.data,
    required this.edit,
    required this.done,
    super.key,
  });
  final JsonApiClient api;
  final String title;
  final Map<String, dynamic> data;
  final bool edit;
  final VoidCallback done;
  @override
  State<Settings> createState() => _SS();
}

class _SS extends State<Settings> {
  late bool enabled, over, budget, tasks;
  late final TextEditingController format, days;
  @override
  void initState() {
    super.initState();
    enabled = widget.data['isEnabled'] != false;
    over = widget.data['allowOverBudget'] == true;
    budget = widget.data['requireBudgetBeforeStart'] != false;
    tasks = widget.data['requireTasksCompleteBeforeClose'] != false;
    format = TextEditingController(text: txt(widget.data['projectNoFormat']));
    days = TextEditingController(text: txt(widget.data['dueWarningDays']));
  }

  @override
  Widget build(BuildContext c) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      LaooCaptionCard(
        tokens: projectUiTokens,
        leading: Icon(
          Icons.settings_outlined,
          color: projectUiTokens.primaryColor,
        ),
        caption: widget.title,
      ),
      SizedBox(height: projectUiTokens.sectionSpacing),
      Expanded(
        child: LaooSurfaceCard(
          tokens: projectUiTokens,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ค่าการทำงานปัจจุบัน',
                  style: Theme.of(c).textTheme.titleMedium,
                ),
                const Divider(),
                sw(
                  'เปิดใช้งานระบบ',
                  enabled,
                  (v) => setState(() => enabled = v),
                ),
                TextField(
                  controller: format,
                  enabled: widget.edit,
                  decoration: inp('รูปแบบเลขที่'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: days,
                  enabled: widget.edit,
                  decoration: inp('เตือนก่อนครบกำหนด (วัน)'),
                ),
                sw('อนุญาตเกินงบ', over, (v) => setState(() => over = v)),
                sw(
                  'ต้องมีงบก่อนเริ่ม',
                  budget,
                  (v) => setState(() => budget = v),
                ),
                sw('งานครบก่อนปิด', tasks, (v) => setState(() => tasks = v)),
                if (widget.edit)
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: save,
                      icon: const Icon(Icons.save),
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
  Widget sw(String l, bool v, ValueChanged<bool> f) => Row(
    children: [
      Text(l),
      Switch(value: v, onChanged: widget.edit ? f : null),
    ],
  );
  Future<void> save() async {
    try {
      await widget.api.put(
        '/api/company/project-management/settings',
        body: {
          'isEnabled': enabled,
          'projectNoFormat': format.text,
          'dueWarningDays': int.tryParse(days.text) ?? 7,
          'allowOverBudget': over,
          'requireBudgetBeforeStart': budget,
          'requireTasksCompleteBeforeClose': tasks,
        },
      );
      showProjectMessage(context, message: 'บันทึกแล้ว');
      widget.done();
    } catch (e) {
      showProjectMessage(context, message: e.toString(), error: true);
    }
  }
}

class TaskRow extends StatefulWidget {
  const TaskRow({
    required this.api,
    required this.row,
    required this.edit,
    required this.done,
    super.key,
  });
  final JsonApiClient api;
  final Map<String, dynamic> row;
  final bool edit;
  final VoidCallback done;
  @override
  State<TaskRow> createState() => _T();
}

class _T extends State<TaskRow> {
  late String state;
  late final TextEditingController p, h, n;
  @override
  void initState() {
    super.initState();
    state = txt(widget.row['status']);
    p = TextEditingController(text: txt(widget.row['progress']));
    h = TextEditingController(text: txt(widget.row['actualHours']));
    n = TextEditingController(text: txt(widget.row['note']));
  }

  @override
  Widget build(BuildContext c) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        txt(widget.row['projectCode']) + ' • ' + txt(widget.row['projectName']),
      ),
      Text(txt(widget.row['name']), style: Theme.of(c).textTheme.titleMedium),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          SizedBox(
            width: 180,
            child: DropdownButtonFormField<String>(
              initialValue: state,
              decoration: inp('สถานะ'),
              items: const [
                DropdownMenuItem(
                  value: 'NOT_STARTED',
                  child: Text('ยังไม่เริ่ม'),
                ),
                DropdownMenuItem(value: 'IN_PROGRESS', child: Text('กำลังทำ')),
                DropdownMenuItem(value: 'BLOCKED', child: Text('ติดปัญหา')),
                DropdownMenuItem(value: 'COMPLETED', child: Text('เสร็จ')),
              ],
              onChanged: widget.edit ? (v) => setState(() => state = v!) : null,
            ),
          ),
          SizedBox(
            width: 120,
            child: TextField(controller: p, decoration: inp('ความคืบหน้า %')),
          ),
          SizedBox(
            width: 120,
            child: TextField(controller: h, decoration: inp('ชั่วโมงจริง')),
          ),
          SizedBox(
            width: 240,
            child: TextField(controller: n, decoration: inp('หมายเหตุ')),
          ),
          if (widget.edit)
            FilledButton(onPressed: save, child: const Text('บันทึก')),
        ],
      ),
    ],
  );
  Future<void> save() async {
    try {
      await widget.api.put(
        '/api/company/project-management/my-tasks/' + txt(widget.row['id']),
        body: {
          'status': state,
          'progress': double.tryParse(p.text) ?? 0,
          'actualHours': double.tryParse(h.text) ?? 0,
          'note': n.text,
        },
      );
      showProjectMessage(context, message: 'อัปเดตงานแล้ว');
      widget.done();
    } catch (e) {
      showProjectMessage(context, message: e.toString(), error: true);
    }
  }
}

InputDecoration inp(String l, [IconData? i]) => InputDecoration(
  labelText: l,
  prefixIcon: i == null ? null : Icon(i),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(4),
    borderSide: BorderSide(color: projectUiTokens.borderColor),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(4),
    borderSide: BorderSide(color: projectUiTokens.borderColor),
  ),
);
Map<String, dynamic> map(dynamic v) => v is Map<String, dynamic>
    ? v
    : v is Map
    ? Map<String, dynamic>.from(v)
    : {};
List<Map<String, dynamic>> rows(dynamic v) =>
    v is List ? v.map(map).toList() : [];
String txt(dynamic v) => v == null ? '' : v.toString();
String status(String s) => switch (s) {
  'DRAFT' => 'ร่าง',
  'ACTIVE' => 'ดำเนินการ',
  'COMPLETED' => 'เสร็จสิ้น',
  'CANCELLED' => 'ยกเลิก',
  _ => s,
};
