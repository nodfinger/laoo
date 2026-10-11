import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';
import 'site_host.dart';

class SiteForm extends StatefulWidget {
  const SiteForm({
    super.key,
    required this.menuCode,
    required this.title,
    required this.icon,
    required this.row,
    required this.options,
    required this.api,
    required this.onSaved,
  });
  final String menuCode, title;
  final IconData icon;
  final Map<String, dynamic>? row;
  final Map<String, dynamic> options;
  final JsonApiClient api;
  final Future<void> Function() onSaved;
  @override
  State<SiteForm> createState() => _SiteFormState();
}

class _SiteFormState extends State<SiteForm> {
  static const base = '/api/company/site';
  static const draftStorage = FlutterSecureStorage();
  final key = GlobalKey<FormState>();
  final fields = <String, TextEditingController>{};
  final lines = <Map<String, dynamic>>[];
  final pendingPhotos = <PlatformFile>[];
  final photos = <Map<String, dynamic>>[];
  bool saving = false, offline = true;
  int? savedId;
  int? project, customer, branch, employee;
  String issueStatus = 'OPEN', handoverType = 'STAGE';
  LaooWorkspaceUiTokens get tokens => siteTokens();
  bool get adding => widget.row == null;
  TextEditingController controller(String name) => fields.putIfAbsent(
    name,
    () => TextEditingController(text: '${widget.row?[name] ?? ''}'),
  );
  String? text(String name) {
    final v = controller(name).text.trim();
    return v.isEmpty ? null : v;
  }

  @override
  void initState() {
    super.initState();
    project = (widget.row?['projectId'] as num?)?.toInt();
    customer = (widget.row?['customerId'] as num?)?.toInt();
    branch = (widget.row?['branchId'] as num?)?.toInt();
    employee = (widget.row?['assignedEmployeeId'] as num?)?.toInt();
    issueStatus = widget.row?['status']?.toString() ?? 'OPEN';
    handoverType = widget.row?['type']?.toString() ?? 'STAGE';
    offline = widget.options['allowOfflineDraft'] != false;
    savedId = (widget.row?['id'] as num?)?.toInt();
    for (final photo in widget.row?['photos'] as List? ?? []) {
      photos.add(Map<String, dynamic>.from(photo as Map));
    }
    if (widget.menuCode == '63003') {
      for (final line in widget.row?['lines'] as List? ?? []) {
        lines.add(Map<String, dynamic>.from(line as Map));
      }
      fields['workDate'] = TextEditingController(
        text:
            widget.row?['workDate']?.toString().split('T').first ??
            DateTime.now().toIso8601String().split('T').first,
      );
      if (adding) _restoreDraft();
    }
    for (final name in ['startDate', 'dueDate']) {
      final value = widget.row?[name]?.toString();
      if (value != null) {
        fields[name] = TextEditingController(text: value.split('T').first);
      }
    }
  }

  String? get draftKey {
    final scope = siteDraftScope();
    return scope == null ? null : 'site:daily-draft:$scope';
  }

  Future<void> _restoreDraft() async {
    final key = draftKey;
    if (key == null) return;
    try {
      final raw = await draftStorage.read(key: key);
      if (raw == null) return;
      final saved = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      final at = DateTime.tryParse('${saved['savedAt'] ?? ''}');
      if (at == null || DateTime.now().difference(at).inHours >= 24) {
        await draftStorage.delete(key: key);
        return;
      }
      final body = Map<String, dynamic>.from(saved['body'] as Map);
      if (!mounted) return;
      setState(() {
        project = (body['projectId'] as num?)?.toInt();
        for (final name in ['workDate', 'summary', 'problemSummary']) {
          fields.putIfAbsent(name, () => TextEditingController()).text =
              '${body[name] ?? ''}';
        }
        lines
          ..clear()
          ..addAll(
            (body['lines'] as List? ?? []).map(
              (line) => Map<String, dynamic>.from(line as Map),
            ),
          );
      });
      if (mounted) {
        siteMessage(
          context,
          message: 'กู้ร่างในเครื่องแล้ว ยังไม่ได้บันทึกที่ Server',
          error: false,
        );
      }
    } catch (_) {
      // Local storage can be unavailable in private browser mode.
    }
  }

