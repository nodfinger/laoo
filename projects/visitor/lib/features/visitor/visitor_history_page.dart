import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/api/visitor_api_client.dart';
import 'visitor_feature_host.dart';
import 'visitor_history_repository.dart';

class VisitorHistoryPage extends StatefulWidget {
  const VisitorHistoryPage({super.key});

  @override
  State<VisitorHistoryPage> createState() => _VisitorHistoryPageState();
}

class _VisitorHistoryPageState extends State<VisitorHistoryPage> {
  final _search = TextEditingController();
  late final VisitorApiClient _api;
  late final VisitorHistoryRepository _repository;
  VisitorHistoryActions? _actions;
  VisitorHistoryList? _result;
  DateTimeRange? _period;
  String _outcome = 'ALL';
  String? _error;
  bool _loading = true;
  int _page = 1;
  static const _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _api = VisitorApiClient();
    _repository = VisitorHistoryRepository(_api);
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    _api.dispose();
    super.dispose();
  }

  Future<void> _load({bool resetPage = false}) async {
    if (resetPage) {
      _page = 1;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final actions = await _repository.actions();
      if (!actions.canView) {
        throw const VisitorApiException(403, 'ไม่มีสิทธิ์ดูประวัติผู้มาติดต่อ');
      }
      final result = await _repository.list(
        search: _search.text.trim(),
        outcomeCode: _outcome == 'ALL' ? null : _outcome,
        dateFrom: _period?.start,
        dateTo: _period?.end,
        page: _page,
        pageSize: _pageSize,
      );
      if (mounted) {
        setState(() {
          _actions = actions;
          _result = result;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickPeriod() async {
    final value = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _period,
    );
    if (value != null && mounted) setState(() => _period = value);
  }

  void _clear() {
    _search.clear();
    setState(() {
      _outcome = 'ALL';
      _period = null;
    });
    _load(resetPage: true);
  }

  String get _periodText {
    final value = _period;
    return value == null
        ? 'ทุกช่วงวันที่'
        : '${_date(value.start)} — ${_date(value.end)}';
  }

  String _date(DateTime value) => '${value.day}/${value.month}/${value.year}';

  @override
  Widget build(BuildContext context) => buildVisitorWorkspaceShell(
    pageTitle: _actions?.caption ?? 'ประวัติผู้มาติดต่อ',
    activeMenu: '31005',
    child: ListView(
      padding: const EdgeInsets.all(10),
      children: [
        _surface(
          Row(
            children: [
              const Icon(Icons.history_outlined),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _actions?.caption ?? 'ประวัติผู้มาติดต่อ',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _surface(_filters()),
        const SizedBox(height: 8),
        if (_error != null)
          _surface(Text(_error!, style: const TextStyle(color: Colors.red))),
        if (_error != null) const SizedBox(height: 8),
        _surface(_list()),
      ],
    ),
  );

  Widget _filters() => Wrap(
    spacing: 8,
    runSpacing: 8,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      SizedBox(
        width: 320,
        child: TextField(
          controller: _search,
          onSubmitted: (_) => _load(resetPage: true),
          decoration: const InputDecoration(
            labelText: 'ค้นหาผู้มาติดต่อ / ผู้รับรอง / จุดติดต่อ',
            prefixIcon: Icon(Icons.search),
          ),
        ),
      ),
      SizedBox(
        width: 190,
        child: DropdownButtonFormField<String>(
          key: ValueKey(_outcome),
          initialValue: _outcome,
          decoration: const InputDecoration(labelText: 'ผลการเข้าพบ'),
          items: const [
            DropdownMenuItem(value: 'ALL', child: Text('ทั้งหมด')),
            DropdownMenuItem(value: 'MET', child: Text('เข้าพบสำเร็จ')),
            DropdownMenuItem(value: 'NOT_MET', child: Text('ไม่ได้เข้าพบ')),
            DropdownMenuItem(
              value: 'CANCELLED',
              child: Text('ยกเลิกการเข้าพบ'),
            ),
          ],
          onChanged: (value) => setState(() => _outcome = value ?? 'ALL'),
        ),
      ),
      OutlinedButton.icon(
        onPressed: _loading ? null : _pickPeriod,
        icon: const Icon(Icons.date_range_outlined),
        label: Text(_periodText),
      ),
      FilledButton.icon(
        onPressed: _loading ? null : () => _load(resetPage: true),
        icon: const Icon(Icons.search),
        label: const Text('ค้นหา'),
      ),
      OutlinedButton(
        onPressed: _loading ? null : _clear,
        child: const Text('ล้าง Filter'),
      ),
    ],
  );

  Widget _list() {
    final items = _result?.items ?? const <VisitorHistoryItem>[];
    return LayoutBuilder(
      builder: (context, constraints) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'รายการ Check-out แล้ว',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(28),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (constraints.maxWidth < 900)
            ...items.map(_compactItem)
          else
            _table(items),
          if (!_loading && items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(28),
              child: Center(child: Text('ไม่พบประวัติผู้มาติดต่อ')),
            ),
          const Divider(height: 24),
          _pagination(),
        ],
      ),
    );
  }

  Widget _table(List<VisitorHistoryItem> items) => Column(
    children: [
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Expanded(flex: 2, child: Text('ผู้มาติดต่อ')),
            Expanded(flex: 2, child: Text('ผู้รับรอง')),
            Expanded(child: Text('จุดติดต่อ')),
            Expanded(child: Text('เวลาเข้า')),
            Expanded(flex: 2, child: Text('ผล / เวลาออก')),
            SizedBox(width: 110),
          ],
        ),
      ),
      ...items.map(
        (item) => Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0xFFD9DDE3))),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Text('${item.visitorName}\n${item.visitPurpose}'),
              ),
              Expanded(flex: 2, child: Text(item.hostName)),
              Expanded(child: Text(item.contactPointName)),
              Expanded(child: Text(_dateTime(item.checkedInDate))),
              Expanded(flex: 2, child: _outcomeCell(item)),
              SizedBox(
                width: 110,
                child: OutlinedButton(
                  onPressed: () => _showDetail(item),
                  child: const Text('ดูรายละเอียด'),
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );

  Widget _compactItem(VisitorHistoryItem item) => Container(
    padding: const EdgeInsets.symmetric(vertical: 12),
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: Color(0xFFD9DDE3))),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${item.visitorName}\n${item.visitPurpose}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            OutlinedButton(
              onPressed: () => _showDetail(item),
              child: const Text('ดูรายละเอียด'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text('ผู้รับรอง: ${item.hostName}'),
        Text('จุดติดต่อ: ${item.contactPointName}'),
        Text('เวลาเข้า: ${_dateTime(item.checkedInDate)}'),
        const SizedBox(height: 4),
        _outcomeCell(item),
      ],
    ),
  );

  Widget _outcomeCell(VisitorHistoryItem item) => Text.rich(
    TextSpan(
      children: [
        TextSpan(
          text: '${item.outcomeLabel}\n',
          style: TextStyle(
            color: item.outcomeCode == 'MET'
                ? Colors.green.shade700
                : Colors.orange.shade800,
            fontWeight: FontWeight.w700,
          ),
        ),
        TextSpan(
          text: '${item.reasonLabel} · ${_dateTime(item.checkedOutDate)}',
        ),
      ],
    ),
  );

  Widget _pagination() {
    final result = _result;
    final total = result?.total ?? 0;
    final pageCount = total == 0 ? 1 : (total / _pageSize).ceil();
    return Row(
      children: [
        Expanded(child: Text('ทั้งหมด $total รายการ')),
        IconButton(
          onPressed: _loading || _page <= 1
              ? null
              : () {
                  setState(() => _page--);
                  _load();
                },
          icon: const Icon(Icons.chevron_left),
        ),
        Text('$_page / $pageCount'),
        IconButton(
          onPressed: _loading || _page >= pageCount
              ? null
              : () {
                  setState(() => _page++);
                  _load();
                },
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  Future<void> _showDetail(VisitorHistoryItem item) => showDialog<void>(
    context: context,
    builder: (_) => _HistoryDetailDialog(repository: _repository, item: item),
  );

  String _dateTime(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    final local = parsed.toLocal();
    return '${local.day}/${local.month}/${local.year} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  Widget _surface(Widget child) => Material(
    color: Colors.white,
    child: Padding(padding: const EdgeInsets.all(16), child: child),
  );
}

class _HistoryDetailDialog extends StatelessWidget {
  const _HistoryDetailDialog({required this.repository, required this.item});
  final VisitorHistoryRepository repository;
  final VisitorHistoryItem item;

  @override
  Widget build(BuildContext context) => AlertDialog(
    insetPadding: const EdgeInsets.all(16),
    title: const Text('รายละเอียดการเข้าพบ'),
    content: SizedBox(
      width: (MediaQuery.sizeOf(context).width - 32)
          .clamp(280.0, 680.0)
          .toDouble(),
      child: FutureBuilder(
        future: repository.detail(item.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Text(snapshot.error.toString());
          }
          final detail = snapshot.data!;
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _section('ข้อมูล Check-in', [
                  'ผู้มาติดต่อ: ${detail.visit['visitorName'] ?? '-'}',
                  'ผู้รับรอง: ${detail.visit['hostName'] ?? '-'}',
                  'จุดติดต่อ: ${detail.visit['contactPointName'] ?? '-'}',
                  'วัตถุประสงค์: ${detail.visit['visitPurpose'] ?? '-'}',
                  'เวลาเข้า: ${detail.visit['checkedInDate'] ?? '-'}',
                ]),
                _section('ผลและ Check-out', [
                  'ผลการเข้าพบ: ${detail.visit['visitOutcomeCode'] ?? '-'}',
                  'ประเภท Check-out: ${detail.visit['checkoutReasonCode'] ?? '-'}',
                  'หมายเหตุ: ${detail.visit['checkoutNote'] ?? '-'}',
                  'ผู้ดำเนินการ: ${detail.visit['checkedOutByName'] ?? '-'}',
                  'เวลาออก: ${detail.visit['checkedOutDate'] ?? '-'}',
                ]),
                if (detail.visit['hostConfirmationResultCode'] != null)
                  _section('การยืนยันจากผู้รับรอง', [
                    'ผลการยืนยัน: ${detail.visit['hostConfirmationResultCode']}',
                    'ผู้ยืนยัน: ${detail.visit['hostConfirmedByName'] ?? '-'}',
                    'เวลา: ${detail.visit['hostConfirmedDate'] ?? '-'}',
                    if ((detail.visit['hostConfirmationNote']?.toString() ?? '')
                        .isNotEmpty)
                      'หมายเหตุ: ${detail.visit['hostConfirmationNote']}',
                  ]),
                _section('หลักฐานเดิม', [
                  if (detail.images.isEmpty)
                    'ไม่มีหลักฐาน'
                  else
                    _HistoryEvidenceList(
                      repository: repository,
                      visitId: item.id,
                      images: detail.images,
                    ),
                ]),
                _section(
                  'ข้อความเพิ่มเติม',
                  detail.notes.isEmpty
                      ? const ['ไม่มีข้อความเพิ่มเติม']
                      : detail.notes
                            .map((note) => note['noteText']?.toString() ?? '-')
                            .toList(growable: false),
                ),
              ],
            ),
          );
        },
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('ปิด'),
      ),
    ],
  );

  Widget _section(String title, List<Object> lines) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        ...lines.map(
          (line) => line is Widget
              ? line
              : Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(line.toString()),
                ),
        ),
      ],
    ),
  );
}

