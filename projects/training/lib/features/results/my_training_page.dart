import 'package:flutter/material.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';
import '../training/training_feature_host.dart';
import '../training/training_route_contract.dart';

class MyTrainingPage extends StatefulWidget {
  const MyTrainingPage({super.key});
  @override
  State<MyTrainingPage> createState() => _MyTrainingPageState();
}

class _MyTrainingPageState extends State<MyTrainingPage> {
  late final dynamic _api;
  List<Map<String, dynamic>> _items = [];
  int _page = 1, _total = 0;
  bool _loading = true;
  String? _message;
  String _caption = 'การอบรมของฉัน';
  final _courseController = TextEditingController();
  String? _resultStatus;

  @override
  void initState() {
    super.initState();
    _api = createTrainingApiClient();
    _loadCaption();
    _load();
  }

  Future<void> _loadCaption() async {
    final caption = await resolveTrainingMenuCaption(
      menuCode: TrainingMenuCodes.myTraining,
      routeName: TrainingRouteNames.myTraining,
      fallback: _caption,
    );
    if (mounted) setState(() => _caption = caption);
  }

  @override
  void dispose() {
    _courseController.dispose();
    disposeTrainingApiClient(_api);
    super.dispose();
  }

  Future<void> _load({int page = 1}) async {
    setState(() => _loading = true);
    try {
      final data = Map<String, dynamic>.from(
        await _api.get(
              '/api/company/my-training',
              query: {
                'page': page.toString(),
                'pageSize': trainingPageSize.toString(),
                if (_courseController.text.trim().isNotEmpty)
                  'course': _courseController.text.trim(),
                if (_resultStatus != null) 'resultStatus': _resultStatus!,
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

  Future<void> _showDetail(Map<String, dynamic> item) async {
    try {
      final data = Map<String, dynamic>.from(
        await _api.get(
              '/api/company/my-training/' + item['participantId'].toString(),
            )
            as Map,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => _DetailDialog(data: data),
      );
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

  void _clearFilters() {
    _courseController.clear();
    setState(() => _resultStatus = null);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = trainingUiTokens;
    final pages = _total == 0 ? 1 : (_total / trainingPageSize).ceil();
    return buildTrainingWorkspaceShell(
      pageTitle: _caption,
      activeMenu: TrainingMenuCodes.myTraining,
      child: Stack(
        children: [
          LaooListWorkspace(
            tokens: tokens.workspace,
            caption: LaooCaptionCard(
              tokens: tokens.workspace,
              caption: _caption,
              leading: Icon(Icons.school_outlined, color: tokens.primaryColor),
            ),
            filter: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 280,
                    child: TextField(
                      controller: _courseController,
                      onSubmitted: (_) => _load(),
                      decoration: const InputDecoration(
                        labelText: 'หลักสูตร',
                        hintText: 'ค้นหาชื่อหลักสูตร',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: DropdownButtonFormField<String?>(
                      value: _resultStatus,
                      decoration: const InputDecoration(
                        labelText: 'ผลสอบ',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text('ทั้งหมด'),
                        ),
                        DropdownMenuItem(value: 'PASSED', child: Text('ผ่าน')),
                        DropdownMenuItem(
                          value: 'FAILED',
                          child: Text('ไม่ผ่าน'),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => _resultStatus = value),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => _load(),
                    icon: const Icon(Icons.search),
                    label: const Text('ค้นหา'),
                  ),
                  OutlinedButton(
                    onPressed: _clearFilters,
                    child: const Text('ล้าง Filter'),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lock_outline,
                        size: 18,
                        color: tokens.primaryColor,
                      ),
                      const SizedBox(width: 8),
                      const Text('แสดงเฉพาะประวัติของบัญชีที่เข้าสู่ระบบ'),
                    ],
                  ),
                ],
              ),
            ),
            table: _loading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('ลำดับ')),
                        DataColumn(label: Text('หัวข้อการอบรม')),
                        DataColumn(label: Text('เลขที่จอง')),
                        DataColumn(label: Text('ห้อง / วันเวลา')),
                        DataColumn(label: Text('สถานะคำเชิญ')),
                        DataColumn(label: Text('PRE')),
                        DataColumn(label: Text('POST')),
                      ],
                      rows: _items.asMap().entries.map((entry) {
                        final x = entry.value;
                        return DataRow(
                          onSelectChanged: (_) => _showDetail(x),
                          cells: [
                            DataCell(
                              Text(
                                ((_page - 1) * trainingPageSize + entry.key + 1)
                                    .toString(),
                              ),
                            ),
                            DataCell(Text(x['subject']?.toString() ?? '-')),
                            DataCell(Text(x['bookingNo']?.toString() ?? '-')),
                            DataCell(
                              Text(
                                (x['roomCode']?.toString() ?? '-') +
                                    ' | ' +
                                    (x['roomName']?.toString() ?? '-') +
                                    '\n' +
                                    (x['startDateTime']?.toString() ?? '-'),
                              ),
                            ),
                            DataCell(Text(_invitation(x['invitationStatus']))),
                            DataCell(Text(_result(x['pre']))),
                            DataCell(Text(_result(x['post']))),
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
          ),
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

  String _invitation(dynamic value) => switch (value?.toString()) {
    'ACCEPTED' => 'ตอบรับแล้ว',
    'DECLINED' => 'ปฏิเสธ',
    _ => 'รอตอบรับ',
  };

  String _result(dynamic value) {
    if (value is! Map) return '-';
    final x = Map<String, dynamic>.from(value);
    if (x['total'] != null) {
      final total = (x['total'] as num?)?.toInt() ?? 0;
      if (total == 0) return '-';
      final submitted = (x['submitted'] as num?)?.toInt() ?? 0;
      final passed = (x['passed'] as num?)?.toInt() ?? 0;
      final result = switch (x['result']?.toString()) {
        'PASSED' => 'ผ่านครบ',
        'FAILED' => 'ไม่ผ่าน',
        _ => 'รอทำให้ครบ',
      };
      return '$submitted/$total ชุด · ผ่าน $passed · $result';
    }
    if (x['score'] != null) {
      final result = x['passed'] == true
          ? 'ผ่าน'
          : x['submitted'] == true
          ? 'ไม่ผ่าน'
          : 'กำลังทำ';
      return x['score'].toString() +
          '/' +
          (x['maxScore']?.toString() ?? '-') +
          ' (' +
          (x['percent']?.toString() ?? '-') +
          '%) ' +
          result;
    }
    return switch (x['status']?.toString()) {
      'NOT_ELIGIBLE' => 'ไม่มีสิทธิ์สอบ',
      'NOT_STARTED' => 'ยังไม่เริ่ม',
      'IN_PROGRESS' => 'กำลังทำ',
      _ => '-',
    };
  }
}

class _DetailDialog extends StatelessWidget {
  const _DetailDialog({required this.data});
  final Map<String, dynamic> data;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(data['subject']?.toString() ?? 'รายละเอียดการอบรม'),
    content: SizedBox(
      width: 520,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('เลขที่จอง: ' + (data['bookingNo']?.toString() ?? '-')),
          Text('สถานะคำเชิญ: ' + (data['invitationStatus']?.toString() ?? '-')),
          const SizedBox(height: 12),
          for (final raw in (data['results'] as List? ?? const []))
            Builder(
              builder: (_) {
                final item = Map<String, dynamic>.from(raw as Map);
                return Card(
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    title: Text(
                      '${item['section']?.toString() ?? '-'} ${item['sequenceNo'] ?? '-'} · ${item['templateName'] ?? '-'}',
                    ),
                    subtitle: Text(item['status']?.toString() ?? '-'),
                    trailing: Text(
                      (item['score']?.toString() ?? '-') +
                          ' / ' +
                          (item['maxScore']?.toString() ?? '-'),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('ปิด'),
      ),
    ],
  );
}
