import 'package:flutter/material.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/navigation/navigation_menu_repository.dart';
import '../../../core/widgets/timed_snack_bar.dart';
import '../../support/presentation/widgets/support_workspace_shell.dart';
import '../ocr/business_card_ocr_api.dart';
import '../ocr/business_card_ocr_ui.dart';
import 'contact_api.dart';

String _contactError(Object error, String fallback) {
  if (error is ApiException) {
    return '${error.message}\nรายละเอียดเพิ่มเติม: ${error.description ?? fallback}';
  }
  return '$fallback\nรายละเอียดเพิ่มเติม: $error';
}

class ContactPage extends StatefulWidget {
  const ContactPage({super.key});
  @override
  State<ContactPage> createState() => _ContactPageState();
}

class _ContactPageState extends State<ContactPage> {
  final _api = ContactApi(), _search = TextEditingController();
  String _caption = '', _query = '';
  Map<String, dynamic> _actions = {};
  List<Map<String, dynamic>> _rows = [];
  int _page = 1, _total = 0;
  static const _pageSize = 20;
  bool _loading = true, _cards = false;
  @override
  void initState() {
    super.initState();
    _loadCaption();
    _load();
  }

  @override
  void dispose() {
    _api.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadCaption() async {
    final value = await NavigationMenuRepository().resolveMenuName(
      menuCode: '55002',
      routeName: 'companyContacts',
    );
    if (mounted) setState(() => _caption = value);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _api.actions(),
        _api.list(search: _query, page: _page, pageSize: _pageSize),
      ]);
      if (!mounted) return;
      final data = results[1];
      setState(() {
        _actions = results[0];
        _rows = List<Map<String, dynamic>>.from(data['items'] as List);
        _total = (data['total'] as num).toInt();
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() => _loading = false);
        showTimedSnackBar(
          context,
          message: _contactError(error, 'โหลดทะเบียนผู้ติดต่อไม่สำเร็จ'),
          error: true,
        );
      }
    }
  }

  Future<void> _open([Map<String, dynamic>? row]) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ContactForm(
        api: _api,
        caption: _caption,
        initial: row,
        onSaved: () {
          showTimedSnackBar(context, message: 'บันทึกทะเบียนผู้ติดต่อแล้ว');
          _load();
        },
      ),
    );
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    final danger = Theme.of(context).colorScheme.error;
    final ok =
        await showDialog<bool>(
          context: context,
          builder: (dialog) => AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
              side: BorderSide(color: danger),
            ),
            title: Row(
              children: [
                Icon(Icons.delete_outline, color: danger),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'ยืนยันการลบข้อมูล',
                    style: TextStyle(
                      color: danger,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
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
                  color: danger.withValues(alpha: .1),
                  child: Text((row['name'] ?? '').toString()),
                ),
                const SizedBox(height: 12),
                const Text('เมื่อลบแล้วจะไม่สามารถเรียกคืนได้'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialog, false),
                child: const Text('ยกเลิก'),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: danger,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                onPressed: () => Navigator.pop(dialog, true),
                icon: const Icon(Icons.delete_outline),
                label: const Text('ลบ'),
              ),
            ],
          ),
        ) ??
        false;
    if (!ok) return;
    try {
      await _api.delete(
        (row['contactId'] as num).toInt(),
        row['rowVersion'].toString(),
      );
      if (mounted) {
        showTimedSnackBar(context, message: 'ลบผู้ติดต่อแล้ว');
        await _load();
      }
    } catch (error) {
      if (mounted) {
        showTimedSnackBar(
          context,
          message: _contactError(error, 'ลบผู้ติดต่อไม่สำเร็จ'),
          error: true,
        );
      }
    }
  }

  Widget _rowActions(Map<String, dynamic> row) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (_actions['edit'] == true)
        IconButton(
          tooltip: 'แก้ไข',
          color: businessCardOcrUi(context).primaryColor,
          onPressed: () => _open(row),
          icon: const Icon(Icons.edit_outlined),
        ),
      if (_actions['delete'] == true)
        IconButton(
          tooltip: 'ลบ',
          color: Theme.of(context).colorScheme.error,
          onPressed: () => _delete(row),
          icon: const Icon(Icons.delete_outline),
        ),
    ],
  );
  Widget _result(bool cards) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_rows.isEmpty) return const Center(child: Text('ไม่พบข้อมูลผู้ติดต่อ'));
    if (cards) {
      return ListView.separated(
        itemCount: _rows.length,
        separatorBuilder: (_, _) => const SizedBox(height: 6),
        itemBuilder: (_, i) {
          final row = _rows[i];
          return LaooSurfaceCard(
            tokens: businessCardOcrUi(context),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (row['name'] ?? '').toString(),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        [
                          (row['company'] ?? ''),
                          (row['position'] ?? ''),
                        ].where((e) => e.toString().isNotEmpty).join(' • '),
                      ),
                      Text(
                        [
                          (row['phone'] ?? ''),
                          (row['email'] ?? ''),
                        ].where((e) => e.toString().isNotEmpty).join(' • '),
                      ),
                      Text(row['isActive'] == true ? 'ใช้งาน' : 'ไม่ใช้งาน'),
                    ],
                  ),
                ),
                _rowActions(row),
              ],
            ),
          );
        },
      );
    }
    return LaooWorkspaceDataTable(
      tokens: businessCardOcrUi(context),
      columns: const [
        LaooWorkspaceTableColumns.id,
        DataColumn(label: Text('Action')),
        DataColumn(label: Text('ชื่อผู้ติดต่อ')),
        DataColumn(label: Text('บริษัท')),
        DataColumn(label: Text('ตำแหน่ง')),
        DataColumn(label: Text('โทรศัพท์')),
        DataColumn(label: Text('อีเมล')),
        DataColumn(label: Text('สถานะ')),
      ],
      rows: [
        for (var i = 0; i < _rows.length; i++)
          DataRow(
            cells: [
              DataCell(Text(((_page - 1) * _pageSize + i + 1).toString())),
              DataCell(_rowActions(_rows[i])),
              DataCell(Text((_rows[i]['name'] ?? '').toString())),
              DataCell(Text((_rows[i]['company'] ?? '').toString())),
              DataCell(Text((_rows[i]['position'] ?? '').toString())),
              DataCell(Text((_rows[i]['phone'] ?? '').toString())),
              DataCell(Text((_rows[i]['email'] ?? '').toString())),
              DataCell(
                Text(_rows[i]['isActive'] == true ? 'ใช้งาน' : 'ไม่ใช้งาน'),
              ),
            ],
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => SupportWorkspaceShell(
    pageTitle: _caption,
    activeMenu: 'companyContacts',
    menuScope: WorkspaceMenuScope.company,
    child: LayoutBuilder(
      builder: (context, box) {
        final compact = box.maxWidth < 900, t = businessCardOcrUi(context);
        final pages = _total == 0 ? 1 : (_total / _pageSize).ceil();
        return ColoredBox(
          color: t.backgroundColor,
          child: LaooListWorkspace(
            tokens: t,
            caption: LaooCaptionCard(
              tokens: t,
              caption: _caption,
              favoriteKey: '55002',
              leading: Icon(Icons.contacts_outlined, color: t.primaryColor),
              trailing: Wrap(
                spacing: 8,
                children: [
                  if (!compact)
                    LaooListCardToggle(
                      tokens: t,
                      cards: _cards,
                      onChanged: (v) => setState(() => _cards = v),
                    ),
                  if (_actions['create'] == true)
                    FilledButton.icon(
                      onPressed: () => _open(),
                      icon: const Icon(Icons.add),
                      label: const Text('เพิ่ม'),
                    ),
                ],
              ),
            ),
            filter: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                SizedBox(
                  width: compact ? box.maxWidth - 40 : 280,
                  child: TextField(
                    controller: _search,
                    decoration: ocrInput(
                      context,
                      'ค้นหาชื่อ บริษัท โทรศัพท์ หรืออีเมล',
                      icon: Icons.search,
                    ),
                    onSubmitted: (_) {
                      _query = _search.text.trim();
                      _page = 1;
                      _load();
                    },
                  ),
                ),
                FilledButton.icon(
                  onPressed: _loading
                      ? null
                      : () {
                          _query = _search.text.trim();
                          _page = 1;
                          _load();
                        },
                  icon: const Icon(Icons.search),
                  label: const Text('ค้นหา'),
                ),
                OutlinedButton(
                  onPressed: _loading
                      ? null
                      : () {
                          _search.clear();
                          _query = '';
                          _page = 1;
                          _load();
                        },
                  child: const Text('ล้าง Filter'),
                ),
              ],
            ),
            table: _result(compact || _cards),
            pagination: LaooPaginationCard(
              tokens: t,
              page: _page,
              pageCount: pages,
              pageSize: _pageSize,
              total: _total,
              onPrevious: _page > 1
                  ? () {
                      setState(() => _page--);
                      _load();
                    }
                  : null,
              onNext: _page < pages
                  ? () {
                      setState(() => _page++);
                      _load();
                    }
                  : null,
            ),
          ),
        );
      },
    ),
  );
}

