import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';
import '../../../app/theme/workspace_theme_presets.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/navigation/navigation_menu_repository.dart';
import '../../../core/widgets/timed_snack_bar.dart';
import '../../support/presentation/widgets/support_workspace_shell.dart';
import '../ocr/business_card_ocr_api.dart';
import '../ocr/business_card_ocr_ui.dart';
import 'contact_api.dart';
import 'contact_ocr_customer_selection.dart';

String _contactError(Object error, String fallback) {
  if (error is ApiException) {
    final detail = error.description;
    return detail == null
        ? error.message
        : '${error.message}\nรายละเอียดเพิ่มเติม: $detail';
  }
  return '$fallback\nรายละเอียดเพิ่มเติม: กรุณาตรวจสอบการเชื่อมต่อและลองใหม่';
}

class ContactPage extends StatefulWidget {
  const ContactPage({super.key, this.supplier = false});
  final bool supplier;
  @override
  State<ContactPage> createState() => _ContactPageState();
}

class _ContactPageState extends State<ContactPage> {
  late final ContactApi _api;
  final _ocr = BusinessCardOcrApi(), _search = TextEditingController();
  String get _menuCode => widget.supplier ? '55003' : '55002';
  String get _route =>
      widget.supplier ? 'companySupplierContacts' : 'companyContacts';
  String get _target => widget.supplier ? 'suppliers' : 'contacts';
  final _customerSelection = GlobalKey<ContactOcrCustomerSelectionState>();
  String _caption = '', _query = '';
  Map<String, dynamic> _actions = {};
  Map<String, dynamic>? _capabilities;
  List<Map<String, dynamic>> _rows = [];
  int _total = 0;
  bool _loading = true;
  int _workspaceTab = 0;
  @override
  void initState() {
    super.initState();
    _api = ContactApi(supplier: widget.supplier);
    _loadCaption();
    _load();
  }