  Future<bool> _keepDraft(Map<String, dynamic> body) async {
    final key = draftKey;
    if (key == null) return false;
    try {
      await draftStorage.write(
        key: key,
        value: jsonEncode({
          'savedAt': DateTime.now().toIso8601String(),
          'body': body,
        }),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  List<Map<String, dynamic>> list(String name) =>
      (widget.options[name] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
  Widget input(
    String name,
    String label, {
    bool required = false,
    int maxLines = 1,
    TextInputType? keyboard,
  }) => TextFormField(
    controller: controller(name),
    maxLines: maxLines,
    keyboardType: keyboard,
    style: tokens.inputStyle,
    decoration: InputDecoration(
      labelText: required ? '$label *' : label,
      border: const OutlineInputBorder(),
    ),
    validator: (v) =>
        required && (v?.trim().isEmpty ?? true) ? 'กรุณาระบุ$label' : null,
  );
  Widget dropdown(
    String label,
    int? selected,
    List<Map<String, dynamic>> values,
    ValueChanged<int?> changed,
  ) => DropdownButtonFormField<int>(
    initialValue: values.any((v) => (v['id'] as num?)?.toInt() == selected)
        ? selected
        : null,
    isExpanded: true,
    decoration: InputDecoration(
      labelText: '$label *',
      border: const OutlineInputBorder(),
    ),
    items: [
      for (final row in values)
        DropdownMenuItem<int>(
          value: (row['id'] as num).toInt(),
          child: Text(
            '${row['name'] ?? row['projectName'] ?? row['code'] ?? row['id']}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
    ],
    onChanged: changed,
    validator: (v) => v == null ? 'กรุณาเลือก$label' : null,
  );
  Widget spacing() => const SizedBox(height: 16);

  Future<void> pickPhoto() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final photo = result.files.single;
    if (photo.bytes == null || photo.size > 20 * 1024 * 1024) {
      if (mounted) {
        siteMessage(context, message: 'รูปต้องไม่เกิน 20 MB', error: true);
      }
      return;
    }
    setState(() => pendingPhotos.add(photo));
  }

  Future<void> previewPhoto(int id) async {
    try {
      final bytes = await siteDownload('$base/files/$id');
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialog) => Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800, maxHeight: 700),
            child: InteractiveViewer(
              child: Image.memory(
                Uint8List.fromList(bytes),
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        siteMessage(
          context,
          message: siteErrorText(error, 'เปิดรูป'),
          error: true,
        );
      }
    }
  }

  Widget photoSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      spacing(),
      Text('รูปหน้างาน', style: tokens.sectionStyle),
      Wrap(
        spacing: 8,
        children: [
          for (final photo in photos)
            OutlinedButton.icon(
              onPressed: () => previewPhoto((photo['id'] as num).toInt()),
              icon: const Icon(Icons.image_outlined),
              label: Text('${photo['fileName'] ?? 'รูปภาพ'}'),
            ),
        ],
      ),
      for (final photo in pendingPhotos)
        ListTile(
          leading: const Icon(Icons.image_outlined),
          title: Text(photo.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: IconButton(
            tooltip: 'นำรูปออก',
            onPressed: () => setState(() => pendingPhotos.remove(photo)),
            icon: const Icon(Icons.close),
          ),
        ),
      OutlinedButton.icon(
        onPressed: saving ? null : pickPhoto,
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: const Text('แนบรูป'),
      ),
    ],
  );

  Widget lineEditor(int index) {
    final line = lines[index];
    String type = '${line['type'] ?? 'WORKER'}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('รายการ ${index + 1}', style: tokens.sectionStyle),
              ),
              IconButton(
                tooltip: 'ลบรายการ',
                onPressed: () => setState(() => lines.removeAt(index)),
                icon: const Icon(Icons.delete_outline, color: Colors.red),
              ),
            ],
          ),
          DropdownButtonFormField<String>(
            initialValue: type,
            decoration: const InputDecoration(
              labelText: 'ประเภท *',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'WORKER', child: Text('คนงาน')),
              DropdownMenuItem(value: 'MATERIAL', child: Text('วัสดุ')),
              DropdownMenuItem(
                value: 'EXPENSE',
                child: Text('ค่าใช้จ่ายภายใน'),
              ),
            ],
            onChanged: (v) => setState(() {
              line['type'] = v;
              line['employeeId'] = null;
              line['itemId'] = null;
            }),
          ),
          if (type == 'WORKER' || type == 'MATERIAL') ...[
            spacing(),
            DropdownButtonFormField<int>(
              initialValue:
                  (line[type == 'WORKER' ? 'employeeId' : 'itemId'] as num?)
                      ?.toInt(),
              isExpanded: true,
              decoration: InputDecoration(
                labelText: type == 'WORKER'
                    ? 'พนักงานในระบบ (ถ้ามี)'
                    : 'วัสดุ/สินค้าในระบบ (ถ้ามี)',
                border: const OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<int>(
                  value: 0,
                  child: Text('ระบุเองในรายละเอียด'),
                ),
                for (final option in list(
                  type == 'WORKER' ? 'employees' : 'items',
                ))
                  DropdownMenuItem<int>(
                    value: (option['id'] as num).toInt(),
                    child: Text(
                      '${option['code'] ?? ''} ${option['name'] ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (value) => setState(() {
                line[type == 'WORKER' ? 'employeeId' : 'itemId'] = value == 0
                    ? null
                    : value;
              }),
            ),
          ],
          spacing(),
          TextFormField(
            initialValue: '${line['description'] ?? ''}',
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'รายละเอียด *',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => line['description'] = v,
            validator: (v) =>
                v?.trim().isEmpty ?? true ? 'กรุณาระบุรายละเอียด' : null,
          ),
          spacing(),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: '${line['quantity'] ?? ''}',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'จำนวน',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) => line['quantity'] = v,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  initialValue: '${line['amount'] ?? ''}',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'จำนวนเงิน',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) => line['amount'] = v,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget body() {
    final menu = widget.menuCode;
    if (menu == '63001') {
      return Column(
        children: [
          input(
            'maxPhotoMB',
            'ขนาดรูปสูงสุด (MB)',
            required: true,
            keyboard: TextInputType.number,
          ),
          spacing(),
          SwitchListTile(
            title: const Text('เก็บร่างบนเครื่องชั่วคราวเมื่อออฟไลน์'),
            value: offline,
            onChanged: (v) => setState(() => offline = v),
          ),
        ],
      );
    }
    if (menu == '63002') {
      return Column(
        children: [
          input('code', 'รหัสโครงการ', required: true),
          spacing(),
          input('name', 'ชื่อโครงการ', required: true),
          spacing(),
          dropdown(
            'ลูกค้า',
            customer,
            list('customers'),
            (v) => setState(() => customer = v),
          ),
          spacing(),
          dropdown(
            'สาขา',
            branch,
            list('branches'),
            (v) => setState(() => branch = v),
          ),
          spacing(),
          input('address', 'สถานที่หน้างาน', maxLines: 2),
          spacing(),
          input('description', 'รายละเอียด', maxLines: 3),
          spacing(),
          input('startDate', 'วันเริ่ม YYYY-MM-DD'),
          spacing(),
          input('dueDate', 'วันครบกำหนด YYYY-MM-DD'),
        ],
      );
    }
    if (menu == '63003') {
      return Column(
        children: [
          dropdown(
            'โครงการ',
            project,
            list('projects'),
            (v) => setState(() => project = v),
          ),
          spacing(),
          input('workDate', 'วันที่ทำงาน YYYY-MM-DD', required: true),
          spacing(),
          input('summary', 'งานวันนี้', required: true, maxLines: 4),
          spacing(),
          input('problemSummary', 'ปัญหาหน้างาน', maxLines: 3),
          spacing(),
          Row(
            children: [
              Expanded(
                child: Text(
                  'คนงาน วัสดุ และค่าใช้จ่าย',
                  style: tokens.sectionStyle,
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => setState(
                  () => lines.add({
                    'type': 'WORKER',
                    'description': '',
                    'quantity': null,
                    'amount': null,
                  }),
                ),
                icon: const Icon(Icons.add),
                label: const Text('เพิ่มรายการ'),
              ),
            ],
          ),
          spacing(),
          for (var i = 0; i < lines.length; i++) lineEditor(i),
        ],
      );
    }
    if (menu == '63005') {
      return Column(
        children: [
          dropdown(
            'โครงการ',
            project,
            list('projects'),
            (v) => setState(() => project = v),
          ),
          spacing(),
          input('title', 'หัวข้อปัญหา', required: true),
          spacing(),
          input('detail', 'รายละเอียด', required: true, maxLines: 4),
          spacing(),
          DropdownButtonFormField<String>(
            initialValue: issueStatus,
            decoration: const InputDecoration(
              labelText: 'สถานะ',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'OPEN', child: Text('เปิด')),
              DropdownMenuItem(value: 'IN_PROGRESS', child: Text('กำลังแก้ไข')),
              DropdownMenuItem(value: 'RESOLVED', child: Text('แก้ไขแล้ว')),
            ],
            onChanged: (v) => setState(() => issueStatus = v ?? 'OPEN'),
          ),
          spacing(),
          input('resolution', 'ผลการแก้ไข', maxLines: 3),
        ],
      );
    }
    if (menu == '63006') {
      return Column(
        children: [
          dropdown(
            'โครงการ',
            project,
            list('projects'),
            (v) => setState(() => project = v),
          ),
          spacing(),
          input('stageName', 'ชื่องวดงาน', required: true),
          spacing(),
          DropdownButtonFormField<String>(
            initialValue: handoverType,
            decoration: const InputDecoration(
              labelText: 'ประเภทส่งมอบ',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'STAGE', child: Text('รายงวด')),
              DropdownMenuItem(value: 'FINAL', child: Text('จบโครงการ')),
            ],
            onChanged: (v) => setState(() => handoverType = v ?? 'STAGE'),
          ),
          spacing(),
          input('detail', 'รายละเอียดส่งมอบ', required: true, maxLines: 4),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  String? validateDate(String name) {
    final value = text(name);
    if (value == null) return null;
    final date = DateTime.tryParse(value);
    return date == null || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)
        ? 'รูปแบบวันที่ต้องเป็น YYYY-MM-DD'
        : null;
  }

  Future<void> save() async {
    if (saving || !(key.currentState?.validate() ?? false)) return;
    if ({'63002', '63003', '63005', '63006'}.contains(widget.menuCode) &&
        project == null &&
        widget.menuCode != '63002') {
      siteMessage(context, message: 'กรุณาเลือกโครงการ', error: true);
      return;
    }
    if (widget.menuCode == '63002' && (customer == null || branch == null)) {
      siteMessage(context, message: 'กรุณาเลือกลูกค้าและสาขา', error: true);
      return;
    }
    final dateFields = switch (widget.menuCode) {
      '63002' => ['startDate', 'dueDate'],
      '63003' => ['workDate'],
      _ => <String>[],
    };
    for (final name in dateFields) {
      final problem = validateDate(name);
      if (problem != null) {
        siteMessage(context, message: problem, error: true);
        return;
      }
    }
    setState(() => saving = true);
    Map<String, dynamic>? draftBody;
    try {
      final menu = widget.menuCode;
      final body = switch (menu) {
        '63001' => <String, dynamic>{
          'maxPhotoMB': int.tryParse(text('maxPhotoMB') ?? '') ?? 0,
          'allowOfflineDraft': offline,
        },
        '63002' => <String, dynamic>{
          'code': text('code'),
          'name': text('name'),
          'customerId': customer,
          'branchId': branch,
          'address': text('address'),
          'description': text('description'),
          'startDate': text('startDate'),
          'dueDate': text('dueDate'),
          'rowVersion': widget.row?['rowVersion'],
        },
        '63003' => <String, dynamic>{
          'projectId': project,
          'workDate': text('workDate'),
          'summary': text('summary'),
          'problemSummary': text('problemSummary'),
          'lines': [
            for (final l in lines)
              {
                'type': l['type'] ?? 'WORKER',
                'description': '${l['description'] ?? ''}'.trim(),
                'quantity': double.tryParse('${l['quantity'] ?? ''}'),
                'amount': double.tryParse('${l['amount'] ?? ''}'),
                'employeeId': l['employeeId'],
                'itemId': l['itemId'],
              },
          ],
        },
        '63005' => <String, dynamic>{
          'projectId': project,
          'reportId': widget.row?['reportId'],
          'title': text('title'),
          'detail': text('detail'),
          'employeeId': employee,
          'dueDate': text('dueDate'),
          'status': issueStatus,
          'resolution': text('resolution'),
        },
        _ => <String, dynamic>{
          'projectId': project,
          'stageName': text('stageName'),
          'type': handoverType,
          'detail': text('detail'),
        },
      };
      final path = switch (menu) {
        '63001' => '$base/settings',
        '63002' => '$base/projects',
        '63003' => '$base/reports',
        '63005' => '$base/issues',
        _ => '$base/handovers',
      };
      if (menu == '63003') draftBody = body;
      if (adding && menu != '63001' && savedId == null) {
        final created = Map<String, dynamic>.from(
          await widget.api.post(path, body: body) as Map,
        );
        savedId = (created['id'] as num).toInt();
      } else {
        final target = menu == '63001' ? path : '$path/$savedId';
        await widget.api.put(target, body: body);
      }
      final localDraftKey = draftKey;
      if (menu == '63003' && localDraftKey != null) {
        try {
          await draftStorage.delete(key: localDraftKey);
        } catch (_) {
          // Server save has already succeeded; local cleanup must not mask it.
        }
      }
      if (savedId != null && pendingPhotos.isNotEmpty && project != null) {
        final ownerType = switch (menu) {
          '63003' => 'REPORT',
          '63005' => 'ISSUE',
          _ => 'HANDOVER',
        };
        for (final photo in pendingPhotos) {
          await siteUpload(
            '$base/files',
            fileName: photo.name,
            bytes: photo.bytes!,
            fields: {
              'projectId': '$project',
              'ownerType': ownerType,
              'ownerId': '$savedId',
            },
          );
        }
        pendingPhotos.clear();
      }
      if (mounted) siteMessage(context, message: 'บันทึกสำเร็จ', error: false);
      await widget.onSaved();
      if (!mounted) return;
      if (adding && menu != '63001') {
        for (final field in fields.values) {
          field.clear();
        }
        lines.clear();
        setState(() {
          savedId = null;
          project = null;
          customer = null;
          branch = null;
          employee = null;
        });
      } else {
        Navigator.pop(context);
      }
    } catch (exception) {
      final kept =
          widget.menuCode == '63003' &&
          adding &&
          savedId == null &&
          offline &&
          draftBody != null &&
          await _keepDraft(draftBody);
      if (mounted) {
        siteMessage(
          context,
          message: kept
              ? 'ยังไม่บันทึกที่ Server เก็บร่างข้อความในเครื่องไว้ 24 ชั่วโมงแล้ว (รูปภาพไม่อยู่ในร่าง)'
              : siteErrorText(exception, 'บันทึก'),
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => LaooActionDialog(
    tokens: tokens,
    icon: widget.icon,
    title: '${widget.title} > ${adding ? 'เพิ่ม' : 'แก้ไข'}',
    content: Form(
      key: key,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          body(),
          if ({'63003', '63005', '63006'}.contains(widget.menuCode))
            photoSection(),
        ],
      ),
    ),
    actions: [
      OutlinedButton(
        onPressed: saving ? null : () => Navigator.pop(context),
        child: const Text('ยกเลิก'),
      ),
      FilledButton.icon(
        onPressed: saving ? null : save,
        icon: saving
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.save_outlined),
        label: Text(saving ? 'กำลังบันทึก' : 'บันทึก'),
      ),
    ],
  );
}
