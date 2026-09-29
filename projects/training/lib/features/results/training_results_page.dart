import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';

import '../training/training_feature_host.dart';
import '../training/training_pagination_card.dart';
import '../training/training_route_contract.dart';

class TrainingResultsPage extends StatefulWidget {
  const TrainingResultsPage({super.key});

  @override
  State<TrainingResultsPage> createState() => _TrainingResultsPageState();
}

class _TrainingResultsPageState extends State<TrainingResultsPage>
    with SingleTickerProviderStateMixin {
  final _search = TextEditingController();
  final _course = TextEditingController();
  late final dynamic _api;
  late final TabController _tabs;
  List<Map<String, dynamic>> _items = [];
  Map<String, dynamic>? _detail;
  Map<String, dynamic>? _section;
  List<Map<String, dynamic>> _evaluations = [];
  int _page = 1, _total = 0;
  bool _loading = true;
  String? _message;
  String? _listError;
  String? _sectionError;
  String? _evaluationError;
  int _sectionLoadEpoch = 0;
  String _status = '';
  String _examResultFilter = '';
  String _caption = 'ผลการอบรม';

  String get _sectionCode => _tabs.index == 0 ? 'PRE' : 'POST';

  @override
  void initState() {
    super.initState();
    _api = createTrainingApiClient();
    _tabs = TabController(length: 2, vsync: this)
      ..addListener(() {
        if (!_tabs.indexIsChanging && _detail != null) _loadSection();
      });
    _loadCaption();
    _load();
  }

  Future<void> _loadCaption() async {
    final caption = await resolveTrainingMenuCaption(
      menuCode: TrainingMenuCodes.results,
      routeName: TrainingRouteNames.results,
      fallback: _caption,
    );
    if (mounted) setState(() => _caption = caption);
  }

  @override
  void dispose() {
    _search.dispose();
    _course.dispose();
    _tabs.dispose();
    disposeTrainingApiClient(_api);
    super.dispose();
  }

  Future<void> _load({int page = 1}) async {
    setState(() {
      _loading = true;
      _listError = null;
    });
    try {
      final data = Map<String, dynamic>.from(
        await _api.get(
              '/api/company/training/results',
              query: {
                'page': '$page',
                'pageSize': '$trainingPageSize',
                'search': _search.text.trim(),
                'course': _course.text.trim(),
                'status': _status,
              },
            )
            as Map,
      );
      if (!mounted) return;
      setState(() {
        _items = _maps(data['items']);
        _total = (data['total'] as num?)?.toInt() ?? 0;
        _page = page;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _items = [];
          _total = 0;
          _listError = trainingErrorText(error);
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(int bookingId) async {
    setState(() => _loading = true);
    try {
      final detail = Map<String, dynamic>.from(
        await _api.get('/api/company/training/results/$bookingId') as Map,
      );
      if (!mounted) return;
      setState(() {
        _detail = detail;
        _section = null;
        _sectionError = null;
        _evaluations = [];
        _evaluationError = null;
        _examResultFilter = '';
      });
      await _loadSection();
      await _loadEvaluations();
    } catch (error) {
      _notice(trainingErrorText(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadEvaluations() async {
    final id = (_detail?['bookingId'] as num?)?.toInt();
    if (id == null) return;
    setState(() {
      _evaluations = [];
      _evaluationError = null;
    });
    try {
      final data = Map<String, dynamic>.from(
        await _api.get('/api/company/training/results/$id/evaluations') as Map,
      );
      if (mounted && (_detail?['bookingId'] as num?)?.toInt() == id) {
        setState(() => _evaluations = _maps(data['items']));
      }
    } catch (error) {
      if (mounted && (_detail?['bookingId'] as num?)?.toInt() == id) {
        setState(() => _evaluationError = trainingErrorText(error));
      }
    }
  }

  Future<void> _loadSection() async {
    final id = (_detail?['bookingId'] as num?)?.toInt();
    if (id == null) {
      return;
    }
    final sectionCode = _sectionCode;
    final epoch = ++_sectionLoadEpoch;
    setState(() {
      _section = null;
      _sectionError = null;
    });
    try {
      final data = Map<String, dynamic>.from(
        await _api.get('/api/company/training/results/$id/$sectionCode') as Map,
      );
      if (mounted && epoch == _sectionLoadEpoch) {
        setState(() => _section = data);
      }
    } catch (error) {
      if (mounted && epoch == _sectionLoadEpoch) {
        setState(() => _sectionError = trainingErrorText(error));
      }
    }
  }

  List<Map<String, dynamic>> _maps(dynamic value) =>
      (value as List? ?? const [])
          .map((x) => Map<String, dynamic>.from(x as Map))
          .toList();

  void _notice(String message) =>
      mounted ? setState(() => _message = message) : null;

  @override
  Widget build(BuildContext context) {
    final tokens = trainingUiTokens;
    return buildTrainingWorkspaceShell(
      pageTitle: _caption,
      activeMenu: TrainingMenuCodes.results,
      child: Stack(
        children: [
          _detail == null ? _list(tokens) : _detailView(tokens),
          if (_message != null)
            Positioned(
              top: 16,
              right: 16,
              child: buildTrainingMessage(
                message: _message!,
                error: true,
                onClose: () => setState(() => _message = null),
              ),
            ),
        ],
      ),
    );
  }

  Widget _list(TrainingUiTokens tokens) {
    final pages = _total == 0 ? 1 : (_total / trainingPageSize).ceil();
    return LaooListWorkspace(
      tokens: tokens.workspace,
      caption: LaooCaptionCard(
        tokens: tokens.workspace,
        caption: _caption,
        leading: Icon(Icons.assessment_outlined, color: tokens.primaryColor),
      ),
      filter: Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.end,
        children: [
          TrainingFilterField(
            width: 220,
            child: TextField(
              controller: _search,
              onSubmitted: (_) => _load(),
              decoration: const InputDecoration(
                labelText: 'เลขที่จอง',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          TrainingFilterField(
            width: 240,
            child: TextField(
              controller: _course,
              onSubmitted: (_) => _load(),
              decoration: const InputDecoration(
                labelText: 'หลักสูตร',
                prefixIcon: Icon(Icons.school_outlined),
              ),
            ),
          ),
          TrainingFilterField(
            width: 180,
            child: DropdownButtonFormField<String>(
              isExpanded: true,
              key: ValueKey(_status),
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'สถานะ'),
              items: const [
                DropdownMenuItem(value: '', child: Text('ทั้งหมด')),
                DropdownMenuItem(value: 'PENDING', child: Text('รออนุมัติ')),
                DropdownMenuItem(value: 'APPROVED', child: Text('อนุมัติแล้ว')),
                DropdownMenuItem(value: 'REJECTED', child: Text('ปฏิเสธ')),
                DropdownMenuItem(value: 'CANCELLED', child: Text('ยกเลิก')),
              ],
              onChanged: _loading
                  ? null
                  : (value) => setState(() => _status = value ?? ''),
            ),
          ),
          FilledButton.icon(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.search),
            label: const Text('ค้นหา'),
          ),
          OutlinedButton(
            onPressed: () {
              _search.clear();
              _course.clear();
              setState(() => _status = '');
              _load();
            },
            child: const Text('ล้าง Filter'),
          ),
        ],
      ),
      table: _loading
          ? const Center(child: CircularProgressIndicator())
          : _listError != null
          ? _errorCard(tokens, _listError!, () => _load(page: _page))
          : _items.isEmpty
          ? const Center(child: Text('ไม่พบผลการอบรม'))
          : LayoutBuilder(
              builder: (context, constraints) =>
                  constraints.maxWidth < tokens.workspace.compactBreakpoint
                  ? ListView.separated(
                      itemCount: _items.length,
                      separatorBuilder: (_, _) =>
                          SizedBox(height: tokens.workspace.itemSpacing),
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        return Card(
                          margin: EdgeInsets.zero,
                          color: tokens.workspace.surfaceColor,
                          surfaceTintColor: Colors.transparent,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              tokens.workspace.radius,
                            ),
                          ),
                          child: Padding(
                            padding: tokens.workspace.cardPadding,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  '${(_page - 1) * trainingPageSize + index + 1} · ${item['bookingNo'] ?? '-'}',
                                  style: tokens.workspace.sectionStyle.copyWith(
                                    color: tokens.primaryColor,
                                  ),
                                ),
                                Text(
                                  '${item['subject'] ?? '-'}',
                                  style: tokens.workspace.tableStyle,
                                ),
                                Text(
                                  '${item['roomCode'] ?? '-'} | ${item['roomName'] ?? '-'} · ${item['startDateTime'] ?? '-'}',
                                  style: tokens.workspace.tableStyle,
                                ),
                                Text(
                                  'เชิญ ${item['invited']} | รับ ${item['accepted']} | รอ ${item['pending']}',
                                  style: tokens.workspace.tableStyle,
                                ),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    onPressed: () => _open(
                                      (item['bookingId'] as num).toInt(),
                                    ),
                                    icon: const Icon(Icons.visibility_outlined),
                                    label: const Text('ดูผลการอบรม'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('ลำดับ')),
                          DataColumn(label: Text('จัดการ')),
                          DataColumn(label: Text('เลขที่จอง / หัวข้ออบรม')),
                          DataColumn(label: Text('ห้อง / วันเวลา')),
                          DataColumn(label: Text('คำเชิญ')),
                        ],
                        rows: _items.asMap().entries.map((entry) {
                          final x = entry.value;
                          return DataRow(
                            cells: [
                              DataCell(
                                Text(
                                  '${(_page - 1) * trainingPageSize + entry.key + 1}',
                                ),
                              ),
                              DataCell(
                                IconButton(
                                  tooltip: 'ดูผลการอบรม',
                                  onPressed: () =>
                                      _open((x['bookingId'] as num).toInt()),
                                  icon: Icon(
                                    Icons.visibility_outlined,
                                    color: tokens.primaryColor,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text('${x['bookingNo']}\n${x['subject']}'),
                              ),
                              DataCell(
                                Text(
                                  '${x['roomCode']} | ${x['roomName']}\n${x['startDateTime'] ?? '-'}',
                                ),
                              ),
                              DataCell(
                                Text(
                                  'เชิญ ${x['invited']} | รับ ${x['accepted']} | รับภายหลัง ${x['lateAccepted']} | รอ ${x['pending']} | ปฏิเสธ ${x['declined']}',
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
            ),
      pagination: TrainingPaginationCard(
        tokens: tokens.workspace,
        page: _page,
        pageCount: pages,
        pageSize: trainingPageSize,
        total: _total,
        onPrevious: _page > 1 ? () => _load(page: _page - 1) : null,
        onNext: _page < pages ? () => _load(page: _page + 1) : null,
      ),
    );
  }

  Widget _detailView(TrainingUiTokens tokens) {
    final detail = _detail!;
    final section = _section;
    return SingleChildScrollView(
      padding: tokens.workspace.contentMargin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LaooCaptionCard(
            tokens: tokens.workspace,
            caption: _caption,
            leading: Icon(
              Icons.assessment_outlined,
              color: tokens.primaryColor,
            ),
          ),
          const SizedBox(height: 6),
          _surfaceCard(
            tokens,
            Row(
              children: [
                IconButton(
                  tooltip: 'ปิดรายละเอียดผลการอบรม',
                  onPressed: () => setState(() {
                    _detail = null;
                    _section = null;
                  }),
                  icon: const Icon(Icons.close),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${detail['bookingNo'] ?? '-'}',
                        style: tokens.workspace.sectionStyle,
                      ),
                      const SizedBox(height: 2),
                      Text('${detail['subject'] ?? '-'}'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: tokens.workspace.sectionSpacing),
          _surfaceCard(
            tokens,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'รอบประเมินที่เกี่ยวข้อง',
                      style: tokens.workspace.sectionStyle,
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () =>
                            context.go('/company/evaluation-results'),
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('ดูผลประเมิน'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_evaluationError != null)
                  _errorContent(_evaluationError!, _loadEvaluations)
                else if (_evaluations.isEmpty)
                  const Text(
                    'ยังไม่มีรอบประเมิน หรือรอคืนห้องเพื่อสร้างร่างประเมิน',
                  )
                else
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: _evaluations
                        .map(
                          (x) => Chip(
                            label: Text(
                              '${x['sourceType'] == 'TRAINING_INSTRUCTOR' ? 'วิทยากร' : 'หลักสูตร'}: ${_evaluationStatus(x['status'])} (${x['submitted']}/${x['eligible']})',
                            ),
                          ),
                        )
                        .toList(),
                  ),
              ],
            ),
          ),
          SizedBox(height: tokens.workspace.sectionSpacing),
          _surfaceCard(
            tokens,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('สรุปคำเชิญ', style: tokens.workspace.sectionStyle),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    _count('เชิญทั้งหมด', detail['invited']),
                    _count('ตอบรับ', detail['accepted']),
                    _count('ตอบรับภายหลัง', detail['lateAccepted']),
                    _count('รอตอบรับ', detail['pending']),
                    _count('ปฏิเสธ', detail['declined']),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: tokens.workspace.sectionSpacing),
          _surfaceCard(
            tokens,
            TabBar(
              controller: _tabs,
              labelColor: tokens.primaryColor,
              tabs: const [
                Tab(text: 'ก่อนอบรม (PRE)'),
                Tab(text: 'หลังอบรม (POST)'),
              ],
            ),
          ),
          SizedBox(height: tokens.workspace.sectionSpacing),
          _sectionTable(tokens, section),
        ],
      ),
    );
  }

  Widget _surfaceCard(TrainingUiTokens tokens, Widget child) => Card(
    margin: EdgeInsets.zero,
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(tokens.workspace.radius),
    ),
    child: Padding(padding: tokens.workspace.cardPadding, child: child),
  );

  Widget _count(String label, dynamic value) =>
      Chip(label: Text('$label: ${value ?? 0}'));

  Widget _errorContent(String message, VoidCallback retry) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(message),
      const SizedBox(height: 12),
      OutlinedButton(onPressed: retry, child: const Text('ลองอีกครั้ง')),
    ],
  );

  Widget _errorCard(
    TrainingUiTokens tokens,
    String message,
    VoidCallback retry,
  ) => _surfaceCard(tokens, _errorContent(message, retry));

  Widget _sectionTable(TrainingUiTokens tokens, Map<String, dynamic>? section) {
    if (_sectionError != null) {
      return _errorCard(tokens, _sectionError!, _loadSection);
    }
    if (section == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final allRows = _maps(section['items']);
    final rows = allRows
        .where(
          (item) =>
              _examResultFilter.isEmpty || item['result'] == _examResultFilter,
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _surfaceCard(
          tokens,
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('สรุปผลแบบทดสอบ', style: tokens.workspace.sectionStyle),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  _count('ผู้มีสิทธิ์สอบ', section['eligible']),
                  _count('ยังไม่เริ่ม', section['notStarted']),
                  _count('กำลังทำ', section['inProgress']),
                  _count('ส่งแล้ว', section['submitted']),
                  _count('ผ่าน', section['passed']),
                  _count('ไม่ผ่าน', section['failed']),
                ],
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  width: 190,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey(_examResultFilter),
                    initialValue: _examResultFilter,
                    decoration: const InputDecoration(labelText: 'ผลสอบ'),
                    items: const [
                      DropdownMenuItem(value: '', child: Text('ทั้งหมด')),
                      DropdownMenuItem(value: 'PASSED', child: Text('ผ่าน')),
                      DropdownMenuItem(value: 'FAILED', child: Text('ไม่ผ่าน')),
                    ],
                    onChanged: (value) =>
                        setState(() => _examResultFilter = value ?? ''),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text('แสดง ${rows.length} จาก ${allRows.length} คน'),
            ],
          ),
        ),
        SizedBox(height: tokens.workspace.sectionSpacing),
        _surfaceCard(
          tokens,
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              dataRowMinHeight: 64,
              dataRowMaxHeight: double.infinity,
              columns: const [
                DataColumn(label: Text('รหัส')),
                DataColumn(label: Text('ชื่อ')),
                DataColumn(label: Text('สถานะคำเชิญ')),
                DataColumn(label: Text('สถานะรวม')),
                DataColumn(label: Text('ทำแล้ว')),
                DataColumn(label: Text('ผลรวม')),
                DataColumn(label: Text('ผลรายชุด')),
              ],
              rows: rows
                  .map(
                    (x) => DataRow(
                      cells: [
                        DataCell(Text('${x['code'] ?? '-'}')),
                        DataCell(Text('${x['name'] ?? '-'}')),
                        DataCell(Text(_invite(x))),
                        DataCell(Text(_test(x['testStatus']))),
                        DataCell(
                          Text(
                            '${x['submittedCount'] ?? 0}/${x['total'] ?? 0} ชุด',
                          ),
                        ),
                        DataCell(Text(_result(x['result']))),
                        DataCell(
                          SizedBox(width: 320, child: Text(_examSummary(x))),
                        ),
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

  String _invite(Map<String, dynamic> x) => x['invitationStatus'] == 'ACCEPTED'
      ? (x['isLateResponse'] == true ? 'ตอบรับภายหลัง' : 'ตอบรับ')
      : x['invitationStatus'] == 'DECLINED'
      ? 'ปฏิเสธ'
      : 'รอตอบรับ';
  String _test(dynamic value) => switch ('$value') {
    'NOT_STARTED' => 'ยังไม่เริ่ม',
    'IN_PROGRESS' => 'กำลังทำ',
    'SUBMITTED' => 'ส่งแล้ว',
    'NOT_ELIGIBLE' => 'ไม่มีสิทธิ์สอบ',
    _ => 'ยังไม่ได้กำหนด',
  };
  String _result(dynamic value) => value == 'PASSED'
      ? 'ผ่าน'
      : value == 'FAILED'
      ? 'ไม่ผ่าน'
      : value == 'INCOMPLETE'
      ? 'รอทำให้ครบ'
      : '-';
  String _examSummary(Map<String, dynamic> participant) {
    final exams = _maps(participant['exams']);
    if (exams.isEmpty) return 'ยังไม่ได้กำหนดชุดแบบทดสอบ';
    return exams
        .map((exam) {
          final score = exam['score'] == null
              ? _test(exam['status'])
              : '${exam['score']}/${exam['maxScore']} (${exam['percent'] ?? '-'}%) ${_result(exam['result'])}';
          return '${exam['sequenceNo']}. ${exam['templateName'] ?? '-'} — $score';
        })
        .join('\n');
  }

  String _evaluationStatus(dynamic value) => switch ('$value') {
    'DRAFT' => 'ร่าง',
    'PENDING_APPROVAL' => 'รออนุมัติ',
    'PUBLISHED' => 'เปิดตอบ',
    'CLOSED' => 'ปิดรอบ',
    _ => '-',
  };
}
