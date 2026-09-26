import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;

import '../../../app/theme/laoo_design_tokens.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/navigation/navigation_menu_repository.dart';
import '../../../core/widgets/timed_snack_bar.dart';
import '../../support/presentation/widgets/support_workspace_shell.dart';
import '../data/service_request_api.dart';
import '../../service_request_qr/data/service_request_qr_api.dart';

class ServiceRequestPage extends StatefulWidget {
  const ServiceRequestPage({
    super.key,
    this.selfService = false,
    this.qrToken,
    this.readOnly = false,
    this.menuCode,
    this.routeName,
  });
  final bool selfService;
  final String? qrToken;
  final bool readOnly;
  final String? menuCode;
  final String? routeName;
  @override
  State<ServiceRequestPage> createState() => _ServiceRequestPageState();
}

class _ServiceRequestPageState extends State<ServiceRequestPage> {
  final _api = ServiceRequestApi();
  final _search = TextEditingController();
  String _status = '';
  int _page = 1;
  bool _loading = true;
  bool _canCreate = false;
  bool _canEdit = false;
  String _menuName = 'รายการแจ้งซ่อมทั้งหมด';
  Map<String, dynamic> _data = const {'items': <dynamic>[], 'total': 0};

  @override
  void initState() {
    super.initState();
    if (widget.selfService) _menuName = 'แจ้งซ่อม / ขอใช้บริการ';
    _load();
    _loadActions();
    _loadMenuName();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final value = await _api.list(
        search: _search.text.trim(),
        status: _status,
        selfService: widget.selfService,
        page: _page,
      );
      if (mounted) setState(() => _data = value);
    } catch (error) {
      if (mounted) _message(error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadActions() async {
    try {
      final actions = await _api.actions();
      if (mounted) {
        setState(() {
          _canCreate = !widget.readOnly && widget.selfService
              ? actions['selfCreate'] == true
              : !widget.readOnly && actions['create'] == true;
          _canEdit =
              !widget.readOnly &&
              !widget.selfService &&
              actions['edit'] == true;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadMenuName() async {
    try {
      final name = await NavigationMenuRepository().resolveMenuName(
        menuCode: widget.menuCode ?? (widget.selfService ? '20001' : '15001'),
        routeName:
            widget.routeName ??
            (widget.selfService ? 'portalRequest' : 'cmTickets'),
        fallback: _menuName,
      );
      if (mounted) setState(() => _menuName = name);
    } catch (_) {}
  }

  void _message(Object error, {bool errorState = true}) {
    final text = error is ApiException
        ? '${error.message}\n${error.description ?? 'กรุณาตรวจสอบข้อมูลแล้วลองใหม่อีกครั้ง'}'
        : 'ไม่สามารถดำเนินการได้\nกรุณาลองใหม่อีกครั้ง';
    showTimedSnackBar(context, message: text, error: errorState);
  }

  Future<void> _create() async {
    final lookup = await _api.lookup();
    if (!mounted) return;
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _RequestDialog(
        api: _api,
        lookup: lookup,
        selfService: widget.selfService,
        qrToken: widget.qrToken,
      ),
    );
    if (saved == true && mounted) {
      _page = 1;
      await _load();
      if (!mounted) return;
      showTimedSnackBar(context, message: 'บันทึกใบแจ้งซ่อมเรียบร้อยแล้ว');
    }
  }

  Future<void> _openDetail(Map<String, dynamic> row) async {
    final id = (row['requestId'] as num?)?.toInt();
    if (id == null) return;
    try {
      final detail = await _api.detail(id);
      if (!mounted) return;
      final attachments = await _api.attachments(id);
      if (!mounted) return;
      final changed = await showDialog<bool>(
        context: context,
        builder: (_) => _RequestDetailDialog(
          api: _api,
          data: detail,
          attachments: attachments,
          canEdit: _canEdit,
        ),
      );
      if (changed == true) await _load();
    } catch (error) {
      if (mounted) _message(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = List<Map<String, dynamic>>.from(
      (_data['items'] as List? ?? const []).map(
        (e) => Map<String, dynamic>.from(e as Map),
      ),
    );
    final total = (_data['total'] as num?)?.toInt() ?? 0;
    return SupportWorkspaceShell(
      pageTitle: _menuName,
      activeMenu:
          widget.routeName ??
          (widget.selfService ? 'portalRequest' : 'cmTickets'),
      menuScope: WorkspaceMenuScope.company,
      child: Container(
        width: double.infinity,
        color: Colors.white,
        padding: const EdgeInsets.all(LaooLayout.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 10,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.build_outlined),
                    const SizedBox(width: 10),
                    Text(
                      _menuName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                if (_canCreate)
                  FilledButton.icon(
                    onPressed: _create,
                    icon: const Icon(Icons.add),
                    label: Text(
                      widget.selfService ? 'แจ้งซ่อม' : 'เพิ่มใบแจ้งซ่อม',
                    ),
                  ),
              ],
            ),
            const Divider(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 300,
                  child: TextField(
                    controller: _search,
                    onSubmitted: (_) {
                      _page = 1;
                      _load();
                    },
                    decoration: _input(
                      hint: 'ค้นหาเลขที่ ผู้แจ้ง หัวข้อ หรือสถานที่',
                      icon: Icons.search,
                    ),
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<String>(
                    initialValue: _status,
                    decoration: _input(label: 'สถานะ'),
                    items: const [
                      DropdownMenuItem(value: '', child: Text('ทั้งหมด')),
                      DropdownMenuItem(value: 'NEW', child: Text('สร้างใหม่')),
                      DropdownMenuItem(
                        value: 'RECEIVED',
                        child: Text('รับเรื่องแล้ว'),
                      ),
                      DropdownMenuItem(
                        value: 'IN_PROGRESS',
                        child: Text('กำลังดำเนินการ'),
                      ),
                      DropdownMenuItem(
                        value: 'COMPLETED',
                        child: Text('เสร็จสิ้น'),
                      ),
                      DropdownMenuItem(
                        value: 'CANCELLED',
                        child: Text('ยกเลิก'),
                      ),
                    ],
                    onChanged: (value) {
                      _status = value ?? '';
                      _page = 1;
                      _load();
                    },
                  ),
                ),
                FilledButton.icon(
                  onPressed: () {
                    _page = 1;
                    _load();
                  },
                  icon: const Icon(Icons.search),
                  label: const Text('ค้นหา'),
                ),
                OutlinedButton(
                  onPressed: () {
                    _search.clear();
                    _status = '';
                    _page = 1;
                    _load();
                  },
                  child: const Text('ล้าง Filter'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_loading) const LinearProgressIndicator(),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('เลขที่')),
                  DataColumn(label: Text('ผู้แจ้ง')),
                  DataColumn(label: Text('สถานที่')),
                  DataColumn(label: Text('หัวข้อ')),
                  DataColumn(label: Text('สถานะ')),
                  DataColumn(label: Text('วันที่')),
                ],
                rows: [
                  for (final row in items)
                    DataRow(
                      cells: [
                        DataCell(
                          InkWell(
                            onTap: () => _openDetail(row),
                            child: Text(
                              row['requestNo']?.toString() ?? '-',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                        DataCell(Text(row['requesterName']?.toString() ?? '-')),
                        DataCell(
                          Text(row['locationSnapshot']?.toString() ?? '-'),
                        ),
                        DataCell(Text(row['subject']?.toString() ?? '-')),
                        DataCell(
                          Text(
                            _statusText(row['statusCode']?.toString() ?? ''),
                          ),
                        ),
                        DataCell(Text(row['requestDate']?.toString() ?? '-')),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _pagination(total),
          ],
        ),
      ),
    );
  }

  Widget _pagination(int total) {
    final pages = total == 0 ? 1 : (total / 20).ceil();
    final end = (_page * 20).clamp(0, total);
    final range = total == 0
        ? '0-0 จาก 0'
        : '${_page == 1 ? '1-' : '${((_page - 1) * 20) + 1}-'}$end จาก $total';
    return SizedBox(
      height: LaooLayout.paginationCardHeight,
      child: Wrap(
        spacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          OutlinedButton(
            onPressed: _page > 1
                ? () {
                    _page--;
                    _load();
                  }
                : null,
            child: const Text('<'),
          ),
          FilledButton(onPressed: null, child: Text(_page.toString())),
          OutlinedButton(
            onPressed: _page < pages
                ? () {
                    _page++;
                    _load();
                  }
                : null,
            child: const Text('>'),
          ),
          const SizedBox(width: 6),
          Text(range),
        ],
      ),
    );
  }

  InputDecoration _input({String? label, String? hint, IconData? icon}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon == null ? null : Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(LaooRadius.xs),
        ),
      );

  String _statusText(String code) =>
      const {
        'NEW': 'สร้างใหม่',
        'RECEIVED': 'รับเรื่องแล้ว',
        'IN_PROGRESS': 'กำลังดำเนินการ',
        'COMPLETED': 'เสร็จสิ้น',
        'CANCELLED': 'ยกเลิก',
      }[code] ??
      code;
}

class _RequestDialog extends StatefulWidget {
  const _RequestDialog({
    required this.api,
    this.lookup,
    this.selfService = false,
    this.qrToken,
  });
  final ServiceRequestApi api;
  final Map<String, dynamic>? lookup;
  final bool selfService;
  final String? qrToken;
  @override
  State<_RequestDialog> createState() => _RequestDialogState();
}

class _RequestDialogState extends State<_RequestDialog> {
  final _form = GlobalKey<FormState>();
  final _subject = TextEditingController();
  final _detail = TextEditingController();
  Map<String, dynamic>? _requester;
  Map<String, dynamic>? _equipment;
  Map<String, dynamic>? _qrContext;
  String? _subjectCode;
  final List<PlatformFile> _attachments = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadQrContext();
  }

  Future<void> _loadQrContext() async {
    final token = widget.qrToken?.trim();
    if (token == null || token.isEmpty) return;
    try {
      final value = await ServiceRequestQrApi().scan(token);
      if (!mounted) return;
      setState(() {
        _qrContext = value;
        _equipment = {
          'itemID': value['itemId'],
          'itemCode': value['itemCode'],
          'itemName': value['itemName'],
        };
      });
    } catch (error) {
      if (mounted)
        showTimedSnackBar(
          context,
          message: error is ApiException
              ? '${error.message}\n${error.description ?? 'กรุณาลองใหม่'}'
              : 'ไม่สามารถอ่าน QR Code ได้',
          error: true,
        );
    }
  }

  @override
  void dispose() {
    _subject.dispose();
    _detail.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate() || _saving) return;
    setState(() => _saving = true);
    try {
      final created = await widget.api.create(
        selfService: widget.selfService,
        requesterId: (_requester?['id'] as num?)?.toInt(),
        requesterType: _requester?['requesterType']?.toString(),
        equipmentItemId: (_equipment?['itemID'] as num?)?.toInt(),
        subject: _subject.text.trim(),
        detail: _detail.text.trim(),
        qrToken: widget.qrToken,
      );
      final requestId = (created['requestId'] as num?)?.toInt();
      final uploadErrors = <String>[];
      if (requestId != null) {
        for (final file in _attachments) {
          final bytes = file.bytes;
          if (bytes == null) {
            uploadErrors.add(file.name);
            continue;
          }
          try {
            await widget.api.uploadAttachment(
              requestId,
              fileName: file.name,
              bytes: bytes,
            );
          } catch (_) {
            uploadErrors.add(file.name);
          }
        }
      }
      if (uploadErrors.isNotEmpty && mounted) {
        showTimedSnackBar(
          context,
          message:
              'บันทึกใบแจ้งซ่อมแล้ว แต่แนบรูปไม่สำเร็จ: ${uploadErrors.join(', ')}',
          error: true,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        final text = error is ApiException
            ? '${error.message}\n${error.description ?? 'กรุณาตรวจสอบข้อมูลแล้วลองใหม่อีกครั้ง'}'
            : 'บันทึกไม่สำเร็จ\nกรุณาลองใหม่อีกครั้ง';
        showTimedSnackBar(context, message: text, error: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickAttachments() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
      allowMultiple: true,
      withData: true,
    );
    if (!mounted || result == null) return;
    final accepted = <PlatformFile>[];
    final rejected = <String>[];
    for (final file in result.files) {
      try {
        accepted.add(_compressAttachment(file));
      } catch (_) {
        rejected.add(file.name);
      }
    }
    if (!mounted) return;
    setState(() => _attachments.addAll(accepted));
    if (rejected.isNotEmpty) {
      showTimedSnackBar(
        context,
        message: 'ไฟล์ไม่ผ่านการประมวลผล: ${rejected.join(', ')}',
        error: true,
      );
    }
  }

  PlatformFile _compressAttachment(PlatformFile source) {
    final bytes = source.bytes;
    if (bytes == null) throw StateError('อ่านไฟล์ไม่ได้');
    if (bytes.length <= 1048576) return source;
    final decoded = img.decodeImage(bytes);
    if (decoded == null) throw StateError('อ่านรูปภาพไม่ได้');
    final widths = [2400, 2000, 1600, 1200, 900, 700, 500];
    const qualities = [88, 78, 68, 58, 48, 38, 30];
    for (var i = 0; i < widths.length; i++) {
      var working = decoded;
      if (working.width > widths[i]) {
        working = img.copyResize(working, width: widths[i]);
      }
      final compressed = Uint8List.fromList(
        img.encodeJpg(working, quality: qualities[i]),
      );
      if (compressed.length <= 1048576) {
        final name = source.name.replaceFirst(RegExp(r'\.[^.]+$'), '.jpg');
        return PlatformFile(
          name: name,
          size: compressed.length,
          bytes: compressed,
        );
      }
    }
    throw StateError('ลดขนาดแล้วยังเกิน 1 MB');
  }

  @override
  Widget build(BuildContext context) {
    final requesters = _maps(widget.lookup?['requesters']);
    final equipment = _maps(widget.lookup?['equipment']);
    final subjects = _maps(widget.lookup?['subjects']);
    final byKey = {
      for (final item in requesters)
        '${item['requesterType']}:${item['id']}': item,
    };
    final dialogWidth = (MediaQuery.sizeOf(context).width - 32).clamp(
      280.0,
      520.0,
    );
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LaooRadius.xs),
      ),
      title: Row(
        children: [
          const Icon(Icons.build_outlined),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.selfService ? 'แจ้งซ่อมด้วยตนเอง' : 'เพิ่มใบแจ้งซ่อม',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: dialogWidth,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Divider(),
                if (!widget.selfService)
                  DropdownButtonFormField<String>(
                    decoration: _input(label: 'ผู้แจ้ง *'),
                    items: [
                      for (final entry in byKey.entries)
                        DropdownMenuItem(
                          value: entry.key,
                          child: Text(
                            _requesterLabel(entry.value),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (key) => setState(
                      () => _requester = key == null ? null : byKey[key],
                    ),
                    validator: (_) =>
                        _requester == null ? 'กรุณาเลือกผู้แจ้ง' : null,
                  )
                else
                  _infoBox(
                    'ผู้แจ้ง: ผู้ใช้ปัจจุบัน\nสถานที่: ตามสิทธิ์ของผู้ใช้',
                  ),
                if (_requester != null) ...[
                  const SizedBox(height: 12),
                  _infoBox(
                    'สถานที่: ${_requester!['locationSnapshot']?.toString() ?? '-'}',
                  ),
                ],
                if (_qrContext != null) ...[
                  const SizedBox(height: 12),
                  _infoBox(
                    'สถานที่จาก QR: ${_qrContext!['locationSnapshot'] ?? '-'}',
                  ),
                ],
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _equipment == null
                      ? null
                      : _equipment!['itemID'].toString(),
                  decoration: _input(label: 'อุปกรณ์ที่แจ้งซ่อม *'),
                  items: [
                    for (final item in equipment)
                      DropdownMenuItem(
                        value: item['itemID'].toString(),
                        child: Text(
                          '${item['itemCode']} | ${item['itemName']}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: _qrContext == null
                      ? (value) => setState(
                          () => _equipment = value == null
                              ? null
                              : equipment.firstWhere(
                                  (item) => item['itemID'].toString() == value,
                                ),
                        )
                      : null,
                  validator: (_) => _equipment == null
                      ? 'กรุณาเลือกอุปกรณ์ที่แจ้งซ่อม'
                      : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _subjectCode,
                  decoration: _input(label: 'หัวข้อ *'),
                  items: [
                    for (final item in subjects)
                      DropdownMenuItem(
                        value: item['code']?.toString(),
                        child: Text(
                          item['name']?.toString() ?? '-',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (code) {
                    final item = subjects
                        .cast<Map<String, dynamic>>()
                        .firstWhere(
                          (row) => row['code']?.toString() == code,
                          orElse: () => <String, dynamic>{},
                        );
                    setState(() {
                      _subjectCode = code;
                      _subject.text = item['shortCode']?.toString() == 'OTHER'
                          ? ''
                          : item['name']?.toString() ?? '';
                    });
                  },
                  validator: (value) =>
                      value == null ? 'กรุณาเลือกหัวข้อ' : null,
                ),
                if (subjects.any(
                  (item) =>
                      item['code']?.toString() == _subjectCode &&
                      item['shortCode']?.toString() == 'OTHER',
                )) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _subject,
                    decoration: _input(label: 'ระบุหัวข้อ *'),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'กรุณาระบุหัวข้อ'
                        : null,
                  ),
                ],
                const SizedBox(height: 12),
                TextFormField(
                  controller: _detail,
                  minLines: 4,
                  maxLines: 7,
                  decoration: _input(label: 'รายละเอียด *'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'กรุณาระบุรายละเอียด'
                      : null,
                ),
                const SizedBox(height: 14),
                _AttachmentPicker(
                  files: _attachments,
                  enabled: !_saving,
                  onPick: _pickAttachments,
                  onRemove: (file) => setState(() => _attachments.remove(file)),
                ),
                const SizedBox(height: 14),
                const Divider(),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    TextButton(
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      child: const Text('ยกเลิก'),
                    ),
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: const Icon(Icons.save_outlined),
                      label: Text(_saving ? 'กำลังบันทึก' : 'บันทึก'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _maps(Object? value) =>
      ((value as List?) ?? const [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

  Widget _infoBox(String text) => Container(
    padding: const EdgeInsets.all(10),
    color: Theme.of(context).colorScheme.primary.withValues(alpha: .08),
    child: Text(text, softWrap: true),
  );

  String _requesterLabel(Map<String, dynamic> value) {
    final prefix = value['requesterType']?.toString() == 'SERVICE_CUSTOMER'
        ? 'ผู้ใช้บริการ Walk-in: '
        : '';
    return prefix + (value['name']?.toString() ?? '-');
  }

  InputDecoration _input({String? label}) => InputDecoration(
    labelText: label,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(LaooRadius.xs),
    ),
  );
}

class _AttachmentPicker extends StatelessWidget {
  const _AttachmentPicker({
    required this.files,
    required this.enabled,
    required this.onPick,
    required this.onRemove,
  });
  final List<PlatformFile> files;
  final bool enabled;
  final VoidCallback onPick;
  final ValueChanged<PlatformFile> onRemove;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          const Expanded(
            child: Text(
              'รูปภาพแนบ (ไม่บังคับ)',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          OutlinedButton.icon(
            onPressed: enabled ? onPick : null,
            icon: const Icon(Icons.attach_file),
            label: const Text('เลือกไฟล์'),
          ),
        ],
      ),
      const Text(
        'รองรับ JPG, PNG, WEBP | ไม่จำกัดจำนวน | ระบบลดขนาดอัตโนมัติ',
        softWrap: true,
      ),
      if (files.isNotEmpty) ...[
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final file in files)
              _AttachmentPreview(file: file, onRemove: () => onRemove(file)),
          ],
        ),
      ],
    ],
  );
}

class _AttachmentPreview extends StatelessWidget {
  const _AttachmentPreview({required this.file, required this.onRemove});
  final PlatformFile file;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 104,
    child: Stack(
      children: [
        Container(
          width: 104,
          height: 104,
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(LaooRadius.xs),
          ),
          clipBehavior: Clip.antiAlias,
          child: file.bytes == null
              ? const Icon(Icons.image_not_supported_outlined)
              : Image.memory(file.bytes!, fit: BoxFit.cover),
        ),
        Positioned(
          right: 2,
          top: 2,
          child: IconButton.filledTonal(
            onPressed: onRemove,
            iconSize: 16,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 28, height: 28),
            icon: const Icon(Icons.close),
          ),
        ),
        Positioned(
          left: 4,
          right: 4,
          bottom: 4,
          child: DecoratedBox(
            decoration: const BoxDecoration(color: Colors.black54),
            child: Text(
              '${file.name}\n${_formatBytes(file.size)}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
          ),
        ),
      ],
    ),
  );
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / 1048576).toStringAsFixed(2)} MB';
}

class _RequestDetailDialog extends StatefulWidget {
  const _RequestDetailDialog({
    required this.api,
    required this.data,
    required this.attachments,
    required this.canEdit,
  });
  final ServiceRequestApi api;
  final Map<String, dynamic> data;
  final List<Map<String, dynamic>> attachments;
  final bool canEdit;

  @override
  State<_RequestDetailDialog> createState() => _RequestDetailDialogState();
}

class _RequestDetailDialogState extends State<_RequestDetailDialog> {
  bool _busy = false;
  late Map<String, dynamic> _data;

  @override
  void initState() {
    super.initState();
    _data = widget.data;
    _attachments = List<Map<String, dynamic>>.from(widget.attachments);
  }

  late List<Map<String, dynamic>> _attachments;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        showTimedSnackBar(context, message: error.toString(), error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (_) => _ReasonDialog(
        title: 'ยกเลิกใบแจ้งซ่อม',
        label: 'เหตุผลการยกเลิก *',
        controller: controller,
      ),
    );
    controller.dispose();
    if (value == null || value.trim().isEmpty || !mounted) return;
    await _run(() => widget.api.cancel(_id, value.trim()));
  }

  Future<void> _deleteAttachment(Map<String, dynamic> item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ลบรูปแนบ'),
        content: Text('ต้องการลบ ${item['fileName'] ?? 'รูปภาพ'} หรือไม่'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (confirmed != true || _busy) return;
    setState(() => _busy = true);
    try {
      await widget.api.deleteAttachment(
        _id,
        (item['attachmentId'] as num).toInt(),
      );
      if (mounted) setState(() => _attachments.remove(item));
    } catch (error) {
      if (mounted) {
        showTimedSnackBar(context, message: error.toString(), error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  int get _id => (_data['requestId'] as num).toInt();
  String get _status => _data['statusCode']?.toString() ?? '';

  @override
  Widget build(BuildContext context) {
    final status = _status;
    return AlertDialog(
      insetPadding: const EdgeInsets.all(16),
      title: Text(_data['requestNo']?.toString() ?? 'รายละเอียดใบแจ้งซ่อม'),
      content: SizedBox(
        width: (MediaQuery.sizeOf(context).width - 32).clamp(280.0, 620.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _line('สถานะ', status),
              _line('ผู้แจ้ง', _data['requesterName']?.toString()),
              _line('สถานที่', _data['locationSnapshot']?.toString()),
              _line(
                'อุปกรณ์',
                '${_data['equipmentCode'] ?? '-'} | ${_data['equipmentName'] ?? '-'}',
              ),
              _line('หัวข้อ', _data['subject']?.toString()),
              _line('รายละเอียด', _data['detail']?.toString()),
              _line(
                'ช่างผู้รับผิดชอบ',
                _data['assignedEmployeeName']?.toString(),
              ),
              if (_data['resolutionDetail'] != null)
                _line('ผลการซ่อม', _data['resolutionDetail']?.toString()),
              if (_data['cancellationReason'] != null)
                _line('เหตุผลยกเลิก', _data['cancellationReason']?.toString()),
              if (_attachments.isNotEmpty) ...[
                const Divider(height: 24),
                const Text(
                  'รูปภาพแนบ',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final item in _attachments)
                      _RemoteAttachmentTile(
                        api: widget.api,
                        requestId: _id,
                        item: item,
                        canDelete:
                            widget.canEdit &&
                            status != 'COMPLETED' &&
                            status != 'CANCELLED',
                        onDelete: () => _deleteAttachment(item),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (widget.canEdit &&
            (status == 'NEW' ||
                status == 'RECEIVED' ||
                status == 'IN_PROGRESS'))
          TextButton(
            onPressed: _busy ? null : _cancel,
            child: const Text('ยกเลิก'),
          ),
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('ปิด'),
        ),
      ],
    );
  }

  Widget _line(String label, String? value) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      '$label: ${value == null || value.isEmpty ? '-' : value}',
      softWrap: true,
    ),
  );
}

class _RemoteAttachmentTile extends StatelessWidget {
  const _RemoteAttachmentTile({
    required this.api,
    required this.requestId,
    required this.item,
    required this.canDelete,
    required this.onDelete,
  });
  final ServiceRequestApi api;
  final int requestId;
  final Map<String, dynamic> item;
  final bool canDelete;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final attachmentId = (item['attachmentId'] as num).toInt();
    return SizedBox(
      width: 120,
      child: Column(
        children: [
          FutureBuilder<List<int>>(
            future: api.downloadAttachment(requestId, attachmentId),
            builder: (context, snapshot) => InkWell(
              onTap: snapshot.hasData
                  ? () => showDialog<void>(
                      context: context,
                      builder: (_) => Dialog(
                        child: InteractiveViewer(
                          child: Image.memory(
                            Uint8List.fromList(snapshot.data!),
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    )
                  : null,
              child: Container(
                width: 120,
                height: 96,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(LaooRadius.xs),
                ),
                child: snapshot.hasData
                    ? Image.memory(
                        Uint8List.fromList(snapshot.data!),
                        fit: BoxFit.cover,
                      )
                    : snapshot.hasError
                    ? const Icon(Icons.broken_image_outlined)
                    : const Center(child: CircularProgressIndicator()),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  item['fileName']?.toString() ?? '-',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (canDelete)
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                  color: Colors.red,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReasonDialog extends StatelessWidget {
  const _ReasonDialog({
    required this.title,
    required this.label,
    required this.controller,
  });
  final String title;
  final String label;
  final TextEditingController controller;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(title),
    content: SizedBox(
      width: 460,
      child: TextField(
        controller: controller,
        minLines: 4,
        maxLines: 8,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('ยกเลิก'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, controller.text),
        child: const Text('บันทึก'),
      ),
    ],
  );
}
