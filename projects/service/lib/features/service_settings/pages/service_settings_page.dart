import 'package:flutter/material.dart';

import '../../../app/theme/laoo_design_tokens.dart';
import '../../../app/theme/laoo_typography.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/widgets/timed_snack_bar.dart';
import '../../support/presentation/widgets/support_workspace_shell.dart';
import '../data/service_settings_api.dart';

class ServiceSettingsPage extends StatefulWidget {
  const ServiceSettingsPage({super.key});

  @override
  State<ServiceSettingsPage> createState() => _ServiceSettingsPageState();
}

class _ServiceSettingsPageState extends State<ServiceSettingsPage> {
  final _api = ServiceSettingsApi();
  bool _loading = true;
  bool _saving = false;
  bool _serviceEnabled = true;
  bool _allowWalkIn = true;
  bool _requireEquipment = true;
  bool _attachmentRequired = false;
  bool _workflowEnabled = true;
  int _attachmentMaxBytes = 1048576;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final value = await _api.get();
      if (!mounted) return;
      setState(() {
        _serviceEnabled = value['serviceEnabled'] == true;
        _allowWalkIn = value['allowWalkIn'] == true;
        _requireEquipment = value['requireEquipment'] == true;
        _attachmentRequired = value['attachmentRequired'] == true;
        _workflowEnabled = value['workflowEnabled'] == true;
        _attachmentMaxBytes =
            (value['attachmentMaxBytes'] as num?)?.toInt() ?? 1048576;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      _message(error);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _api.update({
        'serviceEnabled': _serviceEnabled,
        'allowWalkIn': _allowWalkIn,
        'requireEquipment': _requireEquipment,
        'attachmentRequired': _attachmentRequired,
        'workflowEnabled': _workflowEnabled,
      });
      if (mounted) {
        showTimedSnackBar(
          context,
          message: 'บันทึกตั้งค่าระบบบริการเรียบร้อยแล้ว',
        );
      }
    } catch (error) {
      if (mounted) _message(error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(Object error) {
    final text = error is ApiException
        ? '${error.message}\n${error.description ?? 'กรุณาตรวจสอบสิทธิ์และลองใหม่อีกครั้ง'}'
        : 'ไม่สามารถโหลดหรือบันทึกตั้งค่าระบบบริการได้\nกรุณาลองใหม่อีกครั้ง';
    showTimedSnackBar(context, message: text, error: true);
  }

  @override
  Widget build(BuildContext context) => SupportWorkspaceShell(
    pageTitle: 'ตั้งค่าระบบบริการ',
    activeMenu: 'serviceSettings',
    menuScope: WorkspaceMenuScope.company,
    child: _loading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(LaooLayout.cardMargin),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _section(
                      icon: Icons.settings_outlined,
                      title: 'การรับแจ้งบริการ',
                      children: [
                        _setting(
                          title: 'เปิดใช้งานระบบบริการ',
                          detail:
                              'อนุญาตให้ผู้มีสิทธิ์สร้างและติดตามใบแจ้งซ่อม',
                          value: _serviceEnabled,
                          onChanged: (value) =>
                              setState(() => _serviceEnabled = value),
                        ),
                        _setting(
                          title: 'รับแจ้งจากลูกค้า Walk-in',
                          detail: 'แสดงผู้ใช้บริการภายนอกเป็นผู้แจ้งได้',
                          value: _allowWalkIn,
                          onChanged: _serviceEnabled
                              ? (value) => setState(() => _allowWalkIn = value)
                              : null,
                        ),
                        _setting(
                          title: 'บังคับเลือกอุปกรณ์',
                          detail:
                              'ใบแจ้งซ่อมต้องระบุอุปกรณ์ที่อยู่ในระบบ Service',
                          value: _requireEquipment,
                          onChanged: _serviceEnabled
                              ? (value) =>
                                    setState(() => _requireEquipment = value)
                              : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: LaooLayout.cardSpacing),
                    _section(
                      icon: Icons.route_outlined,
                      title: 'ขั้นตอนดำเนินงาน',
                      children: [
                        _setting(
                          title: 'เปิดใช้ Workflow รับเรื่อง',
                          detail: 'NEW → RECEIVED → IN_PROGRESS → COMPLETED',
                          value: _workflowEnabled,
                          onChanged: _serviceEnabled
                              ? (value) =>
                                    setState(() => _workflowEnabled = value)
                              : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: LaooLayout.cardSpacing),
                    _section(
                      icon: Icons.attach_file_outlined,
                      title: 'รูปภาพแนบ',
                      children: [
                        _setting(
                          title: 'บังคับแนบรูปภาพ',
                          detail: 'หากเปิด ผู้แจ้งต้องแนบรูปอย่างน้อยหนึ่งไฟล์',
                          value: _attachmentRequired,
                          onChanged: _serviceEnabled
                              ? (value) =>
                                    setState(() => _attachmentRequired = value)
                              : null,
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('ขนาดสูงสุดต่อไฟล์'),
                          subtitle: Text(
                            '${(_attachmentMaxBytes / 1048576).toStringAsFixed(0)} MB หลังลดขนาดอัตโนมัติ',
                          ),
                          trailing: const Icon(Icons.lock_outline),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: const Icon(Icons.save_outlined),
                        label: Text(_saving ? 'กำลังบันทึก...' : 'บันทึก'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(
                            120,
                            LaooTypography.buttonHeight,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(LaooRadius.xs),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
  );

  Widget _section({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(LaooLayout.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          ...children,
        ],
      ),
    ),
  );

  Widget _setting({
    required String title,
    required String detail,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) => SwitchListTile.adaptive(
    contentPadding: EdgeInsets.zero,
    title: Text(title),
    subtitle: Text(detail),
    value: value,
    onChanged: onChanged,
  );
}
