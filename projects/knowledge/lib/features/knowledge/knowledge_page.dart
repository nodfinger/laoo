// ignore_for_file: curly_braces_in_flow_control_structures, unnecessary_underscores

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';
import 'knowledge_feature_host.dart';
import 'knowledge_video_preview.dart';
import 'knowledge_video_embed.dart';

class _ReviewCancelled implements Exception {}

class KnowledgePage extends StatefulWidget {
  const KnowledgePage({
    super.key,
    required this.menuCode,
    required this.fallbackTitle,
  });
  final String menuCode;
  final String fallbackTitle;
  @override
  State<KnowledgePage> createState() => _KnowledgePageState();
}

class _KnowledgePageState extends State<KnowledgePage> {
  late final JsonApiClient api = createKnowledgeApi();
  String title = '';
  bool loading = true;
  Object? error;
  Map<String, dynamic> actions = {};
  Map<String, dynamic> options = {};
  dynamic data;
  final search = TextEditingController();
  final _settingsVideo = TextEditingController();
  final _settingsFile = TextEditingController();
  final _settingsReview = TextEditingController();
  final _settingsPolicies = <String, bool>{};
  final _settingsReviewerScopes = <String, String>{};
  final _settingsReviewers = <String, Set<int>>{};
  bool _savingSettings = false;
  String _filterQuery = '';
  String _aiFilter = 'all';
  int? _categoryFilter;
  int? _libraryDepartmentFilter;
  String? _contentTypeFilter;
  String? _statusFilter;
  String? _reviewStatusFilter = 'IN_REVIEW';
  String? _reviewTypeFilter;
  int page = 1;
  bool cards = false;
  String _yearFormat = 'AD';

  @override
  void initState() {
    super.initState();
    title = widget.fallbackTitle;
    knowledgeTitle(widget.menuCode, title).then((v) {
      if (mounted) setState(() => title = v);
    });
    load();
    _loadYearFormat();
  }

  Future<void> _loadYearFormat() async {
    try {
      final setup = _map(await api.get('/api/system/company-setup/runtime'));
      if (mounted)
        setState(() => _yearFormat = '${setup['yearFormat'] ?? 'AD'}');
    } catch (_) {
      // Keep the default when company settings are unavailable.
    }
  }

  String _reviewDate(dynamic value) {
    if (value == null) return '-';
    final parsed = DateTime.tryParse(value.toString());
    if (parsed == null) return '-';
    final utc = parsed.isUtc
        ? parsed
        : DateTime.utc(
            parsed.year,
            parsed.month,
            parsed.day,
            parsed.hour,
            parsed.minute,
            parsed.second,
          );
    final date = utc.toLocal();
    final year = _yearFormat.toUpperCase() == 'BE'
        ? date.year + 543
        : date.year;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/$year ${two(date.hour)}:${two(date.minute)}';
  }

  @override
  void dispose() {
    search.dispose();
    _settingsVideo.dispose();
    _settingsFile.dispose();
    _settingsReview.dispose();
    disposeKnowledgeApi(api);
    super.dispose();
  }