class ContactForm extends StatefulWidget {
  const ContactForm({
    required this.api,
    required this.caption,
    required this.onSaved,
    this.initial,
    super.key,
  });
  final ContactApi api;
  final String caption;
  final VoidCallback onSaved;
  final Map<String, dynamic>? initial;
  @override
  State<ContactForm> createState() => _ContactFormState();
}

class _ContactFormState extends State<ContactForm> {
  final _form = GlobalKey<FormState>(), _ocr = BusinessCardOcrApi();
  late final Map<String, TextEditingController> _fields = {
    for (final e in const {
      'name': 'ชื่อผู้ติดต่อ',
      'phone': 'โทรศัพท์',
      'email': 'อีเมล',
      'company': 'ชื่อบริษัท',
      'position': 'ตำแหน่ง',
      'address': 'ที่อยู่',
      'website': 'เว็บไซต์',
      'line': 'LINE ID',
    }.entries)
      e.key: TextEditingController(
        text: (widget.initial?[e.key] ?? '').toString(),
      ),
  };
  List<Map<String, dynamic>> _persons = [], _customers = [];
  final _images = <BusinessCardImageValue>[];
  int? _personId, _customerId, _savedId;
  String? _personVersion;
  bool _active = true, _saving = false, _loading = true;
  bool get _adding => widget.initial == null;
  @override
  void initState() {
    super.initState();
    _personId = (widget.initial?['personId'] as num?)?.toInt();
    _customerId = (widget.initial?['customerId'] as num?)?.toInt();
    _personVersion = widget.initial?['personRowVersion']?.toString();
    _active = widget.initial?['isActive'] as bool? ?? true;
    _loadLookups();
  }

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    _ocr.dispose();
    super.dispose();
  }

  Future<void> _loadLookups() async {
    try {
      final r = await widget.api.lookups(
        personId: _personId,
        customerId: _customerId,
      );
      if (mounted) {
        setState(() {
          _persons = List<Map<String, dynamic>>.from(
            r['persons'] as List? ?? [],
          );
          _customers = List<Map<String, dynamic>>.from(
            r['customers'] as List? ?? [],
          );
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _loading = false);
        showTimedSnackBar(
          context,
          message: _contactError(error, 'โหลดข้อมูลอ้างอิงไม่สำเร็จ'),
          error: true,
        );
      }
    }
  }

  Future<void> _import(BusinessCardImport result) async {
    final changes = {
      for (final e in result.values.entries)
        if (_fields.containsKey(e.key)) e.key: e.value,
    };
    if (!await confirmBusinessCardChanges(
      context,
      businessCardOcrUi(context),
      {for (final e in _fields.entries) e.key: e.value.text},
      changes,
      {for (final e in businessCardFields.entries) e.key: e.value},
    )) {
      return;
    }
    if (!mounted) return;
    setState(() {
      for (final e in changes.entries) {
        _fields[e.key]!.text = e.value;
      }
      _images
        ..clear()
        ..addAll(
          result.images.map((e) => BusinessCardImageValue(e.bytes, e.name)),
        );
    });
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false) || _saving) return;
    setState(() => _saving = true);
    bool recordSaved = false;
    try {
      final response = await widget.api.save({
        for (final e in _fields.entries) e.key: e.value.text.trim(),
        'isActive': _active,
        'personId': _personId,
        'customerId': _customerId,
        'rowVersion': widget.initial?['rowVersion'],
        'personRowVersion': _personVersion,
      }, id: (widget.initial?['contactId'] as num?)?.toInt() ?? _savedId);
      _savedId = (response['contactId'] as num).toInt();
      recordSaved = true;
      while (_images.isNotEmpty) {
        await widget.api.upload(_savedId!, _images.first);
        _images.removeAt(0);
      }
      widget.onSaved();
      if (!mounted) return;
      if (_adding) {
        for (final c in _fields.values) {
          c.clear();
        }
        setState(() {
          _active = true;
          _personId = null;
          _customerId = null;
          _personVersion = null;
          _savedId = null;
        });
      } else {
        Navigator.pop(context);
      }
    } catch (error) {
      if (mounted) {
        showTimedSnackBar(
          context,
          message: recordSaved
              ? 'บันทึกผู้ติดต่อแล้ว แต่แนบภาพยังไม่ครบ\nรายละเอียดเพิ่มเติม: กดบันทึกเพื่อลองแนบภาพที่เหลืออีกครั้ง'
              : _contactError(error, 'บันทึกผู้ติดต่อไม่สำเร็จ'),
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = businessCardOcrUi(context);
    if (_loading) return const Center(child: CircularProgressIndicator());
    return LaooActionDialog(
      tokens: t,
      icon: Icons.contacts_outlined,
      title: '${widget.caption} > ${_adding ? 'เพิ่ม' : 'แก้ไข'}',
      content: Form(
        key: _form,
        child: Column(
          children: [
            Row(
              children: [
                const Text('สถานะ'),
                const SizedBox(width: 8),
                Switch(
                  value: _active,
                  onChanged: _saving
                      ? null
                      : (v) => setState(() => _active = v),
                ),
                const Spacer(),
                BusinessCardOcrButton(
                  tokens: t,
                  target: 'contacts',
                  recordId:
                      (widget.initial?['contactId'] as num?)?.toInt() ??
                      _savedId,
                  enabled: !_saving,
                  get: _ocr.get,
                  upload: _ocr.upload,
                  notify: (ctx, message, error) =>
                      showTimedSnackBar(ctx, message: message, error: error),
                  onImported: _import,
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int?>(
              initialValue: _personId,
              isExpanded: true,
              decoration: ocrInput(context, 'เชื่อมบุคคลเดิม'),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('สร้างบุคคลใหม่'),
                ),
                for (final p in _persons)
                  DropdownMenuItem(
                    value: (p['id'] as num).toInt(),
                    child: Text((p['name'] ?? '').toString()),
                  ),
              ],
              onChanged: _saving
                  ? null
                  : (v) {
                      setState(() => _personId = v);
                      if (v != null) {
                        final p = _persons.firstWhere(
                          (x) => (x['id'] as num).toInt() == v,
                        );
                        _fields['name']!.text = (p['name'] ?? '').toString();
                        _fields['phone']!.text = (p['phone'] ?? '').toString();
                        _fields['email']!.text = (p['email'] ?? '').toString();
                        _personVersion = p['rowVersion']?.toString();
                      }
                    },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int?>(
              initialValue: _customerId,
              isExpanded: true,
              decoration: ocrInput(context, 'เชื่อมลูกค้า'),
              items: [
                const DropdownMenuItem<int?>(
                  value: null,
                  child: Text('ไม่เชื่อมลูกค้า'),
                ),
                for (final c in _customers)
                  DropdownMenuItem(
                    value: (c['id'] as num).toInt(),
                    child: Text((c['name'] ?? '').toString()),
                  ),
              ],
              onChanged: _saving
                  ? null
                  : (v) => setState(() => _customerId = v),
            ),
            for (final e in _fields.entries) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: e.value,
                maxLines: e.key == 'address' ? 3 : 1,
                maxLength: e.key == 'address'
                    ? 1000
                    : e.key == 'email'
                    ? 320
                    : e.key == 'website'
                    ? 500
                    : e.key == 'company'
                    ? 250
                    : e.key == 'line'
                    ? 100
                    : 200,
                keyboardType: e.key == 'email'
                    ? TextInputType.emailAddress
                    : e.key == 'phone'
                    ? TextInputType.phone
                    : null,
                decoration: ocrInput(
                  context,
                  (businessCardFields[e.key] ?? e.key) +
                      (e.key == 'name' ? ' *' : ''),
                ),
                validator: e.key == 'name'
                    ? (v) => v == null || v.trim().isEmpty
                          ? 'กรุณาระบุชื่อผู้ติดต่อ'
                          : null
                    : null,
              ),
            ],
          ],
        ),
      ),
      actions: [
        OutlinedButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('ยกเลิก'),
        ),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: const Icon(Icons.save_outlined),
          label: Text(_saving ? 'กำลังบันทึก…' : 'บันทึก'),
        ),
      ],
    );
  }
}