class _HistoryEvidenceList extends StatelessWidget {
  const _HistoryEvidenceList({
    required this.repository,
    required this.visitId,
    required this.images,
  });

  final VisitorHistoryRepository repository;
  final int visitId;
  final List<Map<String, dynamic>> images;

  @override
  Widget build(BuildContext context) => Column(
    children: images
        .map((image) {
          final imageId = (image['visitorVisitImageId'] as num?)?.toInt();
          final bytes = imageId == null
              ? null
              : repository.imageBytes(visitId, imageId);
          return ListTile(
            contentPadding: EdgeInsets.zero,
            onTap: bytes == null ? null : () => _preview(context, image, bytes),
            leading: SizedBox(
              width: 48,
              height: 48,
              child: bytes == null
                  ? const Icon(Icons.broken_image_outlined)
                  : FutureBuilder<List<int>>(
                      future: bytes,
                      builder: (context, snapshot) {
                        if (snapshot.hasData) {
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.memory(
                              Uint8List.fromList(snapshot.data!),
                              fit: BoxFit.cover,
                            ),
                          );
                        }
                        if (snapshot.hasError) {
                          return const Icon(Icons.broken_image_outlined);
                        }
                        return const Center(child: CircularProgressIndicator());
                      },
                    ),
            ),
            title: Text(
              '${image['evidenceType'] ?? 'DOCUMENT'} / ${image['captureStage'] ?? 'CHECKIN'}',
            ),
            subtitle: Text(image['originalFileName']?.toString() ?? '-'),
          );
        })
        .toList(growable: false),
  );

  Future<void> _preview(
    BuildContext context,
    Map<String, dynamic> image,
    Future<List<int>> bytes,
  ) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(image['originalFileName']?.toString() ?? 'หลักฐานรูปภาพ'),
      content: SizedBox(
        width: 560,
        child: AspectRatio(
          aspectRatio: 1,
          child: FutureBuilder<List<int>>(
            future: bytes,
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return InteractiveViewer(
                  child: Image.memory(
                    Uint8List.fromList(snapshot.data!),
                    fit: BoxFit.contain,
                  ),
                );
              }
              if (snapshot.hasError) {
                return const Center(
                  child: Icon(Icons.broken_image_outlined, size: 80),
                );
              }
              return const Center(child: CircularProgressIndicator());
            },
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('ปิด'),
        ),
      ],
    ),
  );
}