  String get endpoint => switch (widget.menuCode) {
    '49001' => 'settings',
    '49002' => 'taxonomy',
    '49003' =>
      'articles?search=${Uri.encodeQueryComponent(search.text)}&page=$page&pageSize=20${_aiFilter == 'all' ? '' : '&includeInAi=$_aiFilter'}${_categoryFilter == null ? '' : '&categoryId=$_categoryFilter'}${_contentTypeFilter == null ? '' : '&contentType=${Uri.encodeQueryComponent(_contentTypeFilter!)}'}${_statusFilter == null ? '' : '&status=${Uri.encodeQueryComponent(_statusFilter!)}'}',
    '49004' => 'reviews',
    '49005' =>
      'library?search=${Uri.encodeQueryComponent(search.text)}&page=$page&pageSize=20${_contentTypeFilter == null ? '' : '&contentType=${Uri.encodeQueryComponent(_contentTypeFilter!)}'}${_libraryDepartmentFilter == null ? '' : '&departmentId=$_libraryDepartmentFilter'}',
    '49006' => 'questions',
    '49007' => 'mine',
    _ => 'reports',
  };

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await Future.wait([
        api.get('/api/company/knowledge/actions/${widget.menuCode}'),
        api.get('/api/company/knowledge/$endpoint'),
        api.get('/api/company/knowledge/options'),
      ]);
      if (mounted)
        setState(() {
          actions = _map(result[0]);
          data = result[1];
          options = _map(result[2]);
          if (widget.menuCode == '49001') {
            final settings = _map(data);
            _settingsVideo.text = _text(settings['maxVideoMb']);
            _settingsFile.text = _text(settings['maxAttachmentMb']);
            _settingsReview.text = _text(settings['defaultReviewMonths']);
            _settingsPolicies
              ..clear()
              ..addEntries(
                _rows(settings['reviewPolicies']).map(
                  (p) => MapEntry(
                    p['contentType'].toString(),
                    p['requireReview'] == true,
                  ),
                ),
              );
            _settingsReviewerScopes
              ..clear()
              ..addEntries(
                _rows(settings['reviewPolicies']).map(
                  (p) => MapEntry(
                    p['contentType'].toString(),
                    p['reviewerScope']?.toString() ?? 'ANY',
                  ),
                ),
              );
            _settingsReviewers
              ..clear()
              ..addEntries(
                _rows(settings['reviewPolicies']).map(
                  (p) => MapEntry(
                    p['contentType'].toString(),
                    ((p['reviewerUserIds'] as List?) ?? [])
                        .map((v) => (v as num).toInt())
                        .toSet(),
                  ),
                ),
              );
          }
          loading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          error = e;
          loading = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) => knowledgeShell(
    title: title,
    menu: title,
    child: Padding(
      padding: knowledgeTokens.contentMargin,
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) => LaooCaptionCard(
              tokens: knowledgeTokens,
              caption: title,
              leading: Icon(
                Icons.auto_stories_outlined,
                color: knowledgeTokens.primaryColor,
              ),
              favoriteKey: widget.menuCode,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_supportsListCard &&
                      constraints.maxWidth >= knowledgeTokens.compactBreakpoint)
                    LaooListCardToggle(
                      tokens: knowledgeTokens,
                      cards: cards,
                      onChanged: (value) => setState(() => cards = value),
                    ),
                  if (_topAction() case final action?) ...[
                    SizedBox(width: knowledgeTokens.itemSpacing),
                    action,
                  ],
                ],
              ),
            ),
          ),
          SizedBox(height: knowledgeTokens.sectionSpacing),
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

  bool get _supportsListCard =>
      const {'49002', '49003', '49005'}.contains(widget.menuCode);

  Widget? _topAction() {
    if (widget.menuCode == '49001' && actions['edit'] == true && !loading)
      return SizedBox(
        height: knowledgeTokens.buttonHeight,
        child: FilledButton.icon(
          onPressed: _savingSettings ? null : _saveSettings,
          icon: const Icon(Icons.save_outlined),
          label: Text(_savingSettings ? 'กำลังบันทึก' : 'บันทึก'),
        ),
      );
    if (widget.menuCode == '49003' && actions['create'] == true)
      return _button('เสนอความรู้', Icons.add, () => _articleDialog());
    if (widget.menuCode == '49002' && actions['create'] == true)
      return _button('เพิ่มหมวด', Icons.add, () => _taxonomyDialog());
    if (widget.menuCode == '49006' && actions['create'] == true)
      return _button('ตั้งคำถาม', Icons.add, () => _questionDialog());
    return null;
  }

  Widget _content() => switch (widget.menuCode) {
    '49001' => _settings(),
    '49002' => _taxonomy(),
    '49003' => _articles(false),
    '49004' => _reviews(),
    '49005' => _articles(true),
    '49006' => _questions(),
    '49007' => _mine(),
    _ => _reports(),
  };

  Widget _error() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, size: 42),
        const SizedBox(height: 8),
        const Text('โหลดข้อมูลไม่สำเร็จ'),
        const SizedBox(height: 8),
        _button('ลองอีกครั้ง', Icons.replay, load),
      ],
    ),
  );
  Widget _button(String text, IconData icon, VoidCallback tap) => SizedBox(
    height: knowledgeTokens.buttonHeight,
    child: FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: knowledgeTokens.primaryColor,
        foregroundColor: Colors.white,
        textStyle: knowledgeTokens.buttonStyle,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      onPressed: tap,
      icon: Icon(icon),
      label: Text(text),
    ),
  );
  Map<String, dynamic> _map(dynamic v) =>
      v is Map<String, dynamic> ? v : Map<String, dynamic>.from(v as Map);
  List<Map<String, dynamic>> _rows(dynamic v) =>
      v is List ? v.map((x) => _map(x)).toList() : <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _items(dynamic v, [String key = 'items']) =>
      v is Map ? _rows(_map(v)[key]) : _rows(v);
  String _text(dynamic v) => v?.toString() ?? '-';
  Future<Set<int>?> _choosePolicyReviewers(Set<int> initial) async {
    final selected = Set<int>.of(initial);
    final reviewers = _rows(options['reviewEmployees']);
    final departments = _rows(options['departments']);
    int? departmentId = departments.isEmpty
        ? null
        : (departments.first['id'] as num).toInt();
    String query = '';
    bool selectedOnly = false;
    return showDialog<Set<int>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, update) {
          final matches = reviewers
              .where(
                (r) =>
                    (selectedOnly
                        ? selected.contains((r['id'] as num?)?.toInt())
                        : departmentId == null ||
                              (r['departmentId'] as num?)?.toInt() ==
                                  departmentId) &&
                    '${_text(r['name'])} ${_text(r['nickname'])} ${_text(r['code'])}'
                        .toLowerCase()
                        .contains(query.toLowerCase()),
              )
              .toList();
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('เลือกผู้ตรวจทาน', style: knowledgeTokens.captionStyle),
                const SizedBox(height: 12),
                const Divider(height: 1),
              ],
            ),
            content: SizedBox(
              width: 600,
              height: 400,
              child: Column(
                children: [
                  DropdownButtonFormField<int?>(
                    isExpanded: true,
                    initialValue: departmentId,
                    decoration: _comboInput('แผนก'),
                    style: knowledgeTokens.tableStyle,
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('ทุกแผนก'),
                      ),
                      ...departments.map(
                        (d) => DropdownMenuItem<int?>(
                          value: (d['id'] as num).toInt(),
                          child: Text(
                            _text(d['name']),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) => update(() => departmentId = value),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: _comboInput('ค้นหาชื่อ ชื่อเล่น หรือรหัส'),
                    onChanged: (v) => update(() => query = v.trim()),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () =>
                          update(() => selectedOnly = !selectedOnly),
                      icon: Icon(
                        selectedOnly
                            ? Icons.check_box
                            : Icons.check_box_outline_blank,
                      ),
                      label: Text('แสดงเฉพาะที่เลือก (${selected.length} คน)'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: matches.isEmpty
                        ? const Center(child: Text('ไม่พบพนักงาน'))
                        : ListView.separated(
                            itemCount: matches.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (_, i) {
                              final row = matches[i];
                              final id = (row['id'] as num?)?.toInt();
                              final department = departments.where(
                                (d) => d['id'] == row['departmentId'],
                              );
                              return CheckboxListTile(
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${_text(row['name'])}${(row['nickname']?.toString().trim().isNotEmpty ?? false) ? ' (${row['nickname']})' : ''}',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Flexible(
                                      child: Text(
                                        department.isEmpty
                                            ? 'ไม่ระบุแผนก'
                                            : _text(department.first['name']),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (id == null)
                                      const Text(' · ไม่มีบัญชีเข้าใช้งาน'),
                                  ],
                                ),
                                value: id != null && selected.contains(id),
                                onChanged: id == null
                                    ? null
                                    : (v) => update(() {
                                        if (v == true) {
                                          selected.add(id);
                                        } else {
                                          selected.remove(id);
                                        }
                                      }),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('ยกเลิก'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, selected),
                child: const Text('ตกลง'),
              ),
            ],
          );
        },
      ),
    );
  }

  String _contentTypeName(dynamic value) => switch (_text(value)) {
    'AI_TEXT' => 'ข้อความทั่วไป',
    'PDF_FILE' => 'แนบไฟล์ PDF',
    'AI_IMAGES' => 'รูปภาพสำหรับ AI',
    'ARTICLE' => 'บทความเดิม',
    'VIDEO_FILE' => 'คลิป MP4',
    'VIDEO_URL' => 'ลิงก์วิดีโอ',
    'DOCUMENT_CONTROL' => 'Document Control',
    'TRAINING' => 'Training',
    'INTRANET' => 'Intranet',
    'EXTERNAL_URL' => 'ลิงก์ภายนอก',
    _ => _text(value),
  };

  Widget _settings() {
    const types = <String, String>{
      'AI_TEXT': 'ข้อความทั่วไป',
      'PDF_FILE': 'แนบไฟล์ PDF',
      'AI_IMAGES': 'รูปภาพสำหรับ AI',
      'ARTICLE': 'บทความเดิม',
      'VIDEO_FILE': 'คลิป MP4',
      'VIDEO_URL': 'ลิงก์วิดีโอ',
      'DOCUMENT_CONTROL': 'Document Control',
      'TRAINING': 'Training',
      'INTRANET': 'Intranet',
      'EXTERNAL_URL': 'ลิงก์ภายนอก',
    };
    for (final type in types.keys) {
      _settingsPolicies.putIfAbsent(type, () => true);
      _settingsReviewerScopes.putIfAbsent(type, () => 'ANY');
      _settingsReviewers.putIfAbsent(type, () => <int>{});
    }
    return _card(
      StatefulBuilder(
        builder: (context, setSettings) => ListView(
          children: [
            const Text(
              'ค่าการทำงานปัจจุบัน',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const Divider(),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final fields = [
                  _field(_settingsVideo, 'ขนาดคลิป MP4 สูงสุด (MB)'),
                  _field(_settingsFile, 'ขนาดไฟล์แนบสูงสุด (MB)'),
                  _field(_settingsReview, 'รอบทบทวนเริ่มต้น (เดือน)'),
                ];
                if (constraints.maxWidth < 650) {
                  return Column(
                    children: [
                      fields[0],
                      const SizedBox(height: 16),
                      fields[1],
                      const SizedBox(height: 16),
                      fields[2],
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: fields[0]),
                    const SizedBox(width: 16),
                    Expanded(child: fields[1]),
                    const SizedBox(width: 16),
                    Expanded(child: fields[2]),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            const Text(
              'ขั้นตอนเผยแพร่ตามประเภทเนื้อหา',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'รายการที่ส่งให้ AI ต้องผ่านการตรวจทานเสมอ ส่วนประเภทที่เผยแพร่ได้ทันทีใช้สิทธิ์เพิ่มหรือแก้ไข',
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 900
                    ? 3
                    : constraints.maxWidth >= 600
                    ? 2
                    : 1;
                const gap = 12.0;
                final itemWidth =
                    (constraints.maxWidth - gap * (columns - 1)) / columns;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final entry in types.entries)
                      SizedBox(
                        width: itemWidth,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(
                              color: Theme.of(context).dividerColor,
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SwitchListTile.adaptive(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                title: Wrap(
                                  spacing: 8,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(entry.value),
                                    Text(
                                      _settingsPolicies[entry.key]!
                                          ? 'ต้องส่งตรวจทาน'
                                          : 'เผยแพร่ได้ทันที',
                                      style: knowledgeTokens.tableStyle
                                          .copyWith(color: Colors.blueGrey),
                                    ),
                                  ],
                                ),
                                value: _settingsPolicies[entry.key]!,
                                onChanged: actions['edit'] == true
                                    ? (value) => setSettings(
                                        () => _settingsPolicies[entry.key] =
                                            value,
                                      )
                                    : null,
                              ),
                              DropdownButtonFormField<String>(
                                isExpanded: true,
                                initialValue:
                                    _settingsReviewerScopes[entry.key],
                                style: knowledgeTokens.tableStyle,
                                decoration: _comboInput('ขอบเขตผู้ตรวจทาน'),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'DEPARTMENT',
                                    child: Text(
                                      'แผนกเดียวกับผู้จัดทำ',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 'DIVISION',
                                    child: Text(
                                      'ฝ่ายเดียวกับผู้จัดทำ',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 'ANY',
                                    child: Text(
                                      'อิสระตามสิทธิ์ที่กำหนด',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                                onChanged: actions['edit'] == true
                                    ? (value) => setSettings(
                                        () =>
                                            _settingsReviewerScopes[entry.key] =
                                                value!,
                                      )
                                    : null,
                              ),
                              if (_settingsReviewerScopes[entry.key] == 'ANY')
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton.icon(
                                    onPressed: actions['edit'] == true
                                        ? () async {
                                            final selected =
                                                await _choosePolicyReviewers(
                                                  _settingsReviewers[entry
                                                      .key]!,
                                                );
                                            if (selected != null)
                                              setSettings(
                                                () =>
                                                    _settingsReviewers[entry
                                                            .key] =
                                                        selected,
                                              );
                                          }
                                        : null,
                                    icon: const Icon(Icons.search),
                                    label: Text(
                                      'เลือกผู้ตรวจทาน (${_settingsReviewers[entry.key]!.length} คน)',
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveSettings() async {
    setState(() => _savingSettings = true);
    try {
      await api.put(
        '/api/company/knowledge/settings',
        body: {
          'maxVideoMb': int.tryParse(_settingsVideo.text),
          'maxAttachmentMb': int.tryParse(_settingsFile.text),
          'defaultReviewMonths': int.tryParse(_settingsReview.text),
          'reviewPolicies': [
            for (final entry in _settingsPolicies.entries)
              {
                'contentType': entry.key,
                'requireReview': entry.value,
                'reviewerScope': _settingsReviewerScopes[entry.key],
                'reviewerUserIds': _settingsReviewers[entry.key]!.toList(),
              },
          ],
        },
      );
      if (mounted) {
        await load();
        if (mounted) knowledgeMessage(context, 'บันทึกการตั้งค่าเรียบร้อยแล้ว');
      }
    } catch (error) {
      if (mounted)
        knowledgeMessage(
          context,
          'บันทึกการตั้งค่าไม่สำเร็จ: $error',
          error: true,
        );
    } finally {
      if (mounted) setState(() => _savingSettings = false);
    }
  }

  Widget _taxonomy() => _list(
    _rows(data),
    (r) => [
      _text(r['code']),
      _text(r['name']),
      _text(r['ownerName']),
      r['active'] == true ? 'ใช้งาน' : 'ปิด',
    ],
    const ['รหัส', 'หมวดความรู้', 'เจ้าของหมวด', 'สถานะ'],
    rowActions: (row) => [
      if (actions['edit'] == true)
        IconButton(
          tooltip: 'แก้ไข',
          color: knowledgeTokens.primaryColor,
          onPressed: () => _taxonomyDialog(row),
          icon: const Icon(Icons.edit_outlined),
        ),
      if (actions['delete'] == true)
        IconButton(
          tooltip: 'ลบ',
          color: Theme.of(context).colorScheme.error,
          onPressed: () => _deleteTaxonomy(row),
          icon: const Icon(Icons.delete_outline),
        ),
    ],
  );

  Widget _list(
    List<Map<String, dynamic>> rows,
    List<String> Function(Map<String, dynamic>) values,
    List<String> headers, {
    List<Widget> Function(Map<String, dynamic>)? rowActions,
  }) {
    final filtered = rows
        .where(
          (row) => values(
            row,
          ).join(' ').toLowerCase().contains(_filterQuery.toLowerCase()),
        )
        .toList();
    const pageSize = 20;
    final pages = filtered.isEmpty ? 1 : (filtered.length / pageSize).ceil();
    final current = page.clamp(1, pages);
    final offset = (current - 1) * pageSize;
    final pageRows = filtered.skip(offset).take(pageSize).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LaooFilterCard(
          tokens: knowledgeTokens,
          child: Wrap(
            alignment: WrapAlignment.start,
            runAlignment: WrapAlignment.start,
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 280,
                child: TextField(
                  controller: search,
                  style: knowledgeTokens.inputStyle,
                  decoration: _input(
                    'ค้นหา',
                  ).copyWith(prefixIcon: const Icon(Icons.search)),
                  onSubmitted: (value) => setState(() {
                    _filterQuery = value.trim();
                    page = 1;
                  }),
                ),
              ),
              _button(
                'ค้นหา',
                Icons.search,
                () => setState(() {
                  _filterQuery = search.text.trim();
                  page = 1;
                }),
              ),
              SizedBox(
                height: knowledgeTokens.buttonHeight,
                child: OutlinedButton.icon(
                  onPressed: () => setState(() {
                    search.clear();
                    _filterQuery = '';
                    page = 1;
                  }),
                  icon: const Icon(Icons.filter_alt_off_outlined),
                  label: const Text('ล้าง Filter'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: knowledgeTokens.primaryColor,
                    textStyle: knowledgeTokens.buttonStyle,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        knowledgeTokens.radius,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: knowledgeTokens.sectionSpacing),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (pageRows.isEmpty) {
                return LaooTableCard(
                  tokens: knowledgeTokens,
                  child: const Center(child: Text('ไม่พบข้อมูล')),
                );
              }
              if (cards ||
                  constraints.maxWidth < knowledgeTokens.compactBreakpoint) {
                return ListView.separated(
                  itemCount: pageRows.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, index) {
                    final row = pageRows[index];
                    final rowValues = values(row);
                    return LaooSurfaceCard(
                      tokens: knowledgeTokens,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'ID ${offset + index + 1}',
                                  style: knowledgeTokens.tableStyle.copyWith(
                                    color: knowledgeTokens.primaryColor,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                for (var i = 0; i < headers.length; i++)
                                  if (headers[i] == 'สถานะ')
                                    _statusBadge(rowValues[i])
                                  else
                                    Text('${headers[i]}: ${rowValues[i]}'),
                              ],
                            ),
                          ),
                          if (rowActions != null)
                            Wrap(spacing: 2, children: rowActions(row)),
                        ],
                      ),
                    );
                  },
                );
              }
              return LaooTableCard(
                tokens: knowledgeTokens,
                child: Padding(
                  padding: knowledgeTokens.cardPadding,
                  child: LaooWorkspaceDataTable(
                    tokens: knowledgeTokens,
                    columns: [
                      LaooWorkspaceTableColumns.id,
                      const DataColumn(
                        label: Text('Action'),
                        columnWidth: FixedColumnWidth(100),
                      ),
                      ...headers.map(
                        (header) => DataColumn(label: Text(header)),
                      ),
                    ],
                    rows: List<DataRow>.generate(pageRows.length, (index) {
                      final row = pageRows[index];
                      return DataRow(
                        cells: [
                          DataCell(Text('${offset + index + 1}')),
                          DataCell(
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Wrap(
                                spacing: 2,
                                children: rowActions?.call(row) ?? const [],
                              ),
                            ),
                          ),
                          for (var i = 0; i < headers.length; i++)
                            DataCell(
                              headers[i] == 'สถานะ'
                                  ? _statusBadge(values(row)[i])
                                  : Text(values(row)[i]),
                            ),
                        ],
                      );
                    }),
                  ),
                ),
              );
            },
          ),
        ),
        SizedBox(height: knowledgeTokens.sectionSpacing),
        LaooPaginationCard(
          borderless: true,
          tokens: knowledgeTokens,
          page: current,
          pageCount: pages,
          pageSize: pageSize,
          total: filtered.length,
          onPrevious: current > 1
              ? () => setState(() => page = current - 1)
              : null,
          onNext: current < pages
              ? () => setState(() => page = current + 1)
              : null,
        ),
      ],
    );
  }

  Widget _articles(bool library) {
    final rows = _items(data);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LaooFilterCard(
          tokens: knowledgeTokens,
          child: Wrap(
            alignment: WrapAlignment.start,
            runAlignment: WrapAlignment.start,
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 280,
                child: TextField(
                  controller: search,
                  style: knowledgeTokens.inputStyle,
                  onSubmitted: (_) {
                    setState(() => page = 1);
                    load();
                  },
                  decoration: _input(
                    'ค้นหาชื่อ เนื้อหา หรือ Tag',
                  ).copyWith(prefixIcon: const Icon(Icons.search)),
                ),
              ),
              if (!library)
                SizedBox(
                  width: 210,
                  child: DropdownButtonFormField<int?>(
                    key: ValueKey(_categoryFilter),
                    isExpanded: true,
                    initialValue: _categoryFilter,
                    style: knowledgeTokens.tableStyle,
                    decoration: _comboInput('หมวด'),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('ทั้งหมด'),
                      ),
                      ..._rows(options['categories']).map(
                        (row) => DropdownMenuItem<int?>(
                          value: (row['id'] as num).toInt(),
                          child: Text(
                            _text(row['name']),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _categoryFilter = value;
                        page = 1;
                      });
                      load();
                    },
                  ),
                ),
              SizedBox(
                width: 210,
                child: DropdownButtonFormField<String?>(
                  key: ValueKey(_contentTypeFilter),
                  isExpanded: true,
                  initialValue: _contentTypeFilter,
                  style: knowledgeTokens.tableStyle,
                  decoration: _comboInput('ประเภท'),
                  items: const [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text('ทั้งหมด'),
                    ),
                    DropdownMenuItem(
                      value: 'AI_TEXT',
                      child: Text('ข้อความทั่วไป'),
                    ),
                    DropdownMenuItem(
                      value: 'PDF_FILE',
                      child: Text('แนบไฟล์ PDF'),
                    ),
                    DropdownMenuItem(
                      value: 'AI_IMAGES',
                      child: Text('รูปภาพสำหรับ AI'),
                    ),
                    DropdownMenuItem(
                      value: 'ARTICLE',
                      child: Text('บทความเดิม'),
                    ),
                    DropdownMenuItem(
                      value: 'VIDEO_FILE',
                      child: Text('คลิป MP4'),
                    ),
                    DropdownMenuItem(
                      value: 'VIDEO_URL',
                      child: Text('ลิงก์วิดีโอ'),
                    ),
                    DropdownMenuItem(
                      value: 'DOCUMENT_CONTROL',
                      child: Text('Document Control'),
                    ),
                    DropdownMenuItem(
                      value: 'TRAINING',
                      child: Text('Training'),
                    ),
                    DropdownMenuItem(
                      value: 'INTRANET',
                      child: Text('Intranet'),
                    ),
                    DropdownMenuItem(
                      value: 'EXTERNAL_URL',
                      child: Text('ลิงก์ภายนอก'),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _contentTypeFilter = value;
                      page = 1;
                    });
                    load();
                  },
                ),
              ),
              if (!library)
                SizedBox(
                  width: 210,
                  child: DropdownButtonFormField<String?>(
                    key: ValueKey(_statusFilter),
                    isExpanded: true,
                    initialValue: _statusFilter,
                    style: knowledgeTokens.tableStyle,
                    decoration: _comboInput('สถานะ'),
                    items: const [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text('ทั้งหมด'),
                      ),
                      DropdownMenuItem(value: 'DRAFT', child: Text('แบบร่าง')),
                      DropdownMenuItem(
                        value: 'IN_REVIEW',
                        child: Text('รอตรวจทาน'),
                      ),
                      DropdownMenuItem(
                        value: 'RETURNED',
                        child: Text('ส่งกลับแก้ไข'),
                      ),
                      DropdownMenuItem(
                        value: 'PUBLISHED',
                        child: Text('เผยแพร่แล้ว'),
                      ),
                      DropdownMenuItem(
                        value: 'REVIEW_DUE',
                        child: Text('ครบกำหนดทบทวน'),
                      ),
                      DropdownMenuItem(
                        value: 'ARCHIVED',
                        child: Text('เก็บถาวร'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _statusFilter = value;
                        page = 1;
                      });
                      load();
                    },
                  ),
                ),
              if (library)
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<int?>(
                    key: ValueKey(_libraryDepartmentFilter),
                    initialValue: _libraryDepartmentFilter,
                    isExpanded: true,
                    style: knowledgeTokens.tableStyle,
                    decoration: _comboInput('แผนกที่รับผิดชอบ'),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('ทั้งหมด'),
                      ),
                      ..._rows(options['departments']).map(
                        (d) => DropdownMenuItem<int?>(
                          value: (d['id'] as num).toInt(),
                          child: Text(
                            _text(d['name']),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _libraryDepartmentFilter = value;
                        page = 1;
                      });
                      load();
                    },
                  ),
                ),
              if (!library)
                SizedBox(
                  width: 240,
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    key: ValueKey(_aiFilter),
                    initialValue: _aiFilter,
                    style: knowledgeTokens.tableStyle,
                    decoration: _comboInput('AI'),
                    items: const [
                      DropdownMenuItem(value: 'all', child: Text('ทั้งหมด')),
                      DropdownMenuItem(value: 'true', child: Text('ส่งให้ AI')),
                      DropdownMenuItem(
                        value: 'false',
                        child: Text('ไม่ส่งให้ AI'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _aiFilter = value ?? 'all';
                        page = 1;
                      });
                      load();
                    },
                  ),
                ),
              _button('ค้นหา', Icons.search, () {
                setState(() => page = 1);
                load();
              }),
              SizedBox(
                height: knowledgeTokens.buttonHeight,
                child: OutlinedButton.icon(
                  onPressed: () {
                    search.clear();
                    setState(() {
                      page = 1;
                      _aiFilter = 'all';
                      _categoryFilter = null;
                      _contentTypeFilter = null;
                      _libraryDepartmentFilter = null;
                      _statusFilter = null;
                    });
                    load();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: knowledgeTokens.primaryColor,
                    textStyle: knowledgeTokens.buttonStyle,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        knowledgeTokens.radius,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.filter_alt_off_outlined),
                  label: const Text('ล้าง Filter'),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: knowledgeTokens.sectionSpacing),
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) =>
                cards || c.maxWidth < knowledgeTokens.compactBreakpoint
                ? ListView.separated(
                    itemCount: rows.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _articleCard(rows[i], library),
                  )
                : _articleTable(rows, library),
          ),
        ),
        SizedBox(height: knowledgeTokens.sectionSpacing),
        _pagination(),
      ],
    );
  }

  Widget _pagination() {
    final value = _map(data);
    final total = (value['total'] as num?)?.toInt() ?? _items(data).length;
    final pageSize = (value['pageSize'] as num?)?.toInt() ?? 20;
    final pages = total == 0 ? 1 : (total / pageSize).ceil();
    return LaooPaginationCard(
      borderless: true,
      tokens: knowledgeTokens,
      page: page,
      pageCount: pages,
      pageSize: pageSize,
      total: total,
      onPrevious: page <= 1
          ? null
          : () {
              setState(() => page--);
              load();
            },
      onNext: page >= pages
          ? null
          : () {
              setState(() => page++);
              load();
            },
    );
  }

  Widget _articleCard(Map<String, dynamic> r, bool library) => _card(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              _sourceIcon(_text(r['contentType'])),
              color: knowledgeTokens.primaryColor,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _text(r['title']),
                style: knowledgeTokens.sectionStyle.copyWith(
                  color: knowledgeTokens.primaryColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(_text(r['summary']), maxLines: 3, overflow: TextOverflow.ellipsis),
        Text('ประเภท: ${_contentTypeName(r['contentType'])}'),
        if (library) ...[
          Text('แผนกที่รับผิดชอบ: ${_text(r['departmentName'])}'),
          Text('เผยแพร่: ${_reviewDate(r['publishedAt'])}'),
          Text('จำนวนการดู: ${_text(r['viewCount'])}'),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              onPressed: () => _openLibrarySource(r),
              child: const Text('แสดง'),
            ),
          ),
        ],
        if (!library) ...[
          const SizedBox(height: 8),
          Text('ผู้ตรวจทาน: ${_text(r['reviewerName'])}'),
          Text('วันที่ตรวจทาน: ${_reviewDate(r['reviewedAt'])}'),
        ],
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              _text(r['categoryName']),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (!library) _statusBadge(r['status']),
          ],
        ),
        if (!library)
          Wrap(
            spacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text('AI:', style: knowledgeTokens.tableStyle),
              _aiIndicator(r['includeInAi'] == true),
            ],
          ),
        const SizedBox(height: 8),
        if (!library)
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(spacing: 4, children: _articleActions(r, library)),
          ),
      ],
    ),
  );

  Widget _articleTable(
    List<Map<String, dynamic>> rows,
    bool library,
  ) => LaooTableCard(
    tokens: knowledgeTokens,
    child: Padding(
      padding: knowledgeTokens.cardPadding,
      child: LaooWorkspaceDataTable(
        tokens: knowledgeTokens,
        columns: [
          LaooWorkspaceTableColumns.id,
          if (!library)
            const DataColumn(
              label: Text('Action'),
              columnWidth: FixedColumnWidth(264),
            ),
          DataColumn(label: Text('ชื่อองค์ความรู้')),
          DataColumn(label: Text('ประเภท')),
          if (!library) const DataColumn(label: Text('AI')),
          if (!library) const DataColumn(label: Text('สถานะ')),
          if (library) const DataColumn(label: Text('แผนกที่รับผิดชอบ')),
          if (library) const DataColumn(label: Text('แหล่งความรู้')),
          if (library) const DataColumn(label: Text('วันที่และเวลาเผยแพร่')),
          if (library) const DataColumn(label: Text('จำนวนการดู')),
          if (!library) const DataColumn(label: Text('ผู้ตรวจทาน')),
          if (!library) const DataColumn(label: Text('วันที่และเวลาตรวจทาน')),
        ],
        rows: List<DataRow>.generate(rows.length, (index) {
          final row = rows[index];
          return DataRow(
            cells: [
              DataCell(Text('${(page - 1) * 20 + index + 1}')),
              if (!library)
                DataCell(
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: _articleActions(row, library),
                    ),
                  ),
                ),
              DataCell(
                SizedBox(
                  width: 280,
                  child: Text(
                    _text(row['title']),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              DataCell(Text(_contentTypeName(row['contentType']))),
              if (!library)
                DataCell(
                  _aiIndicator(row['includeInAi'] == true, compact: true),
                ),
              if (!library) DataCell(_statusBadge(row['status'])),
              if (library) DataCell(Text(_text(row['departmentName']))),
              if (library)
                DataCell(
                  OutlinedButton(
                    onPressed: () => _openLibrarySource(row),
                    child: const Text('แสดง'),
                  ),
                ),
              if (library) DataCell(Text(_reviewDate(row['publishedAt']))),
              if (library) DataCell(Text(_text(row['viewCount']))),
              if (!library) DataCell(Text(_text(row['reviewerName']))),
              if (!library) DataCell(Text(_reviewDate(row['reviewedAt']))),
            ],
          );
        }),
      ),
    ),
  );
  List<Widget> _articleActions(Map<String, dynamic> row, bool library) {
    final id = (row['id'] as num).toInt();
    final status = _text(row['status']);
    final editable =
        status == 'DRAFT' || status == 'RETURNED' || status == 'IN_REVIEW';
    return [
      IconButton(
        tooltip: 'เปิดดู',
        color: knowledgeTokens.primaryColor,
        onPressed: () => _articleView(row),
        icon: const Icon(Icons.visibility_outlined),
      ),
      if (!library && editable && actions['edit'] == true)
        IconButton(
          tooltip: 'แก้ไข',
          color: knowledgeTokens.primaryColor,
          onPressed: () => _articleDialog(row),
          icon: const Icon(Icons.edit_outlined),
        ),
      if (!library &&
          (status == 'DRAFT' || status == 'RETURNED') &&
          actions['submit'] == true)
        IconButton(
          tooltip: 'ส่งตรวจทาน',
          color: knowledgeTokens.primaryColor,
          onPressed: () async {
            Map<String, dynamic> article;
            try {
              article = _map(
                await api.get('/api/company/knowledge/articles/$id'),
              );
            } catch (error) {
              if (mounted)
                knowledgeMessage(
                  context,
                  'โหลดข้อมูลผู้ตรวจทานไม่สำเร็จ: $error',
                  error: true,
                );
              return;
            }
            if (!mounted) return;
            final policy = _rows(options['reviewPolicies']).firstWhere(
              (p) => p['contentType'] == article['contentType'],
              orElse: () => <String, dynamic>{},
            );
            final scope = policy['reviewerScope']?.toString() ?? 'ANY';
            final reviewerId = (article['reviewerUserId'] as num?)?.toInt();
            final configuredIds = ((policy['reviewerUserIds'] as List?) ?? [])
                .whereType<num>()
                .map((value) => value.toInt())
                .toSet();
            final users = _rows(options['users']);
            final reviewer = users
                .where((u) => (u['id'] as num?)?.toInt() == reviewerId)
                .toList();
            if (scope == 'ANY' &&
                (reviewerId == null ||
                    !configuredIds.contains(reviewerId) ||
                    reviewer.isEmpty)) {
              knowledgeMessage(
                context,
                'ยังไม่ได้กำหนดผู้ตรวจทาน กรุณาแก้ไขรายการและเลือกผู้ตรวจทานก่อนส่ง',
                error: true,
              );
              return;
            }
            final recipient = scope == 'ANY'
                ? _text(reviewer.first['name'])
                : scope == 'DEPARTMENT'
                ? 'ผู้ตรวจทานตามแผนกของผู้จัดทำ'
                : 'ผู้ตรวจทานตามฝ่ายของผู้จัดทำ';
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: const Text('ยืนยันการส่งตรวจทาน'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(),
                    const SizedBox(height: 12),
                    Text('ต้องการส่ง “${_text(row['title'])}” ตรวจทานหรือไม่'),
                    const SizedBox(height: 8),
                    Text('ส่งให้ตรวจทาน: $recipient'),
                    const SizedBox(height: 12),
                    const Divider(),
                  ],
                ),
                actions: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('ยกเลิก'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: const Text('ส่งตรวจทาน'),
                  ),
                ],
              ),
            );
            if (confirmed != true || !mounted) return;
            try {
              await api.post('/api/company/knowledge/articles/$id/submit');
              await load();
              if (mounted) knowledgeMessage(context, 'ส่งตรวจทานแล้ว');
            } catch (error) {
              if (mounted)
                knowledgeMessage(
                  context,
                  'ส่งตรวจทานไม่สำเร็จ: $error',
                  error: true,
                );
            }
          },
          icon: const Icon(Icons.send_outlined),
        ),
      if (!library && row['canCancelReview'] == true && actions['edit'] == true)
        IconButton(
          tooltip: 'ยกเลิกส่งตรวจทาน',
          color: knowledgeTokens.primaryColor,
          icon: const Icon(Icons.undo_outlined),
          onPressed: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: const Text('ยืนยันการยกเลิกส่งตรวจทาน'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(),
                    const SizedBox(height: 12),
                    Text(
                      'ต้องการยกเลิกส่งตรวจทาน “${_text(row['title'])}” หรือไม่ รายการจะกลับเป็นแบบร่าง',
                    ),
                    const SizedBox(height: 12),
                    const Divider(),
                  ],
                ),
                actions: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('ปิด'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: const Text('ยืนยัน'),
                  ),
                ],
              ),
            );
            if (confirmed != true || !mounted) return;
            try {
              await api.post(
                '/api/company/knowledge/articles/$id/cancel-review',
              );
              await load();
              if (mounted) knowledgeMessage(context, 'ยกเลิกส่งตรวจทานแล้ว');
            } catch (error) {
              if (mounted)
                knowledgeMessage(
                  context,
                  'ยกเลิกส่งตรวจทานไม่สำเร็จ: $error',
                  error: true,
                );
            }
          },
        ),
      if (!library &&
          (status == 'PUBLISHED' || status == 'REVIEW_DUE') &&
          actions['edit'] == true)
        IconButton(
          tooltip: 'สร้าง Revision ใหม่',
          color: knowledgeTokens.primaryColor,
          onPressed: () async {
            await api.post('/api/company/knowledge/articles/$id/revisions');
            if (mounted) {
              knowledgeMessage(context, 'สร้าง Revision ใหม่เป็นร่างแล้ว');
            }
            load();
          },
          icon: const Icon(Icons.content_copy_outlined),
        ),
      if (!library &&
          status == 'DRAFT' &&
          row['publishedRevisionId'] == null &&
          actions['delete'] == true)
        IconButton(
          tooltip: 'ลบ',
          color: Theme.of(context).colorScheme.error,
          onPressed: () => _deleteArticle(row),
          icon: const Icon(Icons.delete_outline),
        ),
    ];
  }

  Widget _reviews() {
    final rows = _rows(data);
    final types =
        rows
            .map((r) => _text(r['contentType']))
            .where((t) => t != '-')
            .toSet()
            .toList()
          ..sort();
    final filtered = rows
        .where(
          (r) =>
              (_reviewStatusFilter == null ||
                  r['status'] == _reviewStatusFilter) &&
              (_reviewTypeFilter == null ||
                  r['contentType'] == _reviewTypeFilter),
        )
        .toList();
    return Column(
      children: [
        _card(
          SizedBox(
            width: double.infinity,
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Wrap(
                alignment: WrapAlignment.start,
                spacing: 12,
                runSpacing: 8,
                children: [
                  SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<String?>(
                      initialValue: _reviewStatusFilter,
                      isExpanded: true,
                      style: knowledgeTokens.tableStyle,
                      decoration: _comboInput('สถานะ'),
                      items: const [
                        DropdownMenuItem(value: null, child: Text('ทั้งหมด')),
                        DropdownMenuItem(
                          value: 'IN_REVIEW',
                          child: Text('รอตรวจทาน'),
                        ),
                        DropdownMenuItem(
                          value: 'PUBLISHED',
                          child: Text('เผยแพร่แล้ว'),
                        ),
                        DropdownMenuItem(
                          value: 'RETURNED',
                          child: Text('ส่งกลับแก้ไข'),
                        ),
                        DropdownMenuItem(
                          value: 'REVIEW_DUE',
                          child: Text('ครบกำหนดทบทวน'),
                        ),
                      ],
                      onChanged: (value) => setState(() {
                        _reviewStatusFilter = value;
                        page = 1;
                      }),
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<String?>(
                      initialValue: types.contains(_reviewTypeFilter)
                          ? _reviewTypeFilter
                          : null,
                      isExpanded: true,
                      style: knowledgeTokens.tableStyle,
                      decoration: _comboInput('ประเภท'),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('ทั้งหมด'),
                        ),
                        ...types.map(
                          (t) => DropdownMenuItem(
                            value: t,
                            child: Text(_contentTypeName(t)),
                          ),
                        ),
                      ],
                      onChanged: (value) => setState(() {
                        _reviewTypeFilter = value;
                        page = 1;
                      }),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(height: knowledgeTokens.sectionSpacing),
        Expanded(child: _simple(filtered, 'งานตรวจทาน', review: true)),
      ],
    );
  }

  Widget _questions() => _pagedItems(_rows(data), (row) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.question_answer_outlined),
      title: Text(_text(row['title'])),
      subtitle: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(_text(row['categoryName'])),
          _statusBadge(row['status']),
          Text('${_text(row['answerCount'])} คำตอบ'),
        ],
      ),
      trailing: Wrap(
        spacing: 2,
        children: [
          IconButton(
            tooltip: 'เปิดดู',
            color: knowledgeTokens.primaryColor,
            onPressed: () => _questionDetail((row['id'] as num).toInt()),
            icon: const Icon(Icons.visibility_outlined),
          ),
          if (row['canEdit'] == true && actions['edit'] == true)
            IconButton(
              tooltip: 'แก้ไข',
              color: knowledgeTokens.primaryColor,
              onPressed: () async {
                final detail = _map(
                  await api.get(
                    '/api/company/knowledge/questions/${(row['id'] as num).toInt()}',
                  ),
                );
                if (mounted) {
                  _questionDialog(_map(detail['question']));
                }
              },
              icon: const Icon(Icons.edit_outlined),
            ),
          if (row['canDelete'] == true && actions['delete'] == true)
            IconButton(
              tooltip: 'ลบ',
              color: Theme.of(context).colorScheme.error,
              onPressed: () => _deleteQuestion(row),
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      onTap: () => _questionDetail((row['id'] as num).toInt()),
    );
  });
  Widget _mine() {
    final value = _map(data);
    return ListView(
      children: [
        _section('งานเขียนของฉัน', _rows(value['authored'])),
        const SizedBox(height: 8),
        _section('รายการที่ติดตาม', _rows(value['followed'])),
      ],
    );
  }

  Widget _section(String title, List<Map<String, dynamic>> rows) => _card(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const Divider(),
        if (rows.isEmpty) const Text('ยังไม่มีข้อมูล'),
        for (final row in rows)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(_text(row['title'])),
            subtitle: Align(
              alignment: Alignment.centerLeft,
              child: _statusBadge(row['status']),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _view(row),
          ),
      ],
    ),
  );
  Widget _reports() {
    final value = _map(data), summary = _map(value['totals']);
    final categories = _rows(value['byCategory']);
    final feedback = _map(value['feedback']);
    return ListView(
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _metric('เผยแพร่', summary['published'], Icons.public),
            _metric(
              'รอตรวจทาน',
              summary['inReview'],
              Icons.fact_check_outlined,
            ),
            _metric('ต้องทบทวน', summary['reviewDue'], Icons.event_repeat),
            _metric(
              'คำถามเปิด',
              summary['total'],
              Icons.question_answer_outlined,
            ),
          ],
        ),
        const SizedBox(height: 8),
        _card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'องค์ความรู้ตามหมวด',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              for (final row in categories)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(child: Text(_text(row['name']))),
                      Text(
                        _text(row['value']),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _metric('มีประโยชน์', feedback['helpful'], Icons.thumb_up_outlined),
            _metric(
              'ควรปรับปรุง',
              feedback['unhelpful'],
              Icons.thumb_down_outlined,
            ),
          ],
        ),
      ],
    );
  }

  Widget _simple(
    List<Map<String, dynamic>> rows,
    String heading, {
    bool review = false,
  }) => _pagedItems(rows, (r) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: review
          ? IconButton(
              tooltip: 'เปิดดู',
              color: knowledgeTokens.primaryColor,
              onPressed: () => _reviewDetail(r),
              icon: const Icon(Icons.visibility_outlined),
            )
          : const Icon(Icons.auto_stories_outlined),
      title: Text(_text(r['title'] ?? r['question'])),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _statusBadge(r['status']),
              if (review) ...[
                Text('ประเภท: ${_contentTypeName(r['contentType'])}'),
                const Text('AI:'),
                _aiIndicator(r['includeInAi'] == true),
              ],
            ],
          ),
          if (review)
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                Text('ผู้ทวนสอบ: ${_text(r['reviewerName'])}'),
                Text(
                  'เผยแพร่: ${_reviewDate(r['status'] == 'PUBLISHED' || r['status'] == 'REVIEW_DUE' ? r['publishedAt'] : null)}',
                ),
              ],
            ),
        ],
      ),
      trailing: review
          ? null
          : IconButton(
              color: knowledgeTokens.primaryColor,
              onPressed: () => _view(r),
              icon: const Icon(Icons.chevron_right),
            ),
    );
  }, dividerAfterLast: review);

  Widget _pagedItems(
    List<Map<String, dynamic>> rows,
    Widget Function(Map<String, dynamic>) itemBuilder, {
    bool dividerAfterLast = false,
  }) {
    const pageSize = 20;
    final totalPages = ((rows.length + pageSize - 1) ~/ pageSize).clamp(
      1,
      1 << 30,
    );
    final currentPage = page.clamp(1, totalPages);
    final visible = rows
        .skip((currentPage - 1) * pageSize)
        .take(pageSize)
        .toList();
    return Column(
      children: [
        Expanded(
          child: LaooSurfaceCard(
            tokens: knowledgeTokens,
            padding: knowledgeTokens.cardPadding,
            child: ListView.separated(
              itemCount: visible.length,
              separatorBuilder: (_, __) =>
                  Divider(color: knowledgeTokens.borderColor, thickness: .6),
              itemBuilder: (_, index) =>
                  dividerAfterLast && index == visible.length - 1
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        itemBuilder(visible[index]),
                        Divider(
                          color: knowledgeTokens.borderColor,
                          thickness: .6,
                        ),
                      ],
                    )
                  : itemBuilder(visible[index]),
            ),
          ),
        ),
        const SizedBox(height: 8),
        LaooPaginationCard(
          borderless: true,
          tokens: knowledgeTokens,
          page: currentPage,
          pageCount: totalPages,
          total: rows.length,
          pageSize: pageSize,
          onPrevious: currentPage > 1
              ? () => setState(() => page = currentPage - 1)
              : null,
          onNext: currentPage < totalPages
              ? () => setState(() => page = currentPage + 1)
              : null,
        ),
      ],
    );
  }

  Future<void> _publish(int id, String articleTitle) async {
    if (!await _confirmReviewAction('เผยแพร่', articleTitle)) return;
    try {
      await api.post(
        '/api/company/knowledge/reviews/$id/publish',
        body: {'note': 'ตรวจทานและเผยแพร่จากหน้าจอ'},
      );
      await load();
      if (mounted) knowledgeMessage(context, 'เผยแพร่องค์ความรู้แล้ว');
    } catch (error) {
      if (mounted)
        knowledgeMessage(context, 'เผยแพร่ไม่สำเร็จ: $error', error: true);
    }
  }

  Future<void> _returnDialog(int id, String articleTitle) async {
    final note = TextEditingController();
    await _popup(
      '$title > ส่งกลับ',
      Icons.undo_outlined,
      TextField(
        controller: note,
        style: knowledgeTokens.inputStyle,
        maxLines: 4,
        decoration: _input('เหตุผลที่ส่งกลับ *'),
      ),
      () async {
        if (note.text.trim().isEmpty) {
          throw StateError('กรุณาระบุเหตุผลที่ส่งกลับ');
        }
        if (!await _confirmReviewAction('ส่งกลับ', articleTitle))
          throw _ReviewCancelled();
        await api.post(
          '/api/company/knowledge/reviews/$id/return',
          body: {'note': note.text},
        );
        if (mounted) knowledgeMessage(context, 'ส่งกลับให้เจ้าของแก้ไขแล้ว');
        load();
      },
    );
  }

  Future<bool> _confirmReviewAction(String action, String articleTitle) async =>
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('ยืนยันการ$action'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Divider(),
              const SizedBox(height: 12),
              Text('ต้องการ$actionองค์ความรู้นี้หรือไม่'),
              const SizedBox(height: 8),
              Text(articleTitle),
              const SizedBox(height: 12),
              const Divider(),
            ],
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('ยืนยัน'),
            ),
          ],
        ),
      ) ??
      false;

  Widget _metric(String label, dynamic value, IconData icon) => SizedBox(
    width: 220,
    child: _card(
      Row(
        children: [
          Icon(icon, size: 30, color: knowledgeTokens.primaryColor),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _text(value),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(label),
            ],
          ),
        ],
      ),
    ),
  );
  IconData _sourceIcon(String type) => type.contains('VIDEO')
      ? Icons.play_circle_outline
      : type.contains('DOCUMENT')
      ? Icons.description_outlined
      : Icons.article_outlined;
  Widget _aiIndicator(bool enabled, {bool compact = false}) {
    final label = enabled
        ? (compact ? 'ใช่' : 'ส่งให้ AI')
        : (compact ? 'ไม่' : 'ไม่ส่งให้ AI');
    if (!enabled) return Text(label, style: knowledgeTokens.tableStyle);
    final color = knowledgeTokens.primaryColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: knowledgeTokens.tableStyle.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _statusBadge(dynamic value) {
    final code = value?.toString().trim().toUpperCase() ?? '';
    final label = switch (code) {
      'DRAFT' => 'แบบร่าง',
      'IN_REVIEW' => 'รอตรวจทาน',
      'RETURNED' => 'ส่งกลับแก้ไข',
      'PUBLISHED' => 'เผยแพร่แล้ว',
      'REVIEW_DUE' => 'ครบกำหนดทบทวน',
      'ARCHIVED' => 'เก็บถาวร',
      'OPEN' => 'รอคำตอบ',
      'ANSWERED' => 'มีคำตอบแล้ว',
      'RESOLVED' => 'ยอมรับคำตอบแล้ว',
      'ใช้งาน' => 'ใช้งาน',
      'ปิด' || 'ปิดใช้งาน' => 'ปิดใช้งาน',
      _ => 'ไม่ระบุสถานะ',
    };
    final scheme = Theme.of(context).colorScheme;
    final color = switch (code) {
      'PUBLISHED' || 'RESOLVED' || 'ใช้งาน' => knowledgeTokens.primaryColor,
      'RETURNED' || 'ปิด' || 'ปิดใช้งาน' => scheme.error,
      'IN_REVIEW' => scheme.secondary,
      'OPEN' => scheme.onSecondaryContainer,
      'REVIEW_DUE' => scheme.tertiary,
      'ANSWERED' => scheme.onTertiaryContainer,
      'ARCHIVED' => scheme.outline,
      _ => scheme.onSurfaceVariant,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: code == 'RESOLVED' ? .22 : .12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: knowledgeTokens.tableStyle.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _card(Widget child) => LaooSurfaceCard(
    tokens: knowledgeTokens,
    padding: knowledgeTokens.cardPadding,
    child: child,
  );
  InputDecoration _input(String label) => InputDecoration(
    labelText: label,
    labelStyle: knowledgeTokens.inputStyle.copyWith(height: 1.4),
    floatingLabelStyle: knowledgeTokens.inputStyle.copyWith(
      fontSize: (knowledgeTokens.tableStyle.fontSize ?? 14) / .75,
      height: 1.4,
      color: knowledgeTokens.primaryColor,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(knowledgeTokens.radius),
      borderSide: BorderSide(color: knowledgeTokens.primaryColor, width: 2),
    ),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(4),
      borderSide: BorderSide(color: knowledgeTokens.borderColor),
    ),
  );
  InputDecoration _comboInput(String label) => _input(
    label,
  ).copyWith(labelStyle: knowledgeTokens.tableStyle.copyWith(height: 1.4));

  Widget _field(TextEditingController c, String label) => TextField(
    controller: c,
    style: knowledgeTokens.inputStyle,
    decoration: _input(label),
  );
  Future<void> _deleteArticle(Map<String, dynamic> row) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        icon: Icon(
          Icons.delete_outline,
          color: Theme.of(context).colorScheme.error,
        ),
        title: Text(
          'ยืนยันการลบ',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              color: Theme.of(context).colorScheme.errorContainer,
              child: Text(_text(row['title'])),
            ),
            const SizedBox(height: 12),
            const Text('ข้อมูลที่ลบแล้วไม่สามารถเรียกคืนได้'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
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
    await api.delete(
      '/api/company/knowledge/articles/${(row['id'] as num).toInt()}',
    );
    if (mounted) knowledgeMessage(context, 'ลบองค์ความรู้แล้ว');
    load();
  }

  Future<void> _articleDialog([Map<String, dynamic>? row]) async {
    final existing = row == null
        ? <String, dynamic>{}
        : _map(
            await api.get(
              '/api/company/knowledge/articles/${(row['id'] as num).toInt()}',
            ),
          );
    final titleC = TextEditingController(text: existing['title']?.toString()),
        summary = TextEditingController(text: existing['summary']?.toString()),
        body = TextEditingController(text: existing['bodyText']?.toString()),
        url = TextEditingController(text: existing['sourceUrl']?.toString());
    final categories = _rows(options['categories']);
    if (categories.isEmpty) {
      if (!mounted) return;
      knowledgeMessage(context, 'กรุณาเพิ่มหมวดความรู้ก่อน', error: true);
      return;
    }
    int categoryId = existing['categoryId'] == null
        ? (categories.first['id'] as num).toInt()
        : (existing['categoryId'] as num).toInt();
    String type = existing['contentType']?.toString() ?? 'AI_TEXT';
    bool includeInAi = existing['includeInAi'] == true;
    final directPolicies = _rows(options['reviewPolicies']);
    final configuredReviewerNames = {
      for (final person in _rows(options['users']))
        (person['id'] as num).toInt(): _text(person['name']),
    };
    Map<String, dynamic> policy() => directPolicies.firstWhere(
      (p) => p['contentType'] == type,
      orElse: () => <String, dynamic>{},
    );
    String reviewerScope() => policy()['reviewerScope']?.toString() ?? 'ANY';
    int? selectedReviewerId = (existing['reviewerUserId'] as num?)?.toInt();
    bool needsReview() => includeInAi || policy()['requireReview'] != false;
    bool allowDirect() =>
        (row == null ? actions['create'] == true : actions['edit'] == true) &&
        !includeInAi &&
        directPolicies.any(
          (p) => p['contentType'] == type && p['requireReview'] == false,
        );
    final directEnabled = ValueNotifier<bool>(allowDirect());
    var publishing = false;
    int? savedArticleId = (row?['id'] as num?)?.toInt();
    final existingFiles = _rows(existing['files']);
    final existingVideos =
        existingFiles
            .where((f) => _text(f['fileName']).toLowerCase().endsWith('.mp4'))
            .toList()
          ..sort((a, b) => (a['id'] as num).compareTo(b['id'] as num));
    final existingVideo = existingVideos.isEmpty ? null : existingVideos.last;
    String audienceMode = existing['audienceMode']?.toString() ?? 'ALL';
    final departments = _rows(options['departments']);
    int? responsibleDepartmentId = (existing['responsibleDepartmentId'] as num?)
        ?.toInt();
    Future<int?> chooseResponsibleDepartment() async {
      String query = '';
      return showDialog<int>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, update) {
            final matches = departments
                .where(
                  (d) => '${_text(d['name'])} ${_text(d['code'])}'
                      .toLowerCase()
                      .contains(query.toLowerCase()),
                )
                .toList();
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'เลือกแผนกที่รับผิดชอบ',
                    style: knowledgeTokens.captionStyle,
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                ],
              ),
              content: SizedBox(
                width: 600,
                height: 400,
                child: Column(
                  children: [
                    TextField(
                      decoration: _comboInput('ค้นหาชื่อหรือรหัสแผนก'),
                      onChanged: (v) => update(() => query = v.trim()),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: matches.isEmpty
                          ? const Center(child: Text('ไม่พบแผนก'))
                          : ListView.separated(
                              itemCount: matches.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (_, i) => ListTile(
                                title: Text(_text(matches[i]['name'])),
                                onTap: () => Navigator.pop(
                                  dialogContext,
                                  (matches[i]['id'] as num).toInt(),
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('ปิด'),
                ),
              ],
            );
          },
        ),
      );
    }

    final users = _rows(options['users']);
    final existingDepartments = existing['departmentIds'] is List
        ? existing['departmentIds'] as List
        : const [];
    final existingUsers = existing['userIds'] is List
        ? existing['userIds'] as List
        : const [];
    int? departmentId = existingDepartments.isEmpty
        ? null
        : (existingDepartments.first as num).toInt();
    int? audienceUserId = existingUsers.isEmpty
        ? null
        : (existingUsers.first as num).toInt();
    PlatformFile? selectedFile;
    final imageFiles = <PlatformFile>[];
    final savedImageIds = <PlatformFile, int>{};
    var savedImagesLoaded = false;
    bool readingImages = false;
    int pdfPageReading = 0;
    bool pdfRead = false;
    await _popup(
      '$title > ${row == null ? 'เพิ่ม' : 'แก้ไข'}',
      Icons.edit_note_outlined,
      StatefulBuilder(
        builder: (context, setLocal) => Column(
          children: [
            if (_text(existing['status']) == 'IN_REVIEW') ...[
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'เมื่อบันทึก รายการจะกลับเป็นแบบร่างและต้องส่งตรวจทานใหม่',
                ),
              ),
              const SizedBox(height: 12),
            ],
            LayoutBuilder(
              builder: (context, constraints) {
                final titleField = _field(titleC, 'ชื่อเรื่อง *');
                final categoryField = DropdownButtonFormField<int>(
                  isExpanded: true,
                  style: knowledgeTokens.tableStyle,
                  initialValue: categoryId,
                  decoration: _comboInput('หมวดความรู้ *'),
                  items: categories
                      .map(
                        (row) => DropdownMenuItem<int>(
                          value: (row['id'] as num).toInt(),
                          child: Text(
                            _text(row['name']),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setLocal(() => categoryId = value!),
                );
                if (constraints.maxWidth < 560) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      titleField,
                      const SizedBox(height: 16),
                      categoryField,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(flex: 3, child: titleField),
                    const SizedBox(width: 16),
                    Expanded(flex: 2, child: categoryField),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final typeField = DropdownButtonFormField<String>(
                  isExpanded: true,
                  style: knowledgeTokens.tableStyle,
                  initialValue: type,
                  decoration: _comboInput('ประเภทเนื้อหา *'),
                  items: [
                    const DropdownMenuItem(
                      value: 'AI_TEXT',
                      child: Text('ข้อความทั่วไป'),
                    ),
                    const DropdownMenuItem(
                      value: 'PDF_FILE',
                      child: Text('แนบไฟล์ PDF'),
                    ),
                    const DropdownMenuItem(
                      value: 'AI_IMAGES',
                      child: Text('รูปภาพสำหรับ AI'),
                    ),
                    if (existing['contentType'] == 'ARTICLE')
                      const DropdownMenuItem(
                        value: 'ARTICLE',
                        child: Text('บทความเดิม'),
                      ),
                    const DropdownMenuItem(
                      value: 'VIDEO_FILE',
                      child: Text('คลิป MP4'),
                    ),
                    const DropdownMenuItem(
                      value: 'VIDEO_URL',
                      child: Text('ลิงก์วิดีโอ'),
                    ),
                    const DropdownMenuItem(
                      value: 'DOCUMENT_CONTROL',
                      child: Text('Document Control'),
                    ),
                    const DropdownMenuItem(
                      value: 'TRAINING',
                      child: Text('Training'),
                    ),
                  ],
                  onChanged: readingImages
                      ? null
                      : (v) => setLocal(() {
                          type = v!;
                          selectedReviewerId = null;
                          if (type == 'AI_IMAGES') includeInAi = true;
                          directEnabled.value = allowDirect();
                          selectedFile = null;
                        }),
                );
                final aiSwitch = SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('ส่งข้อมูลให้ AI'),
                  subtitle: const Text(
                    'ใช้ฉบับที่ผ่านการตรวจทานตามสิทธิ์ที่กำหนด',
                  ),
                  value: includeInAi,
                  onChanged: (value) => setLocal(() {
                    includeInAi = value;
                    directEnabled.value = allowDirect();
                  }),
                );
                final responsibleField = DropdownButtonFormField<int?>(
                  key: ValueKey(responsibleDepartmentId),
                  isExpanded: true,
                  initialValue: responsibleDepartmentId,
                  style: knowledgeTokens.tableStyle,
                  decoration: _comboInput('แผนกที่รับผิดชอบ').copyWith(
                    suffixIcon: IconButton(
                      tooltip: 'ค้นหาแผนก',
                      icon: const Icon(Icons.search),
                      onPressed: () async {
                        final chosen = await chooseResponsibleDepartment();
                        if (chosen != null && context.mounted)
                          setLocal(() => responsibleDepartmentId = chosen);
                      },
                    ),
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('ไม่ระบุ'),
                    ),
                    if (responsibleDepartmentId != null &&
                        !departments.any(
                          (d) =>
                              (d['id'] as num).toInt() ==
                              responsibleDepartmentId,
                        ))
                      DropdownMenuItem<int?>(
                        value: responsibleDepartmentId,
                        child: const Text('แผนกเดิม (ไม่ใช้งาน)'),
                      ),
                    ...departments.map(
                      (d) => DropdownMenuItem<int?>(
                        value: (d['id'] as num).toInt(),
                        child: Text(
                          _text(d['name']),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) =>
                      setLocal(() => responsibleDepartmentId = value),
                );
                if (constraints.maxWidth < 560) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      typeField,
                      const SizedBox(height: 12),
                      responsibleField,
                      const SizedBox(height: 8),
                      aiSwitch,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(flex: 5, child: typeField),
                    const SizedBox(width: 16),
                    Expanded(flex: 5, child: responsibleField),
                    const SizedBox(width: 16),
                    Expanded(flex: 5, child: aiSwitch),
                  ],
                );
              },
            ),
            if (needsReview()) ...[
              const SizedBox(height: 8),
              if (reviewerScope() == 'ANY')
                DropdownButtonFormField<int>(
                  key: ValueKey('reviewer-$type'),
                  initialValue:
                      ((policy()['reviewerUserIds'] as List?) ?? []).contains(
                        selectedReviewerId,
                      )
                      ? selectedReviewerId
                      : null,
                  isExpanded: true,
                  style: knowledgeTokens.tableStyle,
                  decoration: _comboInput('ผู้ตรวจทาน'),
                  items: ((policy()['reviewerUserIds'] as List?) ?? [])
                      .map((id) => (id as num).toInt())
                      .where(configuredReviewerNames.containsKey)
                      .map(
                        (id) => DropdownMenuItem(
                          value: id,
                          child: Text(configuredReviewerNames[id]!),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => selectedReviewerId = value,
                ),
              if (reviewerScope() != 'ANY')
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    reviewerScope() == 'DEPARTMENT'
                        ? 'ผู้ตรวจทาน: ผู้มีสิทธิ์ในแผนกเดียวกับผู้จัดทำ'
                        : 'ผู้ตรวจทาน: ผู้มีสิทธิ์ในฝ่ายเดียวกับผู้จัดทำ',
                  ),
                ),
            ],
            if (type == 'AI_TEXT' || type == 'AI_IMAGES') ...[
              const SizedBox(height: 8),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'ไม่แสดงในคลังความรู้ สามารถเลือกส่งให้ AI ได้',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final audienceField = DropdownButtonFormField<String>(
                  isExpanded: true,
                  style: knowledgeTokens.tableStyle,
                  initialValue: audienceMode,
                  decoration: _comboInput('ผู้มีสิทธิ์เข้าถึง *'),
                  items: const [
                    DropdownMenuItem(value: 'ALL', child: Text('ทุกคน')),
                    DropdownMenuItem(
                      value: 'RESTRICTED',
                      child: Text(
                        'เฉพาะแผนกหรือบุคคล',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  onChanged: (value) => setLocal(() => audienceMode = value!),
                );
                if (audienceMode != 'RESTRICTED') return audienceField;
                final departmentField = DropdownButtonFormField<int?>(
                  isExpanded: true,
                  style: knowledgeTokens.tableStyle,
                  initialValue: departmentId,
                  decoration: _comboInput('แผนกที่เข้าถึงได้'),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('ไม่กำหนด'),
                    ),
                    ...departments.map(
                      (row) => DropdownMenuItem<int?>(
                        value: (row['id'] as num).toInt(),
                        child: Text(
                          _text(row['name']),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) => setLocal(() => departmentId = value),
                );
                final userField = DropdownButtonFormField<int?>(
                  isExpanded: true,
                  style: knowledgeTokens.tableStyle,
                  initialValue: audienceUserId,
                  decoration: _comboInput('บุคคลที่เข้าถึงได้'),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('ไม่กำหนด'),
                    ),
                    ...users.map(
                      (row) => DropdownMenuItem<int?>(
                        value: (row['id'] as num).toInt(),
                        child: Text(
                          _text(row['name']),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) => setLocal(() => audienceUserId = value),
                );
                if (constraints.maxWidth < 700) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      audienceField,
                      const SizedBox(height: 16),
                      departmentField,
                      const SizedBox(height: 16),
                      userField,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: audienceField),
                    const SizedBox(width: 16),
                    Expanded(child: departmentField),
                    const SizedBox(width: 16),
                    Expanded(child: userField),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            _field(summary, 'เนื้อหาสรุป *'),
            if (includeInAi) ...[
              const SizedBox(height: 16),
              TextField(
                controller: body,
                style: knowledgeTokens.inputStyle,
                maxLines: 5,
                decoration: _input('รายละเอียด'),
              ),
            ],
            if (type == 'VIDEO_URL' ||
                type == 'DOCUMENT_CONTROL' ||
                type == 'TRAINING') ...[
              const SizedBox(height: 16),
              _field(url, 'URL หรือ Source reference *'),
            ],
            const SizedBox(height: 8),
            if (includeInAi &&
                type != 'PDF_FILE' &&
                type != 'AI_IMAGES' &&
                type != 'VIDEO_FILE')
              Align(
                alignment: Alignment.centerRight,
                child: _expandDetailsButton(body),
              ),
            if (type == 'VIDEO_FILE') ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (includeInAi) _expandDetailsButton(body),
                  SizedBox(
                    width: 200,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await FilePicker.platform.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: const ['mp4'],
                          withData: true,
                        );
                        if (picked != null) {
                          setLocal(() => selectedFile = picked.files.single);
                        }
                      },
                      icon: const Icon(Icons.video_file_outlined),
                      label: Text(
                        selectedFile?.name ??
                            (existingVideo == null
                                ? 'เลือกคลิป MP4'
                                : _text(existingVideo['fileName'])),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed:
                        selectedFile?.bytes == null && existingVideo == null
                        ? null
                        : () async {
                            PlatformFile file;
                            if (selectedFile?.bytes != null) {
                              file = selectedFile!;
                            } else {
                              try {
                                final data = _map(
                                  await api.get(
                                    '/api/company/knowledge/articles/$savedArticleId/files/${existingVideo!['id']}/preview',
                                  ),
                                );
                                final bytes = base64Decode(
                                  data['base64'] as String,
                                );
                                file = PlatformFile(
                                  name: _text(existingVideo['fileName']),
                                  size: bytes.length,
                                  bytes: bytes,
                                );
                              } catch (error) {
                                if (context.mounted)
                                  knowledgeMessage(
                                    context,
                                    'เปิดตัวอย่างคลิปไม่สำเร็จ: $error',
                                    error: true,
                                  );
                                return;
                              }
                            }
                            if (!context.mounted) return;
                            showDialog<void>(
                              context: context,
                              builder: (dialogContext) => Dialog(
                                backgroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: SizedBox(
                                  width: 1000,
                                  height:
                                      MediaQuery.sizeOf(dialogContext).height *
                                      .8,
                                  child: Column(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                'ตัวอย่างคลิป: ${file.name}',
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            IconButton(
                                              onPressed: () =>
                                                  Navigator.pop(dialogContext),
                                              icon: const Icon(Icons.close),
                                              tooltip: 'ปิด',
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Divider(height: 1),
                                      Expanded(
                                        child: KnowledgeVideoPreview(
                                          bytes: file.bytes!,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                    icon: const Icon(Icons.play_circle_outline),
                    label: const Text('แสดงตัวอย่าง'),
                  ),
                ],
              ),
            ],
            if (type == 'PDF_FILE') ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (includeInAi)
                    const Text(
                      'ระบบใช้ OCR เฉพาะหน้าที่เป็นภาพ · สูงสุด 100 หน้า',
                      style: TextStyle(fontSize: 12),
                    ),
                  if (includeInAi) _expandDetailsButton(body),
                  SizedBox(
                    width: 200,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: readingImages
                          ? null
                          : () async {
                              final picked = await FilePicker.platform
                                  .pickFiles(
                                    type: FileType.custom,
                                    allowedExtensions: const ['pdf'],
                                    withData: true,
                                  );
                              if (picked == null || !context.mounted) return;
                              final file = picked.files.single;
                              if (file.bytes == null ||
                                  file.bytes!.isEmpty ||
                                  file.size <= 0) {
                                knowledgeMessage(
                                  context,
                                  'ไฟล์ PDF ว่างหรืออ่านไม่ได้ กรุณาตรวจสอบไฟล์ต้นฉบับแล้วเลือกอีกครั้ง',
                                  error: true,
                                );
                                return;
                              }
                              setLocal(() {
                                selectedFile = file;
                                pdfRead = false;
                              });
                            },
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: Text(
                        pdfRead ||
                                (selectedFile == null &&
                                    existingFiles.isNotEmpty)
                            ? 'เปลี่ยนไฟล์ใหม่'
                            : (selectedFile?.name ?? 'เลือกไฟล์ PDF'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  if (includeInAi)
                    OutlinedButton.icon(
                      onPressed:
                          !includeInAi ||
                              readingImages ||
                              selectedFile?.bytes == null ||
                              selectedFile!.bytes!.isEmpty
                          ? null
                          : () async {
                              setLocal(() => readingImages = true);
                              try {
                                final file = selectedFile!;
                                final pages = <Map<String, dynamic>>[];
                                var totalPages = 1;
                                for (
                                  var pageNumber = 1;
                                  pageNumber <= totalPages;
                                  pageNumber++
                                ) {
                                  if (!context.mounted) return;
                                  setLocal(() => pdfPageReading = pageNumber);
                                  final result = _map(
                                    await uploadKnowledgeFile(
                                      '/api/company/knowledge/ocr/pdf',
                                      fileName: file.name,
                                      bytes: file.bytes!,
                                      fields: {'page': '$pageNumber'},
                                    ),
                                  );
                                  if (!context.mounted) return;
                                  final current = _rows(result['pages']);
                                  final total = result['totalPages'];
                                  if (current.length != 1 ||
                                      total is! num ||
                                      total < 1 ||
                                      total > 100) {
                                    throw StateError('ไม่พบหน้าที่อ่านได้');
                                  }
                                  totalPages = total.toInt();
                                  pages.add(current.single);
                                }
                                final extracted = pages.map(
                                  (p) =>
                                      'หน้า ${p['page']} (${p['ocr'] == true ? 'OCR' : 'ข้อความ PDF'})\n${p['text'] ?? ''}',
                                );
                                body.text = extracted.join('\n\n');
                                setLocal(() => pdfRead = true);
                                final reviewed = await _expandedDetails(
                                  body.text,
                                );
                                if (!context.mounted) return;
                                if (reviewed != null) body.text = reviewed;
                                knowledgeMessage(
                                  context,
                                  'อ่านข้อความแล้ว กรุณาตรวจแก้ก่อนส่งตรวจทาน',
                                );
                              } catch (error) {
                                if (context.mounted)
                                  knowledgeMessage(
                                    context,
                                    'อ่าน PDF ไม่สำเร็จ: $error',
                                    error: true,
                                  );
                              } finally {
                                if (context.mounted)
                                  setLocal(() => readingImages = false);
                              }
                            },
                      icon: const Icon(Icons.document_scanner_outlined),
                      label: Text(
                        readingImages
                            ? 'กำลังอ่าน PDF หน้า $pdfPageReading'
                            : 'อ่านข้อความจาก PDF',
                      ),
                    ),
                  if (!includeInAi)
                    const Text(
                      'ไม่ส่งให้ AI · ค้นหาจากข้อมูลเรื่อง',
                      style: TextStyle(fontSize: 12),
                    ),
                ],
              ),
              if (selectedFile?.bytes != null || existingFiles.isNotEmpty) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => selectedFile?.bytes != null
                        ? _openPdf({
                            'fileName': selectedFile!.name,
                          }, selected: selectedFile)
                        : _openPdf(existingFiles.first),
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: Text(
                      selectedFile?.name ??
                          _text(existingFiles.first['fileName']),
                    ),
                  ),
                ),
              ],
            ],
            if (type == 'AI_IMAGES') ...[
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (includeInAi) _expandDetailsButton(body),
                  OutlinedButton.icon(
                    onPressed: readingImages
                        ? null
                        : () async {
                            if (!savedImagesLoaded && savedArticleId != null) {
                              try {
                                final loaded = <PlatformFile>[];
                                final loadedIds = <PlatformFile, int>{};
                                for (final entry in existingFiles) {
                                  final id = (entry['id'] as num).toInt();
                                  final data = _map(
                                    await api.get(
                                      '/api/company/knowledge/articles/$savedArticleId/images/$id/content',
                                    ),
                                  );
                                  final bytes = base64Decode(
                                    data['data'] as String,
                                  );
                                  final file = PlatformFile(
                                    name: data['fileName'] as String,
                                    size: bytes.length,
                                    bytes: bytes,
                                  );
                                  loaded.add(file);
                                  loadedIds[file] = id;
                                }
                                imageFiles.insertAll(0, loaded);
                                savedImageIds.addAll(loadedIds);
                                savedImagesLoaded = true;
                              } catch (error) {
                                if (context.mounted)
                                  knowledgeMessage(
                                    context,
                                    'เปิดรูปที่บันทึกแล้วไม่สำเร็จ: $error',
                                    error: true,
                                  );
                                return;
                              }
                            }
                            await _manageKnowledgeImages(
                              imageFiles,
                              body,
                              0,
                              savedImageIds,
                            );
                            if (context.mounted) setLocal(() {});
                          },
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: const Text('จัดการรูป'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      () async {
        if (selectedFile != null &&
            (selectedFile!.bytes == null ||
                selectedFile!.bytes!.isEmpty ||
                selectedFile!.size <= 0)) {
          throw StateError(
            'ไฟล์ว่างหรืออ่านไม่ได้ กรุณาตรวจสอบไฟล์ต้นฉบับแล้วเลือกไฟล์อีกครั้ง',
          );
        }
        if (type == 'AI_IMAGES' &&
            imageFiles.any(
              (file) =>
                  file.bytes == null || file.bytes!.isEmpty || file.size <= 0,
            )) {
          throw StateError(
            'มีไฟล์รูปว่างหรืออ่านไม่ได้ กรุณาเลือกไฟล์รูปอีกครั้ง',
          );
        }
        if (type == 'VIDEO_FILE' &&
            selectedFile?.bytes == null &&
            existingVideo == null) {
          throw StateError('กรุณาเลือกคลิป MP4');
        }
        if (type == 'PDF_FILE' &&
            selectedFile?.bytes == null &&
            existingFiles.isEmpty) {
          throw StateError('กรุณาเลือกไฟล์ PDF');
        }
        if (readingImages) throw StateError('กรุณารอให้อ่านรูปเสร็จก่อน');
        if (type == 'AI_IMAGES' && imageFiles.isEmpty && existingFiles.isEmpty)
          throw StateError('กรุณาเพิ่มรูปอย่างน้อย 1 รูป');
        final payload = {
          'categoryId': categoryId,
          'title': titleC.text,
          'summary': summary.text,
          'contentType': type,
          'includeInAi': includeInAi,
          'responsibleDepartmentId': responsibleDepartmentId,
          'setResponsibleDepartment': true,
          'reviewerUserId': needsReview() && reviewerScope() == 'ANY'
              ? selectedReviewerId
              : null,
          'body': includeInAi ? body.text : null,
          'sourceUrl': url.text,
          'audienceMode': audienceMode,
          'departmentIds': departmentId == null ? <int>[] : [departmentId],
          'userIds': audienceUserId == null ? <int>[] : [audienceUserId],
        };
        final created = savedArticleId == null
            ? await api.post('/api/company/knowledge/articles', body: payload)
            : await api.put(
                '/api/company/knowledge/articles/$savedArticleId',
                body: payload,
              );
        savedArticleId ??= (_map(created)['id'] as num).toInt();
        if (selectedFile?.bytes != null) {
          await uploadKnowledgeFile(
            '/api/company/knowledge/articles/$savedArticleId/files',
            fileName: selectedFile!.name,
            bytes: selectedFile!.bytes!,
            fields: {'kind': type == 'PDF_FILE' ? 'ATTACHMENT' : 'VIDEO'},
          );
        }
        if (type == 'AI_IMAGES') {
          for (final file in imageFiles) {
            if (savedImageIds.containsKey(file)) continue;
            final uploaded = await uploadKnowledgeFile(
              '/api/company/knowledge/articles/$savedArticleId/files',
              fileName: file.name,
              bytes: file.bytes!,
              fields: const {'kind': 'ATTACHMENT'},
            );
            savedImageIds[file] = (_map(uploaded)['id'] as num).toInt();
          }
          if (savedImagesLoaded || existingFiles.isEmpty) {
            await api.put(
              '/api/company/knowledge/articles/$savedArticleId/images/order',
              body: imageFiles.map((f) => savedImageIds[f]!).toList(),
            );
          }
        }
        if (!publishing && allowDirect()) {
          await api.post(
            '/api/company/knowledge/articles/$savedArticleId/publish-direct',
          );
          if (mounted)
            knowledgeMessage(context, 'บันทึกและเผยแพร่องค์ความรู้แล้ว');
        } else if (mounted && !publishing) {
          knowledgeMessage(context, 'บันทึกร่างองค์ความรู้แล้ว');
        }
        load();
      },
      width: 1000,
      contentTopPadding: 22,
      captionTrailing: row == null
          ? null
          : Wrap(
              alignment: WrapAlignment.end,
              spacing: 4,
              children: [
                for (final file in existingFiles)
                  if (_text(file['fileName']).toLowerCase().endsWith('.pdf'))
                    TextButton.icon(
                      onPressed: () => _openPdf(file),
                      icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                      label: Text(
                        _text(file['fileName']),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
              ],
            ),
      directEnabled: directEnabled,
      beforeDirect: () => publishing = true,
      directFailed: () => publishing = false,
      afterDirect: () async {
        try {
          await api.post(
            '/api/company/knowledge/articles/$savedArticleId/publish-direct',
          );
          if (mounted)
            knowledgeMessage(context, 'บันทึกและเผยแพร่องค์ความรู้แล้ว');
          load();
        } finally {
          publishing = false;
        }
      },
    );
    directEnabled.dispose();
  }

  Future<void> _manageKnowledgeImages(
    List<PlatformFile> imageFiles,
    TextEditingController body,
    int existingCount,
    Map<PlatformFile, int> savedImageIds,
  ) async {
    final files = List<PlatformFile>.of(imageFiles);
    final texts = <PlatformFile, String>{};
    final heading = RegExp(
      r'^หน้า\s+\d+\s*\(([^\r\n]*)\)[ \t]*$',
      multiLine: true,
    );
    final original = body.text;
    final matches = heading.allMatches(original).toList();
    for (final file in files) {
      final matching = matches
          .where((match) => match.group(1) == file.name)
          .toList();
      if (matching.length == 1) {
        final match = matching.single;
        final index = matches.indexOf(match);
        final end = index + 1 < matches.length
            ? matches[index + 1].start
            : original.length;
        texts[file] = original.substring(match.end, end).trim();
      }
    }
    var busy = false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, update) {
          Future<void> read(PlatformFile file) async {
            final result = _map(
              await uploadKnowledgeFile(
                '/api/company/knowledge/ocr/image',
                fileName: file.name,
                bytes: file.bytes!,
              ),
            );
            texts[file] = result['text']?.toString() ?? '';
          }

          Future<void> pickImages() async {
            final picked = await FilePicker.platform.pickFiles(
              type: FileType.custom,
              allowedExtensions: const ['jpg', 'jpeg', 'png'],
              allowMultiple: true,
              withData: true,
            );
            if (picked == null || !dialogContext.mounted) return;
            if (picked.files.any(
              (f) =>
                  f.bytes == null ||
                  f.bytes!.isEmpty ||
                  f.size <= 0 ||
                  f.size > 10 * 1024 * 1024,
            )) {
              knowledgeMessage(
                dialogContext,
                'รูปต้องมีข้อมูลและแต่ละไฟล์ต้องไม่เกิน 10 MB',
                error: true,
              );
              return;
            }
            update(() => files.addAll(picked.files));
          }

          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(child: Text('จัดการรูปภาพสำหรับ AI')),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: busy ? null : pickImages,
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: const Text('เพิ่มรูป'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Divider(height: 1),
                const SizedBox(height: 8),
                Text(
                  'ลากเพื่อเรียงลำดับ · JPG, PNG ไม่เกิน 10 MB ต่อรูป',
                  style: TextStyle(
                    fontSize: 12,
                    color: knowledgeTokens.primaryColor,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 900,
              height: MediaQuery.sizeOf(dialogContext).height * .58,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (existingCount > 0)
                    Text(
                      'รูปที่บันทึกไว้ก่อนหน้า $existingCount รูป จัดการแยกจากรูปใหม่',
                      style: const TextStyle(fontSize: 12),
                    ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ReorderableListView.builder(
                      buildDefaultDragHandles: false,
                      itemCount: files.length,
                      onReorder: (oldIndex, newIndex) {
                        if (busy) return;
                        update(() {
                          if (newIndex > oldIndex) newIndex--;
                          files.insert(newIndex, files.removeAt(oldIndex));
                        });
                      },
                      itemBuilder: (context, index) {
                        final file = files[index];
                        return Container(
                          key: ObjectKey(file),
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.black26),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  ReorderableDragStartListener(
                                    index: index,
                                    enabled: !busy,
                                    child: const Padding(
                                      padding: EdgeInsets.all(8),
                                      child: Icon(Icons.drag_handle),
                                    ),
                                  ),
                                  if (file.bytes != null)
                                    Image.memory(
                                      file.bytes!,
                                      width: 80,
                                      height: 70,
                                      fit: BoxFit.contain,
                                    ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${index + 1}. ${file.name}',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: busy
                                        ? null
                                        : () async {
                                            update(() => busy = true);
                                            try {
                                              await read(file);
                                            } catch (error) {
                                              if (dialogContext.mounted)
                                                knowledgeMessage(
                                                  dialogContext,
                                                  'อ่านข้อความไม่สำเร็จ: $error',
                                                  error: true,
                                                );
                                            } finally {
                                              if (dialogContext.mounted)
                                                update(() => busy = false);
                                            }
                                          },
                                    icon: const Icon(
                                      Icons.document_scanner_outlined,
                                    ),
                                    label: Text(
                                      texts.containsKey(file)
                                          ? 'อ่านใหม่'
                                          : 'อ่านข้อความ',
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  OutlinedButton.icon(
                                    onPressed: busy
                                        ? null
                                        : () async {
                                            final edited = await _editImageText(
                                              texts[file] ?? '',
                                            );
                                            if (edited != null &&
                                                dialogContext.mounted)
                                              update(
                                                () => texts[file] = edited,
                                              );
                                          },
                                    icon: const Icon(Icons.open_in_full),
                                    label: const Text('ขยายข้อความ'),
                                  ),
                                  IconButton(
                                    onPressed:
                                        busy || savedImageIds.containsKey(file)
                                        ? null
                                        : () => update(() {
                                            files.remove(file);
                                            texts.remove(file);
                                          }),
                                    icon: const Icon(Icons.delete_outline),
                                    color: Theme.of(context).colorScheme.error,
                                    tooltip: 'ลบรูป',
                                  ),
                                ],
                              ),
                              if (texts.containsKey(file)) ...[
                                const SizedBox(height: 8),
                                TextFormField(
                                  key: ObjectKey(texts[file]),
                                  initialValue: texts[file],
                                  maxLines: 4,
                                  decoration: _input('ข้อความที่อ่านได้'),
                                  onChanged: (value) => texts[file] = value,
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              OutlinedButton.icon(
                onPressed: busy || files.isEmpty
                    ? null
                    : () async {
                        update(() => busy = true);
                        try {
                          for (final file in files) {
                            await read(file);
                          }
                        } catch (error) {
                          if (dialogContext.mounted)
                            knowledgeMessage(
                              dialogContext,
                              'อ่านข้อความไม่สำเร็จ: $error',
                              error: true,
                            );
                        } finally {
                          if (dialogContext.mounted) update(() => busy = false);
                        }
                      },
                icon: const Icon(Icons.document_scanner_outlined),
                label: const Text('อ่านข้อความรวม'),
              ),
              OutlinedButton(
                onPressed: busy ? null : () => Navigator.pop(dialogContext),
                child: const Text('ยกเลิก'),
              ),
              FilledButton(
                onPressed: busy
                    ? null
                    : () {
                        final selectedNames = files
                            .where(texts.containsKey)
                            .map((file) => file.name)
                            .toList();
                        if (selectedNames.toSet().length !=
                                selectedNames.length ||
                            selectedNames.any(
                              (name) =>
                                  matches
                                      .where((m) => m.group(1) == name)
                                      .length >
                                  1,
                            )) {
                          knowledgeMessage(
                            dialogContext,
                            'พบชื่อไฟล์ซ้ำ กรุณาเปลี่ยนชื่อไฟล์ก่อนจัดการข้อความ',
                            error: true,
                          );
                          return;
                        }
                        imageFiles
                          ..clear()
                          ..addAll(files);
                        final preserved = <String>[];
                        if (matches.isEmpty) {
                          if (original.trim().isNotEmpty)
                            preserved.add(original.trim());
                        } else {
                          final prefix = original
                              .substring(0, matches.first.start)
                              .trim();
                          if (prefix.isNotEmpty) preserved.add(prefix);
                          for (var i = 0; i < matches.length; i++) {
                            final match = matches[i];
                            final end = i + 1 < matches.length
                                ? matches[i + 1].start
                                : original.length;
                            if (!selectedNames.contains(match.group(1)))
                              preserved.add(
                                original.substring(match.start, end).trim(),
                              );
                          }
                        }
                        final extracted = <String>[];
                        for (var i = 0; i < files.length; i++) {
                          final text = texts[files[i]];
                          if (text != null)
                            extracted.add(
                              'หน้า ${existingCount + i + 1} (${files[i].name})\n$text',
                            );
                        }
                        if (extracted.isNotEmpty)
                          body.text = [...preserved, ...extracted].join('\n\n');
                        Navigator.pop(dialogContext);
                      },
                child: const Text('บันทึก'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<String?> _editImageText(String initial) async {
    final controller = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        title: const Text('แก้ไขข้อความจากรูป'),
        content: SizedBox(
          width: 900,
          height: MediaQuery.sizeOf(dialogContext).height * .65,
          child: TextField(
            controller: controller,
            expands: true,
            maxLines: null,
            textAlignVertical: TextAlignVertical.top,
            style: knowledgeTokens.inputStyle,
            decoration: _input('ข้อความที่อ่านได้'),
          ),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('ตกลง'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Widget _expandDetailsButton(TextEditingController body) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      OutlinedButton.icon(
        onPressed: () async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (dialogContext) {
              final errorColor = Theme.of(dialogContext).colorScheme.error;
              return AlertDialog(
                backgroundColor: Colors.white,
                surfaceTintColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                  side: BorderSide(color: errorColor),
                ),
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          dialogContext,
                        ).colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Icon(Icons.delete_outline, color: errorColor),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'ยืนยันการลบข้อมูล',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: errorColor,
                        ),
                      ),
                    ),
                  ],
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      color: Theme.of(dialogContext).colorScheme.errorContainer,
                      child: const Text('รายละเอียดทั้งหมด'),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'เมื่อลบและบันทึกแล้วจะไม่สามารถเรียกคืนรายละเอียดได้',
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('ยกเลิก'),
                  ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: errorColor),
                    onPressed: () => Navigator.pop(dialogContext, true),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('ลบ'),
                  ),
                ],
              );
            },
          );
          if (confirmed == true) body.clear();
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: Theme.of(context).colorScheme.error,
          side: BorderSide(color: Theme.of(context).colorScheme.error),
        ),
        icon: const Icon(Icons.delete_outline),
        label: const Text('ลบรายละเอียด'),
      ),
      OutlinedButton.icon(
        onPressed: () async {
          final value = await _expandedDetails(body.text);
          if (value != null) body.text = value;
        },
        icon: const Icon(Icons.open_in_full),
        label: const Text('ขยายรายละเอียด'),
      ),
    ],
  );

  Future<String?> _expandedDetails(String initial) async {
    // OCR stores its page boundaries as visible headings in BodyText, so the
    // same content remains readable by existing consumers and older records.
    final heading = RegExp(r'^หน้า\s+\d+\s*\([^\r\n]*\)\s*$', multiLine: true);
    final matches = heading.allMatches(initial).toList();
    final pages = <String>[];
    final labels = <String>[];
    if (matches.isNotEmpty) {
      final prefix = initial.substring(0, matches.first.start).trim();
      if (prefix.isNotEmpty) {
        pages.add(prefix);
        labels.add('ข้อความ');
      }
      for (var i = 0; i < matches.length; i++) {
        final match = matches[i];
        final end = i + 1 < matches.length
            ? matches[i + 1].start
            : initial.length;
        pages.add(initial.substring(match.end, end).trim());
        final title = match.group(0)!;
        labels.add(
          title.substring(title.indexOf('(') + 1, title.lastIndexOf(')')),
        );
      }
    } else {
      pages.add(initial);
      labels.add('ข้อความ');
    }
    var selectedPage = 0;
    final controller = TextEditingController(text: pages.first);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, update) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          title: const Text('รายละเอียด'),
          content: SizedBox(
            width: 900,
            height: MediaQuery.sizeOf(dialogContext).height * .6,
            child: Column(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    expands: true,
                    maxLines: null,
                    textAlignVertical: TextAlignVertical.top,
                    style: knowledgeTokens.inputStyle,
                    readOnly: selectedPage == -1,
                    decoration: _input(
                      selectedPage == -1
                          ? 'รายละเอียดทุกหน้า'
                          : 'รายละเอียด หน้า ${selectedPage + 1}',
                    ),
                    onChanged: (value) {
                      if (selectedPage >= 0) pages[selectedPage] = value;
                    },
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      if (selectedPage == -1)
                        FilledButton(
                          onPressed: () {},
                          child: const Text('ทุกหน้า'),
                        )
                      else
                        OutlinedButton(
                          onPressed: () => update(() {
                            pages[selectedPage] = controller.text;
                            selectedPage = -1;
                            controller.text = List.generate(
                              pages.length,
                              (i) => 'หน้า ${i + 1}\n${pages[i]}',
                            ).join('\n\n');
                          }),
                          child: const Text('ทุกหน้า'),
                        ),
                      const SizedBox(width: 8),
                      for (var i = 0; i < pages.length; i++) ...[
                        if (i > 0) const SizedBox(width: 8),
                        if (i == selectedPage)
                          FilledButton(
                            onPressed: () {},
                            child: Text('${i + 1}'),
                          )
                        else
                          OutlinedButton(
                            onPressed: () => update(() {
                              if (selectedPage >= 0)
                                pages[selectedPage] = controller.text;
                              selectedPage = i;
                              controller.text = pages[i];
                            }),
                            child: Text('${i + 1}'),
                          ),
                      ],
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () => update(() {
                          if (selectedPage >= 0)
                            pages[selectedPage] = controller.text;
                          pages.add('');
                          labels.add('ข้อความ');
                          selectedPage = pages.length - 1;
                          controller.clear();
                        }),
                        icon: const Icon(Icons.add),
                        label: const Text('เพิ่มหน้า'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: selectedPage < 0 || pages.length <= 1
                            ? null
                            : () async {
                                final pageToDelete = selectedPage;
                                final confirmed = await showDialog<bool>(
                                  context: dialogContext,
                                  builder: (confirmContext) => AlertDialog(
                                    backgroundColor: Colors.white,
                                    surfaceTintColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4),
                                      side: BorderSide(
                                        color: Theme.of(
                                          confirmContext,
                                        ).colorScheme.error,
                                      ),
                                    ),
                                    title: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Theme.of(
                                              confirmContext,
                                            ).colorScheme.errorContainer,
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.delete_outline,
                                            color: Theme.of(
                                              confirmContext,
                                            ).colorScheme.error,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            'ยืนยันการลบข้อมูล',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w700,
                                              color: Theme.of(
                                                confirmContext,
                                              ).colorScheme.error,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.all(10),
                                          color: Theme.of(
                                            confirmContext,
                                          ).colorScheme.errorContainer,
                                          child: Text(
                                            'หน้า ${pageToDelete + 1}',
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        const Text(
                                          'เมื่อลบและบันทึกแล้วจะไม่สามารถเรียกคืนหน้านี้ได้',
                                        ),
                                        const SizedBox(height: 12),
                                        const Divider(height: 1),
                                      ],
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(
                                          confirmContext,
                                          false,
                                        ),
                                        child: const Text('ยกเลิก'),
                                      ),
                                      FilledButton.icon(
                                        style: FilledButton.styleFrom(
                                          backgroundColor: Theme.of(
                                            confirmContext,
                                          ).colorScheme.error,
                                        ),
                                        onPressed: () =>
                                            Navigator.pop(confirmContext, true),
                                        icon: const Icon(Icons.delete_outline),
                                        label: const Text('ลบ'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed != true || !dialogContext.mounted)
                                  return;
                                update(() {
                                  pages.removeAt(pageToDelete);
                                  labels.removeAt(pageToDelete);
                                  selectedPage = pageToDelete.clamp(
                                    0,
                                    pages.length - 1,
                                  );
                                  controller.text = pages[selectedPage];
                                });
                              },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Theme.of(
                            dialogContext,
                          ).colorScheme.error,
                        ),
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('ลบหน้า'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              onPressed: () {
                if (selectedPage >= 0) pages[selectedPage] = controller.text;
                final value = pages.length == 1 && matches.isEmpty
                    ? pages.first
                    : List.generate(
                        pages.length,
                        (i) => 'หน้า ${i + 1} (${labels[i]})\n${pages[i]}',
                      ).join('\n\n');
                Navigator.pop(dialogContext, value);
              },
              child: const Text('ตกลง'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _taxonomyDialog([Map<String, dynamic>? row]) async {
    final code = TextEditingController(text: row?['code']?.toString()),
        name = TextEditingController(text: row?['name']?.toString()),
        sort = TextEditingController(text: _text(row?['sortOrder'] ?? 0));
    final users = _rows(options['users']);
    int? ownerId = row?['ownerUserId'] is num
        ? (row!['ownerUserId'] as num).toInt()
        : null;
    var active = row?['active'] != false;
    await _popup(
      'หมวดความรู้ > ${row == null ? 'เพิ่ม' : 'แก้ไข'}',
      Icons.category_outlined,
      StatefulBuilder(
        builder: (context, setLocal) => Column(
          children: [
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('สถานะ'),
              subtitle: Text(active ? 'ใช้งาน' : 'ปิดใช้งาน'),
              value: active,
              onChanged: (value) => setLocal(() => active = value),
            ),
            const SizedBox(height: 16),
            _field(code, 'รหัส *'),
            const SizedBox(height: 16),
            _field(name, 'ชื่อหมวด *'),
            const SizedBox(height: 16),
            DropdownButtonFormField<int?>(
              style: knowledgeTokens.tableStyle,
              initialValue: ownerId,
              decoration: _comboInput('เจ้าของหมวด'),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('ไม่กำหนด'),
                ),
                ...users.map(
                  (user) => DropdownMenuItem<int?>(
                    value: (user['id'] as num).toInt(),
                    child: Text(
                      _text(user['name']),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              onChanged: (value) => setLocal(() => ownerId = value),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: sort,
              style: knowledgeTokens.inputStyle,
              keyboardType: TextInputType.number,
              decoration: _input('ลำดับ'),
            ),
          ],
        ),
      ),
      () async {
        final body = {
          'code': code.text,
          'name': name.text,
          'ownerUserId': ownerId,
          'sortOrder': int.tryParse(sort.text) ?? 0,
          'active': active,
        };
        if (row == null) {
          await api.post('/api/company/knowledge/taxonomy', body: body);
        } else {
          await api.put(
            '/api/company/knowledge/taxonomy/${(row['id'] as num).toInt()}',
            body: body,
          );
        }
        if (mounted) {
          knowledgeMessage(
            context,
            row == null ? 'เพิ่มหมวดความรู้แล้ว' : 'แก้ไขหมวดความรู้แล้ว',
          );
        }
        load();
      },
    );
  }

  Future<void> _deleteTaxonomy(Map<String, dynamic> row) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        icon: Icon(
          Icons.delete_outline,
          color: Theme.of(context).colorScheme.error,
        ),
        title: Text(
          'ยืนยันการลบ',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
        content: Text(
          'ลบหมวด “${_text(row['name'])}” ถาวรและไม่สามารถเรียกคืนได้',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await api.delete(
      '/api/company/knowledge/taxonomy/${(row['id'] as num).toInt()}',
    );
    if (mounted) knowledgeMessage(context, 'ลบหมวดความรู้แล้ว');
    load();
  }

  Future<void> _questionDetail(int id) async {
    final result = _map(await api.get('/api/company/knowledge/questions/$id'));
    if (!mounted) return;
    final question = _map(result['question']);
    final answers = _rows(result['answers']);
    final answer = TextEditingController();
    await _popup(
      '$title > รายละเอียด',
      Icons.question_answer_outlined,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _text(question['title']),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(_text(question['question'])),
          const SizedBox(height: 16),
          const Divider(),
          for (final item in answers)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                item['accepted'] == true
                    ? Icons.check_circle
                    : Icons.chat_bubble_outline,
                color: item['accepted'] == true
                    ? knowledgeTokens.primaryColor
                    : null,
              ),
              title: Text(_text(item['answer'])),
              subtitle: Text(_text(item['answeredByName'])),
              trailing:
                  question['status'] != 'RESOLVED' && actions['accept'] == true
                  ? TextButton(
                      onPressed: () =>
                          _acceptAnswer(id, (item['id'] as num).toInt()),
                      child: const Text('ยอมรับคำตอบ'),
                    )
                  : null,
            ),
          if (question['status'] != 'RESOLVED' &&
              actions['answer'] == true) ...[
            const SizedBox(height: 8),
            TextField(
              controller: answer,
              style: knowledgeTokens.inputStyle,
              maxLines: 4,
              decoration: _input('เพิ่มคำตอบ *'),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                height: 48,
                child: FilledButton.icon(
                  onPressed: () => _answerQuestion(id, answer.text),
                  icon: const Icon(Icons.send_outlined),
                  label: const Text('ส่งคำตอบ'),
                ),
              ),
            ),
          ],
          if (question['status'] == 'RESOLVED' &&
              question['convertedArticleId'] == null &&
              actions['convert'] == true)
            Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () =>
                      _convertQuestion(id, _text(question['title'])),
                  icon: const Icon(Icons.article_outlined),
                  label: const Text('สร้างร่างองค์ความรู้'),
                ),
              ),
            ),
        ],
      ),
      null,
    );
  }

  Future<void> _deleteQuestion(Map<String, dynamic> row) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        icon: Icon(
          Icons.delete_outline,
          color: Theme.of(context).colorScheme.error,
        ),
        title: Text(
          'ยืนยันการลบ',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
        content: Text(
          'ลบคำถาม “${_text(row['title'])}” ถาวรและไม่สามารถเรียกคืนได้',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await api.delete(
      '/api/company/knowledge/questions/${(row['id'] as num).toInt()}',
    );
    if (mounted) knowledgeMessage(context, 'ลบคำถามแล้ว');
    load();
  }

  Future<void> _answerQuestion(int id, String answer) async {
    await api.post(
      '/api/company/knowledge/questions/$id/answers',
      body: {'answer': answer},
    );
    if (mounted) Navigator.of(context, rootNavigator: true).pop();
    if (mounted) knowledgeMessage(context, 'เพิ่มคำตอบแล้ว');
    load();
  }

  Future<void> _acceptAnswer(int id, int answerId) async {
    await api.post('/api/company/knowledge/questions/$id/accept/$answerId');
    if (mounted) Navigator.of(context, rootNavigator: true).pop();
    if (mounted) knowledgeMessage(context, 'ยอมรับคำตอบและปิดคำถามแล้ว');
    load();
  }

  Future<void> _convertQuestion(int id, String title) async {
    await api.post(
      '/api/company/knowledge/questions/$id/convert',
      body: {'title': title},
    );
    if (mounted) Navigator.of(context, rootNavigator: true).pop();
    if (mounted) knowledgeMessage(context, 'สร้างร่างองค์ความรู้แล้ว');
    load();
  }

  Future<void> _questionDialog([Map<String, dynamic>? row]) async {
    final question = TextEditingController(text: row?['title']?.toString()),
        detail = TextEditingController(text: row?['question']?.toString());
    final categories = _rows(options['categories']);
    if (categories.isEmpty) {
      knowledgeMessage(context, 'กรุณาเพิ่มหมวดความรู้ก่อน', error: true);
      return;
    }
    int categoryId = row?['categoryId'] is num
        ? (row!['categoryId'] as num).toInt()
        : (categories.first['id'] as num).toInt();
    await _popup(
      'ถาม–ตอบผู้เชี่ยวชาญ > ${row == null ? 'ตั้งคำถาม' : 'แก้ไข'}',
      Icons.question_answer_outlined,
      StatefulBuilder(
        builder: (context, setLocal) => Column(
          children: [
            DropdownButtonFormField<int>(
              style: knowledgeTokens.tableStyle,
              initialValue: categoryId,
              decoration: _comboInput('หมวดความรู้ *'),
              items: categories
                  .map(
                    (row) => DropdownMenuItem<int>(
                      value: (row['id'] as num).toInt(),
                      child: Text(_text(row['name'])),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setLocal(() => categoryId = value!),
            ),
            const SizedBox(height: 16),
            _field(question, 'คำถาม *'),
            const SizedBox(height: 16),
            TextField(
              controller: detail,
              style: knowledgeTokens.inputStyle,
              maxLines: 5,
              decoration: _input('รายละเอียด *'),
            ),
          ],
        ),
      ),
      () async {
        final body = {
          'categoryId': categoryId,
          'title': question.text,
          'question': detail.text,
        };
        if (row == null) {
          await api.post('/api/company/knowledge/questions', body: body);
        } else {
          await api.put(
            '/api/company/knowledge/questions/${(row['id'] as num).toInt()}',
            body: body,
          );
        }
        if (mounted) {
          knowledgeMessage(
            context,
            row == null ? 'ส่งคำถามแล้ว' : 'แก้ไขคำถามแล้ว',
          );
        }
        load();
      },
      contentTopPadding: 22,
    );
  }

  Future<void> _reviewDetail(Map<String, dynamic> row) async {
    try {
      final detail = _map(
        await api.get(
          '/api/company/knowledge/reviews/${(row['id'] as num).toInt()}',
        ),
      );
      detail['reviewPreview'] = true;
      detail['assignedReviewer'] = row['assignedReviewer'];
      if (mounted) await _view(detail);
    } catch (error) {
      if (mounted)
        knowledgeMessage(
          context,
          'เปิดรายละเอียดไม่สำเร็จ: $error',
          error: true,
        );
    }
  }

  Future<void> _openLibrarySource(Map<String, dynamic> row) async {
    try {
      final opened = _map(
        await api.post('/api/company/knowledge/library/${row['id']}/open'),
      );
      if (!mounted) return;
      setState(() => row['viewCount'] = opened['viewCount']);
      final type = _text(opened['type']);
      if (type == 'PDF_FILE' || type == 'VIDEO_FILE') {
        final bytes = base64Decode(opened['base64'] as String);
        final name = _text(opened['fileName']);
        if (type == 'PDF_FILE') {
          await _openPdf(
            {'fileName': name},
            selected: PlatformFile(
              name: name,
              size: bytes.length,
              bytes: bytes,
            ),
          );
        } else {
          await showDialog<void>(
            context: context,
            builder: (dialogContext) => Dialog(
              child: SizedBox(
                width: 900,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(name)),
                        IconButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          icon: const Icon(Icons.close),
                          tooltip: 'ปิด',
                        ),
                      ],
                    ),
                    const Divider(height: 1),
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: KnowledgeVideoPreview(bytes: bytes),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
      } else if (type == 'ARTICLE') {
        await _view({...opened, 'contentType': type});
      } else {
        final uri = Uri.tryParse(_text(opened['sourceUrl']));
        if (uri == null || !await launchUrl(uri))
          throw StateError('ไม่สามารถเปิดลิงก์ได้');
      }
    } catch (error) {
      if (mounted)
        knowledgeMessage(
          context,
          'เปิดแหล่งความรู้ไม่สำเร็จ: $error',
          error: true,
        );
    }
  }

  Future<void> _articleView(Map<String, dynamic> row) async {
    try {
      final detail = _map(
        await api.get(
          '/api/company/knowledge/articles/${(row['id'] as num).toInt()}',
        ),
      );
      if (mounted) await _view(detail);
    } catch (error) {
      if (mounted)
        knowledgeMessage(
          context,
          'เปิดรายละเอียดไม่สำเร็จ: $error',
          error: true,
        );
    }
  }

  Future<void> _openPdf(
    Map<String, dynamic> file, {
    PlatformFile? selected,
    int? reviewArticleId,
    int? manageArticleId,
  }) async {
    try {
      final bytes =
          selected?.bytes ??
          base64Decode(
            _map(
                  await api.get(
                    reviewArticleId == null
                        ? manageArticleId == null
                              ? '/api/company/knowledge/files/${(file['id'] as num).toInt()}/pdf-preview'
                              : '/api/company/knowledge/articles/$manageArticleId/files/${file['id']}/preview'
                        : '/api/company/knowledge/reviews/$reviewArticleId/files/${file['id']}/image',
                  ),
                )['base64']
                as String,
          );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          child: SizedBox(
            width: 1000,
            height: MediaQuery.sizeOf(dialogContext).height * .85,
            child: Column(
              children: [
                Row(
                  children: [
                    const SizedBox(width: 16),
                    Expanded(child: Text(_text(file['fileName']))),
                    IconButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(Icons.close),
                      tooltip: 'ปิด',
                    ),
                  ],
                ),
                const Divider(height: 1),
                Expanded(
                  child: PdfPreview(
                    build: (_) async => bytes,
                    canChangePageFormat: false,
                    canChangeOrientation: false,
                    canDebug: false,
                    allowPrinting: false,
                    allowSharing: false,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (error) {
      if (mounted)
        knowledgeMessage(
          context,
          'เปิดไฟล์ PDF ไม่สำเร็จ: $error',
          error: true,
        );
    }
  }

  Uri? _videoEmbedUrl(Object? value) {
    final uri = Uri.tryParse(value?.toString().trim() ?? '');
    if (uri == null || uri.scheme != 'https') return null;
    final host = uri.host.toLowerCase();
    String? id;
    if (host == 'youtu.be') {
      id = uri.pathSegments.isEmpty ? null : uri.pathSegments.first;
    } else if (host == 'youtube.com' ||
        host == 'www.youtube.com' ||
        host == 'm.youtube.com') {
      id = uri.queryParameters['v'];
      if (id == null &&
          uri.pathSegments.length >= 2 &&
          {'embed', 'shorts'}.contains(uri.pathSegments.first))
        id = uri.pathSegments[1];
    }
    if (id != null && RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(id)) {
      return Uri.https('www.youtube-nocookie.com', '/embed/$id');
    }
    if ((host == 'vimeo.com' ||
            host == 'www.vimeo.com' ||
            host == 'player.vimeo.com') &&
        uri.pathSegments.isNotEmpty) {
      final vimeoId = uri.pathSegments.last;
      if (RegExp(r'^\d+$').hasMatch(vimeoId))
        return Uri.https('player.vimeo.com', '/video/$vimeoId');
    }
    return null;
  }

  Widget _imageDetailTabs(Map<String, dynamic> row) {
    final files = _rows(row['files'])
        .where(
          (f) => RegExp(
            r'\.(jpg|jpeg|png|webp)$',
            caseSensitive: false,
          ).hasMatch(_text(f['fileName'])),
        )
        .toList();
    if (files.isEmpty) return const Text('ไม่มีรูปภาพ');
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = (constraints.maxWidth / 220).floor().clamp(1, 5);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: files.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.05,
          ),
          itemBuilder: (context, index) {
            final file = files[index];
            final url = row['reviewPreview'] == true
                ? '/api/company/knowledge/reviews/${row['id']}/files/${file['id']}/image'
                : '/api/company/knowledge/articles/${row['id']}/files/${file['id']}/preview';
            return Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: knowledgeTokens.borderColor),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: FutureBuilder<dynamic>(
                      future: api.get(url),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done)
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        if (snapshot.hasError)
                          return const Center(
                            child: Text('ไม่สามารถแสดงรูปได้'),
                          );
                        if (snapshot.data is! Map)
                          return const Center(
                            child: Text('ไม่สามารถแสดงรูปได้'),
                          );
                        final encoded = _map(snapshot.data)['base64'];
                        if (encoded is! String)
                          return const Center(
                            child: Text('ไม่สามารถแสดงรูปได้'),
                          );
                        return Center(
                          child: Image.memory(
                            base64Decode(encoded),
                            fit: BoxFit.contain,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'หน้า ${index + 1} · ${_text(file['fileName'])}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  List<Map<String, dynamic>> _latestVideo(Map<String, dynamic> row) {
    final files =
        _rows(row['files'])
            .where((f) => _text(f['fileName']).toLowerCase().endsWith('.mp4'))
            .toList()
          ..sort((a, b) => (b['id'] as num).compareTo(a['id'] as num));
    return files.take(1).toList();
  }

  Future<void> _view(Map<String, dynamic> row) => _popup(
    'รายละเอียดองค์ความรู้',
    Icons.visibility_outlined,
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _text(row['title'] ?? row['question']),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Text(_text(row['summary'] ?? row['detail'])),
        if (_text(row['contentType']) == 'AI_IMAGES') ...[
          const SizedBox(height: 12),
          _imageDetailTabs(row),
        ],
        if (_text(row['contentType']) == 'VIDEO_URL' &&
            _videoEmbedUrl(row['sourceUrl']) != null) ...[
          const SizedBox(height: 12),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: KnowledgeVideoEmbed(url: _videoEmbedUrl(row['sourceUrl'])!),
          ),
        ],
        if (_text(row['contentType']) == 'VIDEO_FILE')
          for (final file in _latestVideo(row))
            FutureBuilder<dynamic>(
              future: api.get(
                row['reviewPreview'] == true
                    ? '/api/company/knowledge/reviews/${row['id']}/files/${file['id']}/image'
                    : '/api/company/knowledge/articles/${row['id']}/files/${file['id']}/preview',
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done)
                  return const LinearProgressIndicator();
                if (snapshot.hasError)
                  return const Text('ไม่สามารถแสดงคลิปได้');
                if (snapshot.data is! Map)
                  return const Text('ไม่สามารถแสดงคลิปได้');
                final encoded = _map(snapshot.data)['base64'];
                if (encoded is! String)
                  return const Text('ไม่สามารถแสดงคลิปได้');
                return AspectRatio(
                  aspectRatio: 16 / 9,
                  child: KnowledgeVideoPreview(bytes: base64Decode(encoded)),
                );
              },
            ),
        if ((row['bodyText']?.toString().trim() ?? '').isNotEmpty) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => _popup(
                'รายละเอียดข้อความ',
                Icons.description_outlined,
                SelectableText(row['bodyText'].toString()),
                null,
                width: 1000,
              ),
              icon: const Icon(Icons.open_in_full),
              label: const Text('แสดงรายละเอียดข้อความ'),
            ),
          ),
        ],
        if (!{'AI_IMAGES', 'VIDEO_FILE'}.contains(_text(row['contentType'])) &&
            _rows(row['files']).any(
              (file) =>
                  row['reviewPreview'] == true ||
                  !_text(file['fileName']).toLowerCase().endsWith('.pdf'),
            )) ...[
          const SizedBox(height: 12),
          const Text('ไฟล์แนบ', style: TextStyle(fontWeight: FontWeight.w700)),
          for (final file in _rows(row['files'])) ...[
            if (row['reviewPreview'] == true ||
                !_text(file['fileName']).toLowerCase().endsWith('.pdf'))
              TextButton(
                onPressed:
                    _text(file['fileName']).toLowerCase().endsWith('.pdf')
                    ? () => _openPdf(
                        file,
                        reviewArticleId: row['reviewPreview'] == true
                            ? (row['id'] as num).toInt()
                            : null,
                        manageArticleId: row['reviewPreview'] == true
                            ? null
                            : (row['id'] as num).toInt(),
                      )
                    : null,
                child: Text(_text(file['fileName'])),
              ),
            if (row['reviewPreview'] == true &&
                RegExp(
                  r'\.(jpg|jpeg|png|webp)$',
                  caseSensitive: false,
                ).hasMatch(_text(file['fileName'])))
              FutureBuilder<dynamic>(
                future: api.get(
                  '/api/company/knowledge/reviews/${row['id']}/files/${file['id']}/image',
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done)
                    return const LinearProgressIndicator();
                  if (snapshot.hasError)
                    return const Text('ไม่สามารถแสดงรูปได้');
                  if (snapshot.data is! Map)
                    return const Text('ไม่สามารถแสดงรูปได้');
                  final encoded = _map(snapshot.data)['base64'];
                  if (encoded is! String)
                    return const Text('ไม่สามารถแสดงรูปได้');
                  try {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Image.memory(
                        base64Decode(encoded),
                        height: 220,
                        fit: BoxFit.contain,
                      ),
                    );
                  } catch (_) {
                    return const Text('ไม่สามารถแสดงรูปได้');
                  }
                },
              ),
          ],
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [const Text('สถานะ:'), _statusBadge(row['status'])],
        ),
        if (row.containsKey('includeInAi')) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('AI:'),
              _aiIndicator(row['includeInAi'] == true),
            ],
          ),
        ],
        if (row['id'] != null &&
            _text(row['contentType']) != 'VIDEO_FILE' &&
            !const {
              'ARTICLE',
              'AI_TEXT',
              'AI_IMAGES',
              'PDF_FILE',
            }.contains(_text(row['contentType']))) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () async {
                if (_text(row['contentType']) != 'VIDEO_URL') {
                  await _openSource((row['id'] as num).toInt());
                  return;
                }
                final url = Uri.tryParse(
                  row['sourceUrl']?.toString().trim() ?? '',
                );
                if (url == null ||
                    !{'http', 'https'}.contains(url.scheme) ||
                    !await launchUrl(url)) {
                  if (mounted)
                    knowledgeMessage(
                      context,
                      'เปิดแหล่งข้อมูลไม่สำเร็จ กรุณาตรวจสอบลิงก์',
                      error: true,
                    );
                }
              },
              icon: const Icon(Icons.open_in_new),
              label: const Text('เปิดแหล่งข้อมูลต้นฉบับ'),
            ),
          ),
        ],
      ],
    ),
    null,
    width: row['includeInAi'] != true ? 600 : 1000,
    extraActions: row['reviewPreview'] == true && row['status'] == 'IN_REVIEW'
        ? (dialogContext) => Wrap(
            spacing: 8,
            children: [
              if (actions['return'] == true || row['assignedReviewer'] == true)
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.error,
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  onPressed: () async {
                    Navigator.pop(dialogContext);
                    await _returnDialog(
                      (row['id'] as num).toInt(),
                      _text(row['title']),
                    );
                  },
                  child: const Text('ตีกลับ'),
                ),
              if (actions['publish'] == true || row['assignedReviewer'] == true)
                FilledButton(
                  onPressed: () async {
                    Navigator.pop(dialogContext);
                    await _publish(
                      (row['id'] as num).toInt(),
                      _text(row['title']),
                    );
                  },
                  child: const Text('เผยแพร่'),
                ),
            ],
          )
        : null,
    captionTrailing: row['reviewPreview'] == true
        ? null
        : Wrap(
            alignment: WrapAlignment.end,
            spacing: 4,
            children: [
              for (final file in _rows(row['files']))
                if (_text(file['fileName']).toLowerCase().endsWith('.pdf'))
                  TextButton.icon(
                    onPressed: () => _openPdf(
                      file,
                      manageArticleId: (row['id'] as num).toInt(),
                    ),
                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                    label: Text(
                      _text(file['fileName']),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
            ],
          ),
  );

  Future<void> _openSource(int id) async {
    final source = _map(
      await api.get('/api/company/knowledge/articles/$id/source'),
    );
    final url = source['sourceUrl']?.toString();
    if (url == null || url.isEmpty) {
      if (mounted) {
        knowledgeMessage(context, 'รายการนี้ไม่มี URL ต้นฉบับ', error: true);
      }
      return;
    }
    final parsed = Uri.tryParse(url);
    final uri = parsed == null
        ? null
        : parsed.hasScheme
        ? parsed
        : Uri.base.resolve(url);
    if (uri == null || !await launchUrl(uri)) {
      if (mounted) {
        knowledgeMessage(
          context,
          'ไม่สามารถเปิดแหล่งข้อมูลต้นฉบับได้',
          error: true,
        );
      }
    }
  }

  Future<void> _popup(
    String caption,
    IconData icon,
    Widget content,
    Future<void> Function()? save, {
    double width = 480,
    double contentTopPadding = 12,
    Widget? captionTrailing,
    Widget Function(BuildContext)? extraActions,
    ValueNotifier<bool>? directEnabled,
    VoidCallback? beforeDirect,
    VoidCallback? directFailed,
    Future<void> Function()? afterDirect,
  }) {
    var saving = false;
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialog) => Dialog(
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: width,
              maxWidth: width,
              maxHeight: 680,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 16, 10, 10),
                  child: Row(
                    children: [
                      Icon(icon, size: 24, color: knowledgeTokens.primaryColor),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          caption,
                          style: knowledgeTokens.captionStyle,
                        ),
                      ),
                      if (captionTrailing != null)
                        Flexible(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: captionTrailing,
                          ),
                        ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Flexible(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(10, contentTopPadding, 10, 12),
                    child: content,
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (extraActions != null) extraActions(dialogContext),
                        ConstrainedBox(
                          constraints: const BoxConstraints(
                            minWidth: 112,
                            minHeight: 48,
                          ),
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: knowledgeTokens.primaryColor,
                              textStyle: knowledgeTokens.buttonStyle,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            onPressed: saving
                                ? null
                                : () => Navigator.pop(dialogContext),
                            child: Text(save == null ? 'ปิด' : 'ยกเลิก'),
                          ),
                        ),
                        if (save != null) ...[
                          if (directEnabled != null && afterDirect != null)
                            ValueListenableBuilder<bool>(
                              valueListenable: directEnabled,
                              builder: (context, enabled, _) => enabled
                                  ? OutlinedButton.icon(
                                      onPressed: saving
                                          ? null
                                          : () async {
                                              setDialog(() => saving = true);
                                              beforeDirect?.call();
                                              try {
                                                await save();
                                                await afterDirect();
                                                if (dialogContext.mounted)
                                                  Navigator.pop(dialogContext);
                                              } catch (error) {
                                                directFailed?.call();
                                                if (dialogContext.mounted)
                                                  setDialog(
                                                    () => saving = false,
                                                  );
                                                if (mounted)
                                                  knowledgeMessage(
                                                    context,
                                                    'บันทึกหรือเผยแพร่ไม่สำเร็จ: $error',
                                                    error: true,
                                                  );
                                              }
                                            },
                                      icon: const Icon(Icons.publish),
                                      label: const Text('บันทึกและเผยแพร่'),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ConstrainedBox(
                            constraints: const BoxConstraints(
                              minWidth: 120,
                              minHeight: 48,
                            ),
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: knowledgeTokens.primaryColor,
                                foregroundColor: Colors.white,
                                textStyle: knowledgeTokens.buttonStyle,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              onPressed: saving
                                  ? null
                                  : () async {
                                      setDialog(() => saving = true);
                                      try {
                                        await save();
                                        if (dialogContext.mounted) {
                                          Navigator.pop(dialogContext);
                                        }
                                      } catch (error) {
                                        if (dialogContext.mounted) {
                                          setDialog(() => saving = false);
                                        }
                                        if (error is _ReviewCancelled) return;
                                        if (mounted) {
                                          knowledgeMessage(
                                            context,
                                            'บันทึกข้อมูลไม่สำเร็จ: $error',
                                            error: true,
                                          );
                                        }
                                      }
                                    },
                              icon: saving
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.save_outlined),
                              label: Text(saving ? 'กำลังบันทึก' : 'บันทึก'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
