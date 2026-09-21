import 'package:flutter/material.dart';
import '../../../app/theme/laoo_design_tokens.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/widgets/auto_dismiss_message.dart';
import '../presentation/widgets/support_workspace_shell.dart';

class VillageLocationPage extends StatefulWidget {
  const VillageLocationPage({super.key, required this.caption});
  final String caption;
  @override
  State<VillageLocationPage> createState() => _VillageLocationPageState();
}

class _VillageLocationPageState extends State<VillageLocationPage> {
  final _api = ApiClient();
  final _search = TextEditingController();
  List<Map<String, dynamic>> _lanes = [], _houses = [];
  int? _laneId;
  bool _loading = true, _housesMode = false;
  String _query = '';
  String? _message;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _loadLanes();
  }

  Future<void> _loadLanes() async {
    try {
      final data = await _api.get(
        '/api/company/business-locations/village/lanes',
      );
      if (!mounted) return;
      setState(() {
        _lanes = List<Map<String, dynamic>>.from(data as List);
        _loading = false;
      });
      if (_housesMode) await _loadHouses();
    } catch (e) {
      if (mounted) _fail(e);
    }
  }

  Future<void> _loadHouses() async {
    try {
      final data = await _api.get(
        '/api/company/business-locations/village/houses',
        query: _laneId == null ? null : {'laneId': '$_laneId'},
      );
      if (mounted) {
        setState(() => _houses = List<Map<String, dynamic>>.from(data as List));
      }
    } catch (e) {
      if (mounted) _fail(e);
    }
  }

  void _fail(Object e) => setState(() {
    _error = true;
    _message = e is ApiException ? e.message : 'ดำเนินการไม่สำเร็จ';
  });

  void _success(String text) => setState(() {
    _error = false;
    _message = text;
  });

  Future<void> _editLane([Map<String, dynamic>? row]) async {
    final code = TextEditingController(text: row?['code']?.toString() ?? '');
    final name = TextEditingController(text: row?['name']?.toString() ?? '');
    var type = row?['type']?.toString() ?? 'SOI';
    var active = row?['active'] != false;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          title: Text(row == null ? 'เพิ่มซอย/แยก' : 'แก้ไขซอย/แยก'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'ประเภท *'),
                  items: const [
                    DropdownMenuItem(value: 'SOI', child: Text('ซอย')),
                    DropdownMenuItem(value: 'JUNCTION', child: Text('แยก')),
                  ],
                  onChanged: (v) => setDialogState(() => type = v ?? type),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: code,
                  decoration: const InputDecoration(labelText: 'รหัส *'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'ชื่อ *'),
                ),
                Row(
                  children: [
                    const Text('สถานะ'),
                    Switch(
                      value: active,
                      onChanged: (v) => setDialogState(() => active = v),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              onPressed: () async {
                if (code.text.trim().isEmpty || name.text.trim().isEmpty) {
                  return;
                }
                final path = row == null
                    ? '/api/company/business-locations/village/lanes'
                    : '/api/company/business-locations/village/lanes/${row['id']}';
                final body = {
                  'type': type,
                  'code': code.text.trim(),
                  'name': name.text.trim(),
                  'active': active,
                };
                if (row == null) {
                  await _api.post(path, body: body);
                } else {
                  await _api.put(path, body: body);
                }
                if (dialogContext.mounted) Navigator.pop(dialogContext, true);
              },
              child: const Text('บันทึก'),
            ),
          ],
        ),
      ),
    );
    if (saved == true) {
      await _loadLanes();
      _success('บันทึกซอย/แยกสำเร็จ');
    }
  }

  Future<void> _editHouse([Map<String, dynamic>? row]) async {
    final number = TextEditingController(
      text: row?['houseNo']?.toString() ?? '',
    );
    final address = TextEditingController(
      text: row?['address']?.toString() ?? '',
    );
    var active = row?['active'] != false;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          title: Text(row == null ? 'เพิ่มบ้านเลขที่' : 'แก้ไขบ้านเลขที่'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: number,
                  decoration: const InputDecoration(labelText: 'บ้านเลขที่ *'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: address,
                  decoration: const InputDecoration(
                    labelText: 'ที่อยู่เพิ่มเติม',
                  ),
                ),
                Row(
                  children: [
                    const Text('สถานะ'),
                    Switch(
                      value: active,
                      onChanged: (v) => setDialogState(() => active = v),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              onPressed: () async {
                if (number.text.trim().isEmpty || _laneId == null) return;
                final path = row == null
                    ? '/api/company/business-locations/village/houses'
                    : '/api/company/business-locations/village/houses/${row['id']}';
                final body = {
                  'laneId': _laneId,
                  'houseNo': number.text.trim(),
                  'addressText': address.text.trim(),
                  'active': active,
                };
                if (row == null) {
                  await _api.post(path, body: body);
                } else {
                  await _api.put(path, body: body);
                }
                if (dialogContext.mounted) Navigator.pop(dialogContext, true);
              },
              child: const Text('บันทึก'),
            ),
          ],
        ),
      ),
    );
    if (saved == true) {
      await _loadHouses();
      _success('บันทึกบ้านเลขที่สำเร็จ');
    }
  }

  List<Map<String, dynamic>> _residents = [];

  Future<void> _loadResidents(int houseId) async {
    final data = await _api.get('/api/company/business-locations/village/residents', query: {'houseId': '$houseId'});
    if (mounted) setState(() => _residents = List<Map<String, dynamic>>.from(data as List));
  }

  Future<String?> _pickDate(String current) async {
    final initial = DateTime.tryParse(current) ?? DateTime.now();
    final date = await showDatePicker(context: context, initialDate: initial, firstDate: DateTime(2000), lastDate: DateTime(2100));
    return date?.toIso8601String().substring(0, 10);
  }

  Future<void> _editResident(Map<String, dynamic> house, [Map<String, dynamic>? row]) async {
    final people = List<Map<String, dynamic>>.from(await _api.get('/api/company/persons/lookup') as List);
    final start = TextEditingController(text: row?['startDate']?.toString().split('T').first ?? DateTime.now().toIso8601String().substring(0, 10));
    final end = TextEditingController(text: row?['endDate']?.toString().split('T').first ?? '');
    int? personId = row?['personId'] as int?;
    var active = row?['active'] != false;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          title: Text(row == null ? 'เพิ่มผู้อาศัย' : 'แก้ไขผู้อาศัย'),
          content: SizedBox(
            width: 480,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Align(alignment: Alignment.centerLeft, child: Text('บ้านเลขที่ ${house['houseNo']}')),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: personId,
                decoration: const InputDecoration(labelText: 'บุคคล *'),
                items: people.map((person) {
                  final id = (person['personID'] as num).toInt();
                  return DropdownMenuItem(value: id, child: Text('${person['fullName']}'));
                }).toList(),
                onChanged: (value) => setDialogState(() => personId = value),
              ),
              const SizedBox(height: 12),
              TextField(controller: start, readOnly: true, decoration: const InputDecoration(labelText: 'วันที่เริ่มอยู่อาศัย *'), onTap: () async { final value = await _pickDate(start.text); if (value != null) setDialogState(() => start.text = value); }),
              const SizedBox(height: 12),
              TextField(controller: end, readOnly: true, decoration: const InputDecoration(labelText: 'วันที่สิ้นสุด'), onTap: () async { final value = await _pickDate(end.text); if (value != null) setDialogState(() => end.text = value); }),
              Row(children: [const Text('สถานะ'), Switch(value: active, onChanged: (value) => setDialogState(() => active = value))]),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('ยกเลิก')),
            FilledButton(onPressed: () async {
              if (personId == null || start.text.isEmpty) return;
              final path = row == null ? '/api/company/business-locations/village/residents' : '/api/company/business-locations/village/residents/${row['id']}';
              final body = {'houseId': house['id'], 'personId': personId, 'startDate': start.text, 'endDate': end.text.isEmpty ? null : end.text, 'active': active};
              try {
                if (row == null) { await _api.post(path, body: body); } else { await _api.put(path, body: body); }
                if (dialogContext.mounted) Navigator.pop(dialogContext, true);
              } catch (e) {
                if (dialogContext.mounted) Navigator.pop(dialogContext, false);
                if (mounted) _fail(e);
              }
            }, child: const Text('บันทึก')),
          ],
        ),
      ),
    );
    if (saved == true) { await _loadResidents((house['id'] as num).toInt()); _success('บันทึกผู้อาศัยสำเร็จ'); }
  }

  Future<void> _showResidents(Map<String, dynamic> house) async {
    await _loadResidents((house['id'] as num).toInt());
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          title: Text('ผู้อาศัยบ้านเลขที่ ${house['houseNo']}'),
          content: SizedBox(width: 620, child: _residents.isEmpty ? const Text('ยังไม่มีผู้อาศัย') : ListView.separated(shrinkWrap: true, itemCount: _residents.length, separatorBuilder: (_, __) => const Divider(height: 1), itemBuilder: (_, index) {
            final resident = _residents[index];
            return ListTile(title: Text('${resident['personName']}'), subtitle: Text('${resident['startDate']?.toString().split('T').first ?? '-'} | ${resident['active'] == true ? 'ใช้งาน' : 'ไม่ใช้งาน'}'), trailing: IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () async { await _editResident(house, resident); setDialogState(() {}); }));
          })),
          actions: [
            TextButton(onPressed: () async { await _editResident(house); setDialogState(() {}); }, child: const Text('เพิ่มผู้อาศัย')),
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('ปิด')),
          ],
        ),
      ),
    );
  }
  @override
  Widget build(BuildContext context) => SupportWorkspaceShell(
    pageTitle: widget.caption,
    activeMenu: '14001',
    menuScope: WorkspaceMenuScope.company,
    child: Padding(
      padding: const EdgeInsets.all(LaooLayout.cardMargin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(),
          const SizedBox(height: 6),
          _filters(),
          const SizedBox(height: LaooLayout.cardSpacing),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _housesMode
                ? _houseTable()
                : _laneTable(),
          ),
          if (_message != null)
            AutoDismissMessage(
              message: _message!,
              error: _error,
              onClose: () => setState(() => _message = null),
            ),
        ],
      ),
    ),
  );

  Widget _header() => Card(
    child: Padding(
      padding: const EdgeInsets.all(LaooLayout.cardPadding),
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.caption,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
          FilledButton.icon(
            onPressed: _housesMode ? () => _editHouse() : () => _editLane(),
            icon: const Icon(Icons.add),
            label: Text(_housesMode ? 'เพิ่มบ้านเลขที่' : 'เพิ่มซอย/แยก'),
          ),
        ],
      ),
    ),
  );

  Widget _filters() => Card(
    child: Padding(
      padding: const EdgeInsets.all(LaooLayout.cardPadding),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ChoiceChip(
            label: const Text('ซอย/แยก'),
            selected: !_housesMode,
            onSelected: (_) => setState(() => _housesMode = false),
          ),
          ChoiceChip(
            label: const Text('บ้านเลขที่'),
            selected: _housesMode,
            onSelected: (_) async {
              setState(() => _housesMode = true);
              await _loadHouses();
            },
          ),
          if (_housesMode)
            DropdownButton<int?>(
              value: _laneId,
              hint: const Text('เลือกซอย/แยก'),
              items: [
                const DropdownMenuItem(value: null, child: Text('ทั้งหมด')),
                ..._lanes.map(
                  (r) => DropdownMenuItem(
                    value: (r['id'] as num).toInt(),
                    child: Text('${r['code']} ${r['name']}'),
                  ),
                ),
              ],
              onChanged: (v) async {
                setState(() => _laneId = v);
                await _loadHouses();
              },
            ),
          SizedBox(
            width: 260,
            child: TextField(
              controller: _search,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'ค้นหารหัสหรือชื่อ',
              ),
              onSubmitted: (_) =>
                  setState(() => _query = _search.text.trim().toLowerCase()),
            ),
          ),
          OutlinedButton(
            onPressed: () => setState(() {
              _search.clear();
              _query = '';
            }),
            child: const Text('ล้าง Filter'),
          ),
        ],
      ),
    ),
  );

  Widget _laneTable() {
    final rows = _lanes
        .where(
          (r) => '${r['code']} ${r['name']}'.toLowerCase().contains(_query),
        )
        .toList();
    return _table(
      ['รหัส', 'ชื่อ', 'ประเภท', 'สถานะ', 'Action'],
      rows
          .map(
            (r) => [
              r['code'],
              r['name'],
              r['type'] == 'JUNCTION' ? 'แยก' : 'ซอย',
              r['active'] == true ? 'ใช้งาน' : 'ไม่ใช้งาน',
              IconButton(
                onPressed: () => _editLane(r),
                icon: const Icon(Icons.edit_outlined),
              ),
            ],
          )
          .toList(),
    );
  }

  Widget _houseTable() {
    final rows = _houses
        .where(
          (r) =>
              '${r['houseNo']} ${r['laneName']}'.toLowerCase().contains(_query),
        )
        .toList();
    return _table(
      ['บ้านเลขที่', 'ซอย/แยก', 'ที่อยู่เพิ่มเติม', 'สถานะ', 'Action'],
      rows
          .map(
            (r) => [
              r['houseNo'],
              '${r['laneCode']} ${r['laneName']}',
              r['address'] ?? '-',
              r['active'] == true ? 'ใช้งาน' : 'ไม่ใช้งาน',
              Wrap(
                children: [
                  IconButton(
                    onPressed: () => _editHouse(r),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  TextButton(
                    onPressed: () => _showResidents(r),
                    child: const Text('ดูผู้อาศัย'),
                  ),
                ],
              ),
            ],
          )
          .toList(),
    );
  }

  Widget _table(List<String> headers, List<List<Object?>> rows) => Card(
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: headers.map((h) => DataColumn(label: Text(h))).toList(),
        rows: rows
            .map(
              (r) => DataRow(
                cells: r
                    .map((v) => DataCell(v is Widget ? v : Text('$v')))
                    .toList(),
              ),
            )
            .toList(),
      ),
    ),
  );
}
