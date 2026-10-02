import 'package:flutter/material.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';

import '../../core/api/visitor_api_client.dart';
import 'visitor_exceptions_repository.dart';
import 'visitor_feature_host.dart';
import 'visitor_inside_repository.dart';
import 'visitor_visit_detail_dialog.dart';

class VisitorExceptionsPage extends StatefulWidget {
  const VisitorExceptionsPage({super.key, this.apiClient});

  final VisitorApiClient? apiClient;

  @override
  State<VisitorExceptionsPage> createState() => _VisitorExceptionsPageState();
}

class _VisitorExceptionsPageState extends State<VisitorExceptionsPage> {
  final _search = TextEditingController();
  late final VisitorApiClient _api;
  late final VisitorExceptionsRepository _repository;
  late final VisitorInsideRepository _detailRepository;
  VisitorExceptionsActions? _actions;
  VisitorExceptionsList? _result;
  DateTimeRange? _period;
  String _type = 'ALL';
  String? _error;
  bool _loading = true;
  int _page = 1;
  static const _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _api = widget.apiClient ?? VisitorApiClient();
    _repository = VisitorExceptionsRepository(_api);
    _detailRepository = VisitorInsideRepository(_api);
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    if (widget.apiClient == null) _api.dispose();
    super.dispose();
  }

  Future<void> _load({bool resetPage = false}) async {
    if (resetPage) _page = 1;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final actions = await _repository.actions();
      if (!actions.canView) {
        throw const VisitorApiException(403, 'ไม่มีสิทธิ์ดูรายการผิดปกติ');
      }
      final result = await _repository.list(
        search: _search.text.trim(),
        exceptionType: _type == 'ALL' ? null : _type,
        dateFrom: _period?.start,
        dateTo: _period?.end,
        page: _page,
        pageSize: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _actions = actions;
        _result = result;
      });
    } catch (error) {
      if (mounted) {
        final detail = error is VisitorApiException
            ? error.message
            : 'กรุณาตรวจสอบการเชื่อมต่อแล้วลองอีกครั้ง';
        setState(
          () => _error =
              'ไม่สามารถโหลดรายการผิดปกติได้\nรายละเอียดเพิ่มเติม: $detail',
        );
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
      _type = 'ALL';
      _period = null;
    });
    _load(resetPage: true);
  }

  @override
  Widget build(BuildContext context) => buildVisitorWorkspaceShell(
    pageTitle: _actions?.caption ?? '',
    activeMenu: '34003',
    child: ListView(
      padding: EdgeInsets.all(visitorUiTokens.cardMargin),
      children: [
        _surface(
          Row(
            children: [
              Expanded(
                child: Text(
                  _actions?.caption ?? '',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const LaooPageFavoriteButton(),
            ],
          ),
        ),
        SizedBox(height: visitorUiTokens.listSectionSpacing),
        _surface(_filters()),
        SizedBox(height: visitorUiTokens.listSectionSpacing),
        if (_error != null) ...[
          _surface(
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _loading ? null : _load,
                  child: const Text('ลองอีกครั้ง'),
                ),
              ],
            ),
          ),
          SizedBox(height: visitorUiTokens.listSectionSpacing),
        ],
        if (_error == null) _surface(_list()),
        SizedBox(height: visitorUiTokens.listSectionSpacing),
        _pagination(),
      ],
    ),
  );

  Widget _filters() => LayoutBuilder(
    builder: (context, constraints) => Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: constraints.maxWidth < 280 ? constraints.maxWidth : 280,
          child: TextField(
            controller: _search,
            onSubmitted: (_) => _load(resetPage: true),
            decoration: const InputDecoration(
              labelText: 'ค้นหาชื่อ / ผู้รับรอง / จุดติดต่อ',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        SizedBox(
          width: constraints.maxWidth < 250 ? constraints.maxWidth : 250,
          child: DropdownButtonFormField<String>(
            key: ValueKey(_type),
            initialValue: _type,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'ประเภทผิดปกติ'),
            items: const [
              DropdownMenuItem(value: 'ALL', child: Text('ทั้งหมด')),
              DropdownMenuItem(
                value: 'HOST_CONFIRMATION_PENDING',
                child: Text('รอยืนยันการเข้าพบ'),
              ),
              DropdownMenuItem(
                value: 'CHECKOUT_OTHER',
                child: Text('Check-out เหตุผลอื่น ๆ'),
              ),
              DropdownMenuItem(
                value: 'NOTIFICATION_FAILED',
                child: Text('แจ้งเตือนส่งไม่สำเร็จ'),
              ),
              DropdownMenuItem(
                value: 'NOTIFICATION_NO_CHANNEL',
                child: Text('ไม่มีช่องทางแจ้งเตือน'),
              ),
              DropdownMenuItem(
                value: 'CHECKOUT_RULE_MISMATCH',
                child: Text('ผลและเหตุผลไม่สัมพันธ์กัน'),
              ),
            ],
            onChanged: (value) => setState(() => _type = value ?? 'ALL'),
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
    ),
  );

  String get _periodText {
    final value = _period;
    if (value == null) return 'ทุกช่วงวันที่';
    return '${_date(value.start)} — ${_date(value.end)}';
  }

  Widget _list() {
    final items = _result?.items ?? const <VisitorExceptionItem>[];
    return LayoutBuilder(
      builder: (context, constraints) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'รายการที่ต้องตรวจสอบ',
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
          else if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(28),
              child: Center(child: Text('ไม่พบรายการผิดปกติ')),
            )
          else if (constraints.maxWidth < 900)
            ...items.map(_compactItem)
          else
            _table(items),
        ],
      ),
    );
  }

  Widget _table(List<VisitorExceptionItem> items) => Column(
    children: [
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            SizedBox(width: 56, child: Text('ID')),
            Expanded(flex: 2, child: Text('ผู้มาติดต่อ')),
            Expanded(flex: 2, child: Text('ประเภท / รายละเอียด')),
            Expanded(child: Text('ผู้รับรอง')),
            Expanded(child: Text('จุดติดต่อ')),
            Expanded(child: Text('เวลาพบ')),
            SizedBox(width: 108),
          ],
        ),
      ),
      ...items.map(
        (item) => Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          ),
          child: Row(
            children: [
              SizedBox(width: 56, child: Text('${item.visitId}')),
              Expanded(flex: 2, child: Text(item.visitorName)),
              Expanded(
                flex: 2,
                child: Text('${item.typeLabel}\n${item.description}'),
              ),
              Expanded(child: Text(item.hostName)),
              Expanded(child: Text(item.contactPointName)),
              Expanded(child: Text(_dateTime(item.occurredDate))),
              SizedBox(
                width: 108,
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

  Widget _compactItem(VisitorExceptionItem item) => Container(
    padding: const EdgeInsets.symmetric(vertical: 12),
    decoration: BoxDecoration(
      border: Border(
        top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                item.visitorName,
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
        Text('${item.typeLabel}: ${item.description}'),
        Text('ผู้รับรอง: ${item.hostName}'),
        Text('จุดติดต่อ: ${item.contactPointName}'),
        Text('เวลาพบ: ${_dateTime(item.occurredDate)}'),
      ],
    ),
  );

  Widget _pagination() {
    final result = _result;
    final total = result?.total ?? 0;
    final pageCount = total == 0 ? 1 : (total / _pageSize).ceil();
    return VisitorPaginationCard(
      page: _page,
      pageCount: pageCount,
      pageSize: _pageSize,
      total: total,
      onPrevious: _loading || _page <= 1
          ? null
          : () {
              setState(() => _page--);
              _load();
            },
      onNext: _loading || _page >= pageCount
          ? null
          : () {
              setState(() => _page++);
              _load();
            },
    );
  }

  Future<void> _showDetail(VisitorExceptionItem item) => showDialog<void>(
    context: context,
    builder: (_) => VisitorVisitDetailDialog(
      repository: _detailRepository,
      visitId: item.visitId,
      visitorName: item.visitorName,
      canEdit: false,
    ),
  );

  String _date(DateTime value) => '${value.day}/${value.month}/${value.year}';

  String _dateTime(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    final local = parsed.toLocal();
    return '${_date(local)} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  Widget _surface(Widget child) => Card(
    margin: EdgeInsets.zero,
    elevation: 0,
    child: Padding(
      padding: EdgeInsets.all(visitorUiTokens.cardPadding),
      child: child,
    ),
  );
}