  @override
  void dispose() {
    _api.dispose();
    _ocr.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadCaption() async {
    final value = await NavigationMenuRepository().resolveMenuName(
      menuCode: _menuCode,
      routeName: _route,
    );
    if (mounted) setState(() => _caption = value);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _api.actions(),
        _api.reviewQueue(_query),
      ]);
      Map<String, dynamic>? capabilities;
      if (results[0]['create'] == true) {
        try {
          capabilities = Map<String, dynamic>.from(
            await _ocr.get('/api/company/ocr/business-cards/capabilities', {
                  'target': _target,
                  'action': 'CREATE',
                })
                as Map,
          );
        } catch (_) {
          capabilities = null;
        }
      }
      if (!mounted) return;
      final data = results[1];
      setState(() {
        _actions = results[0];
        _rows = List<Map<String, dynamic>>.from(data['items'] as List);
        _total = _rows.length;
        _capabilities = capabilities;
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

  Future<BusinessCardSaveOutcome> _saveBusinessCard(
    BusinessCardImport result,
  ) async {
    final selection = _customerSelection.currentState;
    final validation =
        selection?.validate(result.values) ??
        (selection == null
            ? (widget.supplier
                  ? 'กรุณารอให้โหลดข้อมูลผู้ขายสำเร็จ'
                  : 'กรุณารอให้โหลดข้อมูลลูกค้าสำเร็จ')
            : null);
    if (validation != null) {
      if (mounted)
        showTimedSnackBar(
          context,
          message: 'บันทึกข้อมูลไม่สำเร็จ\nรายละเอียดเพิ่มเติม: $validation',
          error: true,
        );
      return BusinessCardSaveOutcome.failure;
    }
    try {
      await _api.saveDraft(
        {
          'name': result.values['name']?.trim() ?? '',
          'phone': result.values['phone'],
          'email': result.values['email'],
          'company': result.values['company'],
          'position': result.values['position'],
          'address': result.values['address'],
          'website': result.values['website'],
          'line': result.values['line'],
          'isActive': true,
          'customerId': selection!.mode == 'existing'
              ? selection.customerId
              : null,
          'createCustomer': selection.mode == 'new',
          'fromOcr': true,
        },
        result.images
            .map((e) => BusinessCardImageValue(e.bytes, e.name))
            .toList(),
      );
      return BusinessCardSaveOutcome.saved;
    } catch (error) {
      if (mounted)
        showTimedSnackBar(
          context,
          message: _contactError(error, 'บันทึกแบบร่างไม่สำเร็จ'),
          error: true,
        );
      return BusinessCardSaveOutcome.failure;
    }
  }

  Future<void> _removeDraft(Map<String, dynamic> row) async {
    final errorColor = Theme.of(context).colorScheme.error;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(color: errorColor),
        ),
        title: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: errorColor.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(Icons.delete_outline, color: errorColor),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'ยืนยันการลบข้อมูล',
                style: TextStyle(
                  color: errorColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: errorColor.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Text('${row['name'] ?? ''}'),
              ),
            ),
            const SizedBox(height: 12),
            const Text('ต้องการลบแบบร่างนี้หรือไม่ เมื่อลบแล้วเรียกคืนไม่ได้'),
            const SizedBox(height: 12),
            const Divider(height: 1),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialog, true),
            style: FilledButton.styleFrom(backgroundColor: errorColor),
            icon: const Icon(Icons.delete_outline),
            label: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _api.deleteDraft((row['reviewId'] as num).toInt());
      if (!mounted) return;
      showTimedSnackBar(context, message: 'ลบแบบร่างแล้ว');
      await _load();
    } catch (error) {
      if (mounted)
        showTimedSnackBar(
          context,
          message: _contactError(error, 'ลบแบบร่างไม่สำเร็จ'),
          error: true,
        );
    }
  }

  Future<void> _showDraft(Map<String, dynamic> row) async {
    try {
      final data = await _api.draftDetails((row['reviewId'] as num).toInt());
      if (!mounted) return;
      final contact = Map<String, dynamic>.from(data['contact'] as Map);
      final images = (data['images'] as List).cast<Map>();
      await showDialog<void>(
        context: context,
        builder: (dialog) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          title: const Text('ข้อมูลนามบัตร'),
          content: SizedBox(
            width: 700,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final image in images)
                        Image.memory(
                          base64Decode('${image['data']}'),
                          height: 180,
                          fit: BoxFit.contain,
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  for (final entry in {
                    'name': 'ชื่อผู้ติดต่อ',
                    'company': 'บริษัท',
                    'position': 'ตำแหน่ง',
                    'phone': 'โทรศัพท์',
                    'email': 'อีเมล',
                    'address': 'ที่อยู่',
                    'website': 'เว็บไซต์',
                    'line': 'LINE ID',
                  }.entries)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        '${entry.value}: ${contact[entry.key] ?? '-'}',
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog),
              child: const Text('ปิด'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted)
        showTimedSnackBar(
          context,
          message: _contactError(error, 'โหลดข้อมูลนามบัตรไม่สำเร็จ'),
          error: true,
        );
    }
  }

  @override
  Widget build(BuildContext context) =>
      ValueListenableBuilder<WorkspaceThemePreset>(
        valueListenable: workspaceThemeController,
        builder: (context, _, _) => SupportWorkspaceShell(
          pageTitle: _caption,
          activeMenu: _route,
          menuScope: WorkspaceMenuScope.company,
          child: LayoutBuilder(
            builder: (context, box) => _reviewWorkspace(
              businessCardOcrUi(context),
              box.maxWidth < 1100,
            ),
          ),
        ),
      );
  Widget _reviewWorkspace(LaooWorkspaceUiTokens t, bool compact) {
    final list = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LaooSurfaceCard(
          tokens: t,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('รายการนามบัตร ($_total)', style: t.sectionStyle),
              const Text('แบบร่างและรายการที่ส่งตรวจสอบ'),
              const SizedBox(height: 12),
              TextField(
                controller: _search,
                style: t.inputStyle,
                decoration: ocrInput(
                  context,
                  'ค้นหาชื่อ บริษัท โทรศัพท์ หรืออีเมล',
                  icon: Icons.search,
                ),
                onSubmitted: (_) {
                  _query = _search.text.trim();
                  _load();
                },
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: _loading
                        ? null
                        : () {
                            _query = _search.text.trim();
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
                            _load();
                          },
                    child: const Text('ล้าง Filter'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        LaooSurfaceCard(
          tokens: t,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _rows.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('ไม่มีรายการนามบัตร'),
                  ),
                )
              : Column(
                  children: [
                    for (final row in _rows)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ListTile(
                            title: Text('${row['company'] ?? '-'}'),
                            onTap: () => _showDraft(row),
                            subtitle: Text(
                              [row['name'], row['phone'], row['email']]
                                  .where((v) => v != null && '$v'.isNotEmpty)
                                  .join(' • '),
                            ),
                            trailing: Text(
                              row['status'] == 'DRAFT'
                                  ? 'แบบร่าง'
                                  : 'รอตรวจสอบ',
                            ),
                          ),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (row['canSend'] == true)
                                OutlinedButton(
                                  onPressed: () async {
                                    try {
                                      await _api.sendDraft(
                                        (row['reviewId'] as num).toInt(),
                                      );
                                      if (!mounted) return;
                                      showTimedSnackBar(
                                        context,
                                        message: 'ส่งตรวจสอบแล้ว',
                                      );
                                      await _load();
                                    } catch (error) {
                                      if (mounted)
                                        showTimedSnackBar(
                                          context,
                                          message: _contactError(
                                            error,
                                            'ส่งตรวจสอบไม่สำเร็จ',
                                          ),
                                          error: true,
                                        );
                                    }
                                  },
                                  child: const Text('ส่งตรวจสอบ'),
                                ),
                              if (row['canDelete'] == true)
                                OutlinedButton.icon(
                                  onPressed: () => _removeDraft(row),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Theme.of(
                                      context,
                                    ).colorScheme.error,
                                    side: BorderSide(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.error,
                                    ),
                                  ),
                                  icon: Icon(
                                    Icons.delete_outline,
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                  label: const Text('ลบ'),
                                ),
                              if (row['canReview'] == true)
                                OutlinedButton(
                                  onPressed: () async {
                                    try {
                                      await _api.completeReview(
                                        (row['reviewId'] as num).toInt(),
                                      );
                                      if (!mounted) return;
                                      showTimedSnackBar(
                                        context,
                                        message: 'ตรวจสอบเรียบร้อยแล้ว',
                                      );
                                      await _load();
                                    } catch (error) {
                                      if (mounted)
                                        showTimedSnackBar(
                                          context,
                                          message: _contactError(
                                            error,
                                            'ตรวจสอบไม่สำเร็จ',
                                          ),
                                          error: true,
                                        );
                                    }
                                  },
                                  child: const Text('ตรวจสอบเสร็จ'),
                                ),
                            ],
                          ),
                          Divider(color: t.borderColor),
                        ],
                      ),
                  ],
                ),
        ),
      ],
    );
    final caps = _capabilities;
    final ocr = _actions['create'] == true && caps?['isEnabled'] == true
        ? BusinessCardOcrPage(
            key: const ValueKey('contact-inline-ocr'),
            tokens: t,
            target: _target,
            get: _ocr.get,
            upload: _ocr.upload,
            notify: (ctx, message, error) =>
                showTimedSnackBar(ctx, message: message, error: error),
            maxImageSizeMB: (caps?['maxImageSizeMB'] as num?)?.toInt() ?? 10,
            engineAvailable: caps?['engineAvailable'] == true,
            embedded: true,
            extraReview: ContactOcrCustomerSelection(
              key: _customerSelection,
              api: _api,
              supplier: widget.supplier,
            ),
            onSave: _saveBusinessCard,
            onCompleted: (_) async {
              if (mounted) {
                showTimedSnackBar(context, message: 'บันทึกแบบร่างแล้ว');
                await _load();
                if (mounted) setState(() => _workspaceTab = 1);
              }
            },
          )
        : const Center(
            child: Text('ไม่มีสิทธิ์เพิ่มข้อมูล หรือ OCR ยังไม่พร้อมใช้งาน'),
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LaooCaptionCard(
          tokens: t,
          caption: _caption,
          favoriteKey: _menuCode,
          leading: Icon(Icons.contacts_outlined, color: t.primaryColor),
        ),
        const SizedBox(height: 8),
        LaooSurfaceCard(
          tokens: t,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tab in [
                const MapEntry(0, 'ข้อมูลนามบัตรที่สแกน'),
                const MapEntry(1, 'รายการนามบัตร'),
              ])
                ChoiceChip(
                  label: Text(tab.value),
                  selected: _workspaceTab == tab.key,
                  selectedColor: t.primaryColor.withValues(alpha: .12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(t.radius),
                  ),
                  onSelected: (_) => setState(() => _workspaceTab = tab.key),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: IndexedStack(
            index: _workspaceTab,
            children: [
              ocr,
              SingleChildScrollView(child: list),
            ],
          ),
        ),
      ],
    );
  }
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
              style: t.tableStyle,
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
              style: t.tableStyle,
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
                style: t.inputStyle,
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
                ).copyWith(counterText: ''),
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
