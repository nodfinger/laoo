import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'ai_image_picker.dart';

import '../../app/theme/laoo_design_tokens.dart';
import '../../core/api/api_client.dart';
import '../../core/navigation/navigation_menu_repository.dart';
import '../../core/widgets/timed_snack_bar.dart';
import '../company/shared/registry_ui.dart';
import '../support/presentation/widgets/support_workspace_shell.dart';

class AiAgentsPage extends StatefulWidget {
  const AiAgentsPage({super.key, this.embedded = false, this.busy = false});

  final bool embedded;
  final bool busy;

  @override
  State<AiAgentsPage> createState() => AiAgentsPageState();
}

class _AgentEditor {
  _AgentEditor(Map row)
    : id = row['id'] as String,
      name = TextEditingController(text: row['name'] as String),
      greeting = TextEditingController(text: row['greeting'] as String),
      capabilities = (row['capabilities'] as List).cast<String>(),
      status = row['status'] as String;
  final String id, status;
  final TextEditingController name, greeting;
  final List<String> capabilities;
  Uint8List? image;
  Uint8List? pendingImage;
  String? pendingImageName;
  void dispose() {
    name.dispose();
    greeting.dispose();
  }
}

class AiAgentsPageState extends State<AiAgentsPage> {
  final _api = ApiClient();
  final _form = GlobalKey<FormState>();
  final _rows = <_AgentEditor>[];
  String _caption = '';
  bool _loading = true, _canEdit = false, _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final menu = await NavigationMenuRepository().findMenu(menuCode: '64003');
      final result =
          await _api.get('/api/assistant/agents/configuration') as Map;
      final rows = (result['agents'] as List)
          .map((e) => _AgentEditor(e as Map))
          .toList();
      for (final row in rows) {
        try {
          row.image = Uint8List.fromList(
            await _api.getBytes('/api/assistant/agents/${row.id}/image'),
          );
        } catch (_) {}
      }
      if (!mounted) {
        for (final row in rows) {
          row.dispose();
        }
        return;
      }
      setState(() {
        _caption = menu?.name ?? '';
        _canEdit = result['canEdit'] == true;
        _rows.addAll(rows);
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'ไม่สามารถโหลด Agent ได้ กรุณาตรวจสอบสิทธิ์และลองใหม่';
        });
      }
    }
  }

  Future<void> _pickAgentImage(_AgentEditor row) async {
    try {
      final picked = await pickAiImage();
      if (picked == null || picked.files.single.bytes == null) return;
      final file = picked.files.single;
      if (file.bytes!.length > 1024 * 1024) throw StateError('image too large');
      if (mounted) {
        setState(() {
          row.image = file.bytes;
          row.pendingImage = file.bytes;
          row.pendingImageName = file.name;
        });
      }
    } catch (_) {
      if (mounted) {
        showTimedSnackBar(
          context,
          message:
              'บันทึกรูปไม่สำเร็จ กรุณาเลือกรูป JPG, PNG หรือ WEBP ขนาดไม่เกิน 1 MB',
          error: true,
        );
      }
    }
  }

  String? validateForSave() {
    if (_loading || _error != null || !_canEdit) {
      return 'ไม่สามารถบันทึก Agent ได้ กรุณาตรวจสอบสิทธิ์และการโหลดข้อมูล';
    }
    if (_rows.any(
      (row) => row.name.text.trim().isEmpty || row.greeting.text.trim().isEmpty,
    )) {
      return 'กรุณาระบุชื่อและข้อความแนะนำตัวของ Agent ให้ครบ';
    }
    return null;
  }

  Future<void> savePending() async {
    await _api.put(
      '/api/assistant/agents/configuration',
      body: _rows
          .map(
            (row) => {
              'id': row.id,
              'name': row.name.text.trim(),
              'greeting': row.greeting.text.trim(),
            },
          )
          .toList(),
    );
    for (final row in _rows) {
      if (row.pendingImage != null) {
        await _api.upload(
          '/api/assistant/agents/${row.id}/image',
          fileName: row.pendingImageName!,
          bytes: row.pendingImage!,
        );
        row.pendingImage = null;
        row.pendingImageName = null;
      }
    }
  }

  Future<void> _save() async {
    final error = validateForSave();
    if (error != null || !(_form.currentState?.validate() ?? false)) {
      if (error != null) {
        showTimedSnackBar(context, message: error, error: true);
      }
      return;
    }
    setState(() => _saving = true);
    try {
      await savePending();
      if (mounted) {
        showTimedSnackBar(context, message: 'บันทึกการตั้งค่า Agent แล้ว');
      }
    } catch (_) {
      if (mounted) {
        showTimedSnackBar(
          context,
          message: 'บันทึก Agent ไม่สำเร็จ กรุณาตรวจสอบข้อมูลและลองใหม่',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    _api.dispose();
    super.dispose();
  }

  Widget _content(BuildContext context) => _loading
      ? const Center(child: CircularProgressIndicator())
      : Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!widget.embedded)
                registrySurface(
                  Row(
                    children: [
                      Expanded(
                        child: widget.embedded
                            ? Text(
                                _caption,
                                style: Theme.of(context).textTheme.titleMedium,
                              )
                            : WorkspacePageTitle(
                                title: _caption,
                                favoriteKey: 'companyAiAgents',
                              ),
                      ),
                      if (_canEdit)
                        FilledButton.icon(
                          onPressed: _saving ? null : _save,
                          icon: const Icon(Icons.save_outlined),
                          label: const Text('บันทึก'),
                        ),
                    ],
                  ),
                ),
              if (!widget.embedded) const SizedBox(height: 8),
              if (_error != null)
                registrySurface(
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(_error!),
                  ),
                )
              else
                ..._rows.map(
                  (row) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Card(
                      margin: EdgeInsets.zero,
                      color: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(LaooRadius.xs),
                      ),
                      child: ExpansionTile(
                        initiallyExpanded: false,
                        maintainState: true,
                        shape: const Border(),
                        collapsedShape: const Border(),
                        title: Text(switch (row.id) {
                          'service' => 'Agent Service',
                          'stock' => 'Agent สต๊อก',
                          'meeting' => 'Agent ห้องประชุม',
                          _ => row.id,
                        }, style: Theme.of(context).textTheme.titleMedium),
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 28,
                                      backgroundImage: row.image == null
                                          ? null
                                          : MemoryImage(row.image!),
                                      child: row.image == null
                                          ? const Icon(Icons.smart_toy_outlined)
                                          : null,
                                    ),
                                    const SizedBox(width: 12),
                                    if (_canEdit)
                                      OutlinedButton.icon(
                                        onPressed: _saving || widget.busy
                                            ? null
                                            : () => _pickAgentImage(row),
                                        icon: const Icon(Icons.image_outlined),
                                        label: const Text('เลือกรูป Agent'),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: row.name,
                                  enabled: _canEdit && !_saving && !widget.busy,
                                  maxLength: 100,
                                  decoration: const InputDecoration(
                                    labelText: 'ชื่อเรียก',
                                    counterText: '',
                                  ),
                                  validator: (v) => (v?.trim().isEmpty ?? true)
                                      ? 'กรุณาระบุชื่อเรียก'
                                      : null,
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: row.greeting,
                                  enabled: _canEdit && !_saving && !widget.busy,
                                  maxLength: 500,
                                  maxLines: 2,
                                  decoration: const InputDecoration(
                                    labelText: 'ข้อความแนะนำตัว',
                                    counterText: '',
                                  ),
                                  validator: (v) => (v?.trim().isEmpty ?? true)
                                      ? 'กรุณาระบุข้อความแนะนำตัว'
                                      : null,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  row.status == 'planned'
                                      ? 'สถานะ: รอพัฒนา'
                                      : 'สถานะ: พร้อมใช้งาน',
                                ),
                                if (row.id == 'meeting' &&
                                    row.status == 'planned')
                                  const Text(
                                    'เตรียมรองรับการค้นหาห้องว่างและตรวจสอบการจอง เมื่อพัฒนาและทดสอบสิทธิ์แล้ว',
                                  ),
                                if (row.capabilities.isNotEmpty)
                                  Text(
                                    'ความสามารถ: ${row.capabilities.map((code) => switch (code) {
                                      'meeting.availability' => 'ค้นหาห้องประชุมว่าง',
                                      'meeting.own_bookings' => 'การจองห้องประชุมของฉัน',
                                      'meeting.invitations' => 'คำเชิญประชุมของฉัน',
                                      'repair.create_own' => 'แจ้งซ่อมใหม่',
                                      'repair.track_own' => 'ติดตามงานของตนเอง',
                                      'repair.parts_cost' => 'สรุปต้นทุนอะไหล่',
                                      _ => code,
                                    }).join(', ')}',
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) return _content(context);
    return SupportWorkspaceShell(
      pageTitle: _caption,
      activeMenu: 'companyAiAgents',
      menuScope: WorkspaceMenuScope.company,
      child: ColoredBox(
        color: LaooColors.background,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(LaooLayout.cardMargin),
          child: _content(context),
        ),
      ),
    );
  }
}
