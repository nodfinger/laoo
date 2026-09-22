import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/visitor_api_client.dart';
import 'visitor_feature_host.dart';
import 'visitor_inside_repository.dart';

class VisitorInsidePage extends StatefulWidget {
  const VisitorInsidePage({super.key});

  @override
  State<VisitorInsidePage> createState() => _VisitorInsidePageState();
}

class _VisitorInsidePageState extends State<VisitorInsidePage> {
  final _search = TextEditingController();
  late final VisitorApiClient _api;
  late final VisitorInsideRepository _repository;
  VisitorInsideActions? _actions;
  VisitorInsideList? _result;
  bool _loading = true;
  bool _working = false;
  String? _error;
  int _page = 1;
  static const _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _api = VisitorApiClient();
    _repository = VisitorInsideRepository(_api);
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    _api.dispose();
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
      if (!actions.canView)
        throw const VisitorApiException(403, 'ไม่มีสิทธิ์ดูผู้มาติดต่อภายใน');
      final result = await _repository.list(
        search: _search.text.trim(),
        page: _page,
        pageSize: _pageSize,
      );
      if (mounted)
        setState(() {
          _actions = actions;
          _result = result;
        });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _checkOut(VisitorInside row) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันการ Check-out'),
        content: Text('ต้องการบันทึกให้ ${row.name} ออกจากระบบหรือไม่'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ยืนยันออก'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted || _working) return;
    setState(() => _working = true);
    try {
      await _repository.checkOut(row.id);
      if (mounted) await _load();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) => buildVisitorWorkspaceShell(
    pageTitle: _actions?.caption ?? 'ผู้มาติดต่อภายใน',
    activeMenu: '31002',
    child: ListView(
      padding: const EdgeInsets.all(10),
      children: [
        _card(
          Row(
            children: [
              const Icon(Icons.people_alt_outlined),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _actions?.caption ?? 'ผู้มาติดต่อภายใน',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (_actions?.canCreate == true)
                FilledButton.icon(
                  onPressed: () => context.go('/visitor/check-in?action=new'),
                  icon: const Icon(Icons.person_add_alt_1),
                  label: const Text('รับผู้มาติดต่อ'),
                ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _loading ? null : () => _load(),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        _card(
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SizedBox(
                width: 300,
                child: TextField(
                  controller: _search,
                  onSubmitted: (_) => _load(resetPage: true),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    labelText: 'ค้นหาชื่อ / เบอร์โทร / เลขบัตร',
                  ),
                ),
              ),
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<String>(
                  initialValue: 'CHECKED_IN',
                  decoration: const InputDecoration(labelText: 'สถานะ'),
                  items: const [
                    DropdownMenuItem(
                      value: 'CHECKED_IN',
                      child: Text('อยู่ภายใน'),
                    ),
                  ],
                  onChanged: null,
                ),
              ),
              FilledButton.icon(
                onPressed: _loading ? null : () => _load(resetPage: true),
                icon: const Icon(Icons.search),
                label: const Text('ค้นหา'),
              ),
              OutlinedButton(
                onPressed: _loading
                    ? null
                    : () {
                        _search.clear();
                        _load(resetPage: true);
                      },
                child: const Text('ล้าง Filter'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        if (_error != null)
          _card(Text(_error!, style: const TextStyle(color: Colors.red))),
        if (_error != null) const SizedBox(height: 6),
        _card(
          _loading
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              : _table(),
        ),
        const SizedBox(height: 6),
        _pagination(),
      ],
    ),
  );

  Widget _table() {
    final rows = _result?.items ?? const <VisitorInside>[];
    return Column(
      children: [
        _headerRow(),
        ...rows.map((row) => _dataRow(row)),
        if (rows.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('ไม่พบผู้มาติดต่อที่อยู่ภายใน'),
          ),
      ],
    );
  }

  Widget _headerRow() => const Padding(
    padding: EdgeInsets.symmetric(vertical: 10),
    child: Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            'ผู้มาติดต่อ',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            'ผู้รับรอง',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        Expanded(
          child: Text(
            'จุดติดต่อ',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        Expanded(
          child: Text(
            'เวลาเข้า',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        SizedBox(
          width: 110,
          child: Text(
            'การทำงาน',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );

  Widget _dataRow(VisitorInside row) => Container(
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: Color(0xFFD9DDE3))),
    ),
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Expanded(flex: 2, child: Text('${row.name}\n#${row.id}')),
        Expanded(flex: 2, child: Text(row.host)),
        Expanded(child: Text(row.point)),
        Expanded(child: Text(_displayDate(row.timeIn))),
        SizedBox(
          width: 110,
          child: _actions?.canEdit == true
              ? OutlinedButton.icon(
                  onPressed: _working ? null : () => _checkOut(row),
                  icon: const Icon(Icons.logout, size: 16),
                  label: const Text('ออก'),
                )
              : const SizedBox.shrink(),
        ),
      ],
    ),
  );

  Widget _pagination() {
    final result = _result;
    final total = result?.total ?? 0;
    final pageCount = total == 0 ? 1 : (total / _pageSize).ceil();
    return SizedBox(
      height: 56,
      child: _card(
        Row(
          children: [
            Text('แสดง ${result?.items.length ?? 0} รายการจากทั้งหมด $total'),
            const Spacer(),
            IconButton(
              onPressed: _page > 1 && !_loading
                  ? () {
                      _page--;
                      _load();
                    }
                  : null,
              icon: const Icon(Icons.chevron_left),
            ),
            Text('$_page / $pageCount'),
            IconButton(
              onPressed: _page < pageCount && !_loading
                  ? () {
                      _page++;
                      _load();
                    }
                  : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ),
    );
  }

  String _displayDate(String value) {
    final date = DateTime.tryParse(value)?.toLocal();
    if (date == null) return value;
    String two(int n) => n.toString().padLeft(2, '0');
    return '${date.day}/${date.month}/${date.year} ${two(date.hour)}:${two(date.minute)}';
  }

  Widget _card(Widget child) => Card(
    margin: EdgeInsets.zero,
    child: Padding(padding: const EdgeInsets.all(10), child: child),
  );
}
