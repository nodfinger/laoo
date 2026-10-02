// ignore_for_file: curly_braces_in_flow_control_structures, unnecessary_underscores

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';
import 'knowledge_feature_host.dart';

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
  int page = 1;
  bool cards = false;

  @override
  void initState() {
    super.initState();
    title = widget.fallbackTitle;
    knowledgeTitle(widget.menuCode, title).then((v) {
      if (mounted) setState(() => title = v);
    });
    load();
  }

  @override
  void dispose() {
    search.dispose();
    disposeKnowledgeApi(api);
    super.dispose();
  }

  String get endpoint => switch (widget.menuCode) {
    '49001' => 'settings',
    '49002' => 'taxonomy',
    '49003' =>
      'articles?search=${Uri.encodeQueryComponent(search.text)}&page=$page&pageSize=20',
    '49004' => 'reviews',
    '49005' =>
      'library?search=${Uri.encodeQueryComponent(search.text)}&page=$page&pageSize=20',
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
      padding: const EdgeInsets.all(8),
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
  Map<String, dynamic> _map(dynamic v) =>
      v is Map<String, dynamic> ? v : Map<String, dynamic>.from(v as Map);
  List<Map<String, dynamic>> _rows(dynamic v) =>
      v is List ? v.map((x) => _map(x)).toList() : <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _items(dynamic v, [String key = 'items']) =>
      v is Map ? _rows(_map(v)[key]) : _rows(v);
  String _text(dynamic v) => v?.toString() ?? '-';
  Widget _settings() {
    final row = _map(data);
    final video = TextEditingController(text: _text(row['maxVideoMb']));
    final file = TextEditingController(text: _text(row['maxAttachmentMb']));
    final review = TextEditingController(
      text: _text(row['defaultReviewMonths']),
    );
    return _card(
      ListView(
        children: [
          const Text(
            'ค่าการทำงานปัจจุบัน',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const Divider(),
          _field(video, 'ขนาดคลิป MP4 สูงสุด (MB)'),
          const SizedBox(height: 16),
          _field(file, 'ขนาดไฟล์แนบสูงสุด (MB)'),
          const SizedBox(height: 16),
          _field(review, 'รอบทบทวนเริ่มต้น (เดือน)'),
          const SizedBox(height: 20),
          if (actions['edit'] == true)
            Align(
              alignment: Alignment.centerRight,
              child: _button('บันทึก', Icons.save_outlined, () async {
                await api.put(
                  '/api/company/knowledge/settings',
                  body: {
                    'maxVideoMb': int.tryParse(video.text),
                    'maxAttachmentMb': int.tryParse(file.text),
                    'defaultReviewMonths': int.tryParse(review.text),
                  },
                );
                if (mounted) knowledgeMessage(context, 'บันทึกการตั้งค่าแล้ว');
                load();
              }),
            ),
        ],
      ),
    );
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
  }) => Column(
    children: [
      Expanded(
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (rows.isEmpty) {
              return LaooTableCard(
                tokens: knowledgeTokens,
                child: const Center(child: Text('ไม่พบข้อมูล')),
              );
            }
            if (cards ||
                constraints.maxWidth < knowledgeTokens.compactBreakpoint) {
              return ListView.separated(
                itemCount: rows.length,
                separatorBuilder: (_, _) =>
                    SizedBox(height: knowledgeTokens.itemSpacing),
                itemBuilder: (_, index) {
                  final row = rows[index];
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
                                'ID ${index + 1}',
                                style: knowledgeTokens.tableStyle.copyWith(
                                  color: knowledgeTokens.primaryColor,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              for (var i = 0; i < headers.length; i++)
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
              child: LaooWorkspaceDataTable(
                tokens: knowledgeTokens,
                columns: [
                  LaooWorkspaceTableColumns.id,
                  const DataColumn(
                    label: Center(child: Text('Action')),
                    columnWidth: FixedColumnWidth(100),
                  ),
                  ...headers.map((header) => DataColumn(label: Text(header))),
                ],
                rows: List<DataRow>.generate(rows.length, (index) {
                  final row = rows[index];
                  return DataRow(
                    cells: [
                      DataCell(Text('${index + 1}')),
                      DataCell(
                        Center(
                          child: Wrap(
                            spacing: 2,
                            children: rowActions?.call(row) ?? const [],
                          ),
                        ),
                      ),
                      ...values(row).map((value) => DataCell(Text(value))),
                    ],
                  );
                }),
              ),
            );
          },
        ),
      ),
      SizedBox(height: knowledgeTokens.sectionSpacing),
      LaooPaginationCard(
        tokens: knowledgeTokens,
        page: 1,
        pageCount: 1,
        pageSize: rows.isEmpty ? 20 : rows.length,
        total: rows.length,
        onPrevious: null,
        onNext: null,
      ),
    ],
  );

  Widget _articles(bool library) {
    final rows = _items(data);
    return Column(
      children: [
        LaooFilterCard(
          tokens: knowledgeTokens,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 280,
                child: TextField(
                  controller: search,
                  onSubmitted: (_) {
                    setState(() => page = 1);
                    load();
                  },
                  decoration: _input(
                    'ค้นหาชื่อ เนื้อหา หรือ Tag',
                  ).copyWith(prefixIcon: const Icon(Icons.search)),
                ),
              ),
              FilledButton.icon(
                onPressed: () {
                  setState(() => page = 1);
                  load();
                },
                icon: const Icon(Icons.search),
                label: const Text('ค้นหา'),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  search.clear();
                  setState(() => page = 1);
                  load();
                },
                icon: const Icon(Icons.filter_alt_off_outlined),
                label: const Text('ล้าง Filter'),
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
                    separatorBuilder: (_, _) =>
                        SizedBox(height: knowledgeTokens.itemSpacing),
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
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _text(r['title']),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(_text(r['summary']), maxLines: 3, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 8),
        Text(
          '${_text(r['categoryName'])} · ${_text(r['status'])}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: Wrap(spacing: 4, children: _articleActions(r, library)),
        ),
      ],
    ),
  );

  Widget _articleTable(List<Map<String, dynamic>> rows, bool library) =>
      LaooTableCard(
        tokens: knowledgeTokens,
        child: LaooWorkspaceDataTable(
          tokens: knowledgeTokens,
          columns: const [
            LaooWorkspaceTableColumns.id,
            DataColumn(
              label: Center(child: Text('Action')),
              columnWidth: FixedColumnWidth(100),
            ),
            DataColumn(label: Text('รหัส')),
            DataColumn(label: Text('ชื่อองค์ความรู้')),
            DataColumn(label: Text('ประเภท')),
            DataColumn(label: Text('สถานะ')),
          ],
          rows: List<DataRow>.generate(rows.length, (index) {
            final row = rows[index];
            return DataRow(
              cells: [
                DataCell(Text('${(page - 1) * 20 + index + 1}')),
                DataCell(
                  Center(
                    child: Wrap(
                      spacing: 2,
                      children: _articleActions(row, library),
                    ),
                  ),
                ),
                DataCell(Text(_text(row['code']))),
                DataCell(
                  SizedBox(
                    width: 360,
                    child: Text(
                      _text(row['title']),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                DataCell(Text(_text(row['contentType']))),
                DataCell(Text(_text(row['status']))),
              ],
            );
          }),
        ),
      );
  List<Widget> _articleActions(Map<String, dynamic> row, bool library) {
    final id = (row['id'] as num).toInt();
    final status = _text(row['status']);
    final editable = status == 'DRAFT' || status == 'RETURNED';
    return [
      IconButton(
        tooltip: 'เปิดดู',
        onPressed: () => _view(row),
        icon: const Icon(Icons.visibility_outlined),
      ),
      if (!library && editable && actions['edit'] == true)
        IconButton(
          tooltip: 'แก้ไข',
          onPressed: () => _articleDialog(row),
          icon: const Icon(Icons.edit_outlined),
        ),
      if (!library && editable && actions['submit'] == true)
        IconButton(
          tooltip: 'ส่งตรวจทาน',
          onPressed: () async {
            await api.post('/api/company/knowledge/articles/$id/submit');
            if (mounted) knowledgeMessage(context, 'ส่งตรวจทานแล้ว');
            load();
          },
          icon: const Icon(Icons.send_outlined),
        ),
      if (!library &&
          (status == 'PUBLISHED' || status == 'REVIEW_DUE') &&
          actions['edit'] == true)
        IconButton(
          tooltip: 'สร้าง Revision ใหม่',
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

  Widget _reviews() => _simple(_rows(data), 'รายการรอตรวจทาน', review: true);
  Widget _questions() => _card(
    ListView.separated(
      itemCount: _rows(data).length,
      separatorBuilder: (_, __) => const Divider(),
      itemBuilder: (_, index) {
        final row = _rows(data)[index];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.question_answer_outlined),
          title: Text(_text(row['title'])),
          subtitle: Text(
            '${_text(row['categoryName'])} • ${_text(row['status'])} • ${_text(row['answerCount'])} คำตอบ',
          ),
          trailing: Wrap(
            spacing: 2,
            children: [
              IconButton(
                tooltip: 'เปิดดู',
                onPressed: () => _questionDetail((row['id'] as num).toInt()),
                icon: const Icon(Icons.visibility_outlined),
              ),
              if (row['canEdit'] == true && actions['edit'] == true)
                IconButton(
                  tooltip: 'แก้ไข',
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
      },
    ),
  );
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
            subtitle: Text(_text(row['status'])),
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
  }) => _card(
    ListView.separated(
      itemCount: rows.length,
      separatorBuilder: (_, __) => const Divider(),
      itemBuilder: (_, i) {
        final r = rows[i];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            review ? Icons.fact_check_outlined : Icons.auto_stories_outlined,
          ),
          title: Text(_text(r['title'] ?? r['question'])),
          subtitle: Text(_text(r['status'])),
          trailing: review
              ? Wrap(
                  spacing: 4,
                  children: [
                    IconButton(
                      tooltip: 'ส่งกลับ',
                      onPressed: actions['return'] == true
                          ? () => _returnDialog((r['id'] as num).toInt())
                          : null,
                      icon: const Icon(Icons.undo_outlined),
                    ),
                    IconButton(
                      tooltip: 'เผยแพร่',
                      onPressed: actions['publish'] == true
                          ? () => _publish((r['id'] as num).toInt())
                          : null,
                      icon: const Icon(Icons.publish_outlined),
                    ),
                    IconButton(
                      onPressed: () => _view(r),
                      icon: const Icon(Icons.visibility_outlined),
                    ),
                  ],
                )
              : IconButton(
                  onPressed: () => _view(r),
                  icon: const Icon(Icons.chevron_right),
                ),
        );
      },
    ),
  );
  Future<void> _publish(int id) async {
    await api.post(
      '/api/company/knowledge/reviews/$id/publish',
      body: {'note': 'ตรวจทานและเผยแพร่จากหน้าจอ'},
    );
    if (mounted) knowledgeMessage(context, 'เผยแพร่องค์ความรู้แล้ว');
    load();
  }

  Future<void> _returnDialog(int id) async {
    final note = TextEditingController();
    await _popup(
      '$title > ส่งกลับ',
      Icons.undo_outlined,
      TextField(
        controller: note,
        maxLines: 4,
        decoration: _input('เหตุผลที่ส่งกลับ *'),
      ),
      () async {
        await api.post(
          '/api/company/knowledge/reviews/$id/return',
          body: {'note': note.text},
        );
        if (mounted) knowledgeMessage(context, 'ส่งกลับให้เจ้าของแก้ไขแล้ว');
        load();
      },
    );
  }

  Widget _metric(String label, dynamic value, IconData icon) => SizedBox(
    width: 220,
    child: _card(
      Row(
        children: [
          Icon(icon, size: 30, color: Theme.of(context).colorScheme.primary),
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
  Widget _card(Widget child, {double padding = 14}) => LaooSurfaceCard(
    tokens: knowledgeTokens,
    padding: EdgeInsets.all(padding),
    child: child,
  );
  InputDecoration _input(String label) => InputDecoration(
    labelText: label,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(4),
      borderSide: BorderSide(color: Theme.of(context).dividerColor),
    ),
  );
  Widget _field(TextEditingController c, String label) =>
      TextField(controller: c, decoration: _input(label));
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
    String type = existing['contentType']?.toString() ?? 'ARTICLE';
    String audienceMode = existing['audienceMode']?.toString() ?? 'ALL';
    final departments = _rows(options['departments']);
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
    await _popup(
      '$title > ${row == null ? 'เพิ่ม' : 'แก้ไข'}',
      Icons.edit_note_outlined,
      StatefulBuilder(
        builder: (context, setLocal) => Column(
          children: [
            _field(titleC, 'ชื่อเรื่อง *'),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              initialValue: categoryId,
              decoration: _input('หมวดความรู้ *'),
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
            DropdownButtonFormField<String>(
              initialValue: type,
              decoration: _input('ประเภทเนื้อหา *'),
              items: const [
                DropdownMenuItem(value: 'ARTICLE', child: Text('บทความ')),
                DropdownMenuItem(value: 'VIDEO_FILE', child: Text('คลิป MP4')),
                DropdownMenuItem(
                  value: 'VIDEO_URL',
                  child: Text('ลิงก์วิดีโอ'),
                ),
                DropdownMenuItem(
                  value: 'DOCUMENT_CONTROL',
                  child: Text('Document Control'),
                ),
                DropdownMenuItem(value: 'TRAINING', child: Text('Training')),
              ],
              onChanged: (v) => setLocal(() => type = v!),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: audienceMode,
              decoration: _input('ผู้มีสิทธิ์เข้าถึง *'),
              items: const [
                DropdownMenuItem(value: 'ALL', child: Text('ทุกคน')),
                DropdownMenuItem(
                  value: 'RESTRICTED',
                  child: Text('เฉพาะแผนกหรือบุคคล'),
                ),
              ],
              onChanged: (value) => setLocal(() => audienceMode = value!),
            ),
            if (audienceMode == 'RESTRICTED') ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<int?>(
                initialValue: departmentId,
                decoration: _input('แผนกที่เข้าถึงได้'),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('ไม่กำหนด'),
                  ),
                  ...departments.map(
                    (row) => DropdownMenuItem<int?>(
                      value: (row['id'] as num).toInt(),
                      child: Text(_text(row['name'])),
                    ),
                  ),
                ],
                onChanged: (value) => setLocal(() => departmentId = value),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int?>(
                initialValue: audienceUserId,
                decoration: _input('บุคคลที่เข้าถึงได้'),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('ไม่กำหนด'),
                  ),
                  ...users.map(
                    (row) => DropdownMenuItem<int?>(
                      value: (row['id'] as num).toInt(),
                      child: Text(_text(row['name'])),
                    ),
                  ),
                ],
                onChanged: (value) => setLocal(() => audienceUserId = value),
              ),
            ],
            const SizedBox(height: 16),
            _field(summary, 'เนื้อหาสรุป *'),
            const SizedBox(height: 16),
            TextField(
              controller: body,
              maxLines: 5,
              decoration: _input('รายละเอียด'),
            ),
            if (type == 'VIDEO_URL' ||
                type == 'DOCUMENT_CONTROL' ||
                type == 'TRAINING') ...[
              const SizedBox(height: 16),
              _field(url, 'URL หรือ Source reference *'),
            ],
            if (type == 'VIDEO_FILE') ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
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
                  label: Text(selectedFile?.name ?? 'เลือกคลิป MP4'),
                ),
              ),
            ],
          ],
        ),
      ),
      () async {
        if (type == 'VIDEO_FILE' && selectedFile?.bytes == null) {
          throw StateError('กรุณาเลือกคลิป MP4');
        }
        final payload = {
          'categoryId': categoryId,
          'title': titleC.text,
          'summary': summary.text,
          'contentType': type,
          'body': body.text,
          'sourceUrl': url.text,
          'audienceMode': audienceMode,
          'departmentIds': departmentId == null ? <int>[] : [departmentId],
          'userIds': audienceUserId == null ? <int>[] : [audienceUserId],
        };
        final created = row == null
            ? await api.post('/api/company/knowledge/articles', body: payload)
            : await api.put(
                '/api/company/knowledge/articles/${(row['id'] as num).toInt()}',
                body: payload,
              );
        final articleId = (_map(created)['id'] as num).toInt();
        if (selectedFile?.bytes != null) {
          await uploadKnowledgeFile(
            '/api/company/knowledge/articles/$articleId/files',
            fileName: selectedFile!.name,
            bytes: selectedFile!.bytes!,
            fields: const {'kind': 'VIDEO'},
          );
        }
        if (mounted) knowledgeMessage(context, 'บันทึกร่างองค์ความรู้แล้ว');
        load();
      },
    );
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
              initialValue: ownerId,
              decoration: _input('เจ้าของหมวด'),
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
                    ? Theme.of(context).colorScheme.primary
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
              initialValue: categoryId,
              decoration: _input('หมวดความรู้ *'),
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
    );
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
        const SizedBox(height: 12),
        Text('สถานะ: ${_text(row['status'])}'),
        if (row['id'] != null && _text(row['contentType']) != 'ARTICLE') ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () => _openSource((row['id'] as num).toInt()),
              icon: const Icon(Icons.open_in_new),
              label: const Text('เปิดแหล่งข้อมูลต้นฉบับ'),
            ),
          ),
        ],
      ],
    ),
    null,
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
    Future<void> Function()? save,
  ) {
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
            constraints: const BoxConstraints(maxWidth: 480, maxHeight: 680),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      Icon(
                        icon,
                        size: 24,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          caption,
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
                    child: content,
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      SizedBox(
                        width: save == null ? 84 : 84,
                        height: 48,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
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
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 100,
                          height: 48,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
