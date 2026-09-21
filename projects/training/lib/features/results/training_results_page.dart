import 'package:flutter/material.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';

import '../training/training_feature_host.dart';
import '../training/training_route_contract.dart';

class TrainingResultsPage extends StatefulWidget {
  const TrainingResultsPage({super.key});

  @override
  State<TrainingResultsPage> createState() => _TrainingResultsPageState();
}

class _TrainingResultsPageState extends State<TrainingResultsPage>
    with SingleTickerProviderStateMixin {
  final _search = TextEditingController();
  late final dynamic _api;
  late final TabController _tabs;
  List<Map<String, dynamic>> _items = [];
  Map<String, dynamic>? _detail;
  Map<String, dynamic>? _section;
  int _page = 1, _total = 0;
  bool _loading = true;
  String? _message;

  String get _sectionCode => _tabs.index == 0 ? 'PRE' : 'POST';

  @override
  void initState() {
    super.initState();
    _api = createTrainingApiClient();
    _tabs = TabController(length: 2, vsync: this)
      ..addListener(() {
        if (!_tabs.indexIsChanging && _detail != null) _loadSection();
      });
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    _tabs.dispose();
    disposeTrainingApiClient(_api);
    super.dispose();
  }

  Future<void> _load({int page = 1}) async {
    setState(() => _loading = true);
    try {
      final data = Map<String, dynamic>.from(
        await _api.get(
              '/api/company/training/results',
              query: {
                'page': '$page',
                'pageSize': '$trainingPageSize',
                'search': _search.text.trim(),
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
      _notice(trainingErrorText(error));
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
      setState(() => _detail = detail);
      await _loadSection();
    } catch (error) {
      _notice(trainingErrorText(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadSection() async {
    final id = (_detail?['bookingId'] as num?)?.toInt();
    if (id == null) {
      return;
    }
    try {
      final data = Map<String, dynamic>.from(
        await _api.get('/api/company/training/results/$id/$_sectionCode')
            as Map,
      );
      if (mounted) setState(() => _section = data);
    } catch (error) {
      _notice(trainingErrorText(error));
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
      pageTitle: 'ผลการอบรม',
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
        caption: 'ผลการอบรม',
        leading: Icon(Icons.assessment_outlined, color: tokens.primaryColor),
      ),
      filter: Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.end,
        children: [
          SizedBox(
            width: 300,
            child: TextField(
              controller: _search,
              onSubmitted: (_) => _load(),
              decoration: const InputDecoration(
                labelText: 'ค้นหาเลขที่จองหรือหัวข้ออบรม',
                prefixIcon: Icon(Icons.search),
              ),
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
              _load();
            },
            child: const Text('ล้าง Filter'),
          ),
        ],
      ),
      table: _loading
          ? const Center(child: CircularProgressIndicator())
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
                      DataCell(Text('${x['bookingNo']}\n${x['subject']}')),
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
      pagination: LaooPaginationCard(
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
    return Column(
      children: [
        Card(
          margin: tokens.workspace.contentMargin,
          color: Colors.white,
          child: Padding(
            padding: tokens.workspace.cardPadding,
            child: Row(
              children: [
                IconButton(
                  onPressed: () => setState(() {
                    _detail = null;
                    _section = null;
                  }),
                  icon: const Icon(Icons.arrow_back_outlined),
                ),
                Icon(Icons.assessment_outlined, color: tokens.primaryColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${detail['bookingNo']} | ${detail['subject']}',
                    style: tokens.workspace.captionStyle,
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: tokens.workspace.contentMargin,
          child: Wrap(
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
        ),
        TabBar(
          controller: _tabs,
          labelColor: tokens.primaryColor,
          tabs: const [
            Tab(text: 'ก่อนอบรม (PRE)'),
            Tab(text: 'หลังอบรม (POST)'),
          ],
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: tokens.workspace.contentMargin,
            child: _sectionTable(tokens, section),
          ),
        ),
      ],
    );
  }

  Widget _count(String label, dynamic value) =>
      Chip(label: Text('$label: ${value ?? 0}'));

  Widget _sectionTable(TrainingUiTokens tokens, Map<String, dynamic>? section) {
    if (section == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final rows = _maps(section['items']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('รหัส')),
              DataColumn(label: Text('ชื่อ')),
              DataColumn(label: Text('สถานะคำเชิญ')),
              DataColumn(label: Text('สถานะสอบ')),
              DataColumn(label: Text('คะแนน')),
              DataColumn(label: Text('เปอร์เซ็นต์')),
              DataColumn(label: Text('ผล')),
              DataColumn(label: Text('เวลาส่ง')),
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
                          x['score'] == null
                              ? '-'
                              : '${x['score']}/${x['maxScore']}',
                        ),
                      ),
                      DataCell(
                        Text(x['percent'] == null ? '-' : '${x['percent']}%'),
                      ),
                      DataCell(Text(_result(x['result']))),
                      DataCell(Text('${x['submittedDate'] ?? '-'}')),
                    ],
                  ),
                )
                .toList(),
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
      : '-';
}
