import 'package:flutter/material.dart';
import '../../core/api/visitor_api_client.dart';
import 'visitor_contact_points_repository.dart';
import 'visitor_feature_host.dart';

class VisitorContactPointsPage extends StatefulWidget {
  const VisitorContactPointsPage({super.key});
  @override
  State<VisitorContactPointsPage> createState() =>
      _VisitorContactPointsPageState();
}

class _VisitorContactPointsPageState extends State<VisitorContactPointsPage> {
  final _search = TextEditingController();
  late final VisitorApiClient _api;
  VisitorContactPointActions? _actions;
  VisitorContactPointList? _list;
  bool _loading = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _api = VisitorApiClient();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    _api.dispose();
    super.dispose();
  }

  Future<void> _load([int page = 1]) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = VisitorContactPointsRepository(_api);
      final a = await r.actions();
      final l = await r.list(search: _search.text.trim(), page: page);
      if (mounted) {
        setState(() {
          _actions = a;
          _list = l;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext c) => buildVisitorWorkspaceShell(
    pageTitle: _actions?.caption ?? 'กำหนดจุดติดต่อ',
    activeMenu: '33001',
    child: Stack(
      children: [
        Positioned.fill(child: _body(c)),
        if (_error != null) Positioned(top: 12, right: 12, child: _notice(c)),
      ],
    ),
  );
  Widget _body(BuildContext c) {
    final l = _list;
    if (_loading && l == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView(
      padding: const EdgeInsets.all(10),
      children: [
        _header(c),
        const SizedBox(height: 6),
        _filter(c),
        const SizedBox(height: 6),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          child: _table(c, l),
        ),
      ],
    );
  }

  Widget _header(BuildContext c) => Card(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.location_on_outlined),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _actions?.caption ?? 'กำหนดจุดติดต่อ',
              style: Theme.of(c).textTheme.titleLarge,
            ),
          ),
          if (_actions?.create == true)
            FilledButton.icon(
              onPressed: _edit,
              icon: const Icon(Icons.add),
              label: const Text('เพิ่ม'),
            ),
        ],
      ),
    ),
  );
  Widget _filter(BuildContext c) => Card(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _search,
              onSubmitted: (_) => _load(),
              decoration: const InputDecoration(
                labelText: 'ค้นหารหัสหรือชื่อจุดติดต่อ',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.search),
            label: const Text('ค้นหา'),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: () {
              _search.clear();
              _load();
            },
            child: const Text('ล้าง Filter'),
          ),
        ],
      ),
    ),
  );
  Widget _table(BuildContext c, VisitorContactPointList? l) {
    if (l == null) {
      return const SizedBox(
        height: 120,
        child: Center(child: Text('ไม่พบข้อมูล')),
      );
    }
    return Column(
      children: [
        for (final x in l.items)
          ListTile(
            title: Text('${x.code} — ${x.name}'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${x.branchCode ?? ''} — ${x.branchName ?? ''} · พนักงาน ${x.employeeCount} คน',
                ),
                if (x.employeeNames?.isNotEmpty == true) Text(x.employeeNames!),
              ],
            ),
            trailing: Wrap(
              children: [
                Icon(
                  x.isActive ? Icons.check_circle : Icons.cancel,
                  color: x.isActive ? Colors.green : Colors.grey,
                ),
                if (_actions?.edit == true)
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _edit(x),
                  ),
                if (_actions?.delete == true)
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () => _delete(x),
                  ),
              ],
            ),
          ),
        if (l.items.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Text('ไม่พบจุดติดต่อ'),
          ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('ทั้งหมด ${l.total} รายการ'),
              IconButton(
                onPressed: l.page > 1 ? () => _load(l.page - 1) : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Text('${l.page}'),
              IconButton(
                onPressed: l.items.length == 30
                    ? () => _load(l.page + 1)
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _edit([VisitorContactPoint? x]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _PointDialog(api: _api, initial: x),
    );
    if (saved == true) _load(_list?.page ?? 1);
  }

  Future<void> _delete(VisitorContactPoint x) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        icon: const Icon(Icons.delete_forever, color: Colors.red),
        title: const Text('ลบจุดติดต่อ'),
        content: Text('${x.code} — ${x.name}\nไม่สามารถเรียกคืนได้'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (yes != true) return;
    try {
      await VisitorContactPointsRepository(_api).delete(x.id!);
      _load(_list?.page ?? 1);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Widget _notice(BuildContext c) => Material(
    color: Theme.of(c).colorScheme.errorContainer,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Text(_error!),
          ),
          IconButton(
            onPressed: () => setState(() => _error = null),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    ),
  );
}

class _PointDialog extends StatefulWidget {
  const _PointDialog({required this.api, this.initial});
  final VisitorApiClient api;
  final VisitorContactPoint? initial;
  @override
  State<_PointDialog> createState() => _PointDialogState();
}

class _PointDialogState extends State<_PointDialog> {
  late final _code = TextEditingController(text: widget.initial?.code);
  late final _name = TextEditingController(text: widget.initial?.name);
  VisitorContactPointLookups? _lookups;
  late int? _branch = widget.initial?.branchId;
  late bool _active = widget.initial?.isActive ?? true;
  late Set<int> _employees = {...?widget.initial?.employeeIds};
  bool _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final repository = VisitorContactPointsRepository(widget.api);
      final lookups = await repository.lookups(
        contactPointId: widget.initial?.id,
      );
      final detail = widget.initial?.id == null
          ? null
          : await repository.get(widget.initial!.id!);
      if (!mounted) return;
      setState(() {
        _lookups = lookups;
        if (detail != null) {
          _code.text = detail.code;
          _name.text = detail.name;
          _branch = detail.branchId;
          _active = detail.isActive;
          _employees = {...detail.employeeIds};
        }
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _save() async {
    if (_code.text.trim().isEmpty ||
        _name.text.trim().isEmpty ||
        _branch == null) {
      setState(() => _error = 'กรุณาระบุรหัส ชื่อจุดติดต่อ และสาขา');
      return;
    }
    setState(() => _saving = true);
    try {
      await VisitorContactPointsRepository(widget.api).save(
        (widget.initial ?? const VisitorContactPoint()).copyWith(
          code: _code.text.trim(),
          name: _name.text.trim(),
          branchId: _branch,
          isActive: _active,
          employeeIds: _employees.toList(),
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext c) => AlertDialog(
    title: Text(widget.initial == null ? 'เพิ่มจุดติดต่อ' : 'แก้ไขจุดติดต่อ'),
    content: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('สถานะ'),
              value: _active,
              onChanged: (v) => setState(() => _active = v),
            ),
            TextField(
              controller: _code,
              decoration: const InputDecoration(labelText: 'รหัสจุดติดต่อ *'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'ชื่อจุดติดต่อ *'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              key: ValueKey(_branch),
              initialValue: _branch,
              decoration: const InputDecoration(labelText: 'สาขา *'),
              items: _lookups?.branches
                  .map(
                    (b) => DropdownMenuItem(
                      value: b.id,
                      child: Text('${b.code} — ${b.name}'),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _branch = v),
            ),
            const SizedBox(height: 12),
            Text('พนักงานประจำจุด', style: Theme.of(c).textTheme.titleMedium),
            if (_lookups == null)
              const Center(child: CircularProgressIndicator())
            else
              for (final e in _lookups!.employees)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _employees.contains(e.id),
                  enabled: e.available || _employees.contains(e.id),
                  title: Text('${e.code} — ${e.name}'),
                  subtitle: e.available ? null : const Text('ประจำจุดอื่นแล้ว'),
                  onChanged: (v) => setState(() {
                    if (v == true) {
                      _employees.add(e.id);
                    } else {
                      _employees.remove(e.id);
                    }
                  }),
                ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(c).colorScheme.error),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(c),
        child: const Text('ยกเลิก'),
      ),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: Text(_saving ? 'กำลังบันทึก' : 'บันทึก'),
      ),
    ],
  );
}
