import 'package:flutter/material.dart';

import '../../../app/theme/laoo_design_tokens.dart';
import '../../../app/theme/laoo_typography.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/navigation/navigation_menu_repository.dart';
import '../../../core/widgets/timed_snack_bar.dart';
import '../../support/presentation/widgets/support_workspace_shell.dart';
import '../data/service_settings_api.dart';

class ServiceSettingsPage extends StatefulWidget {
  const ServiceSettingsPage({super.key, this.api});
  final ServiceSettingsApi? api;

  @override
  State<ServiceSettingsPage> createState() => _ServiceSettingsPageState();
}

class _ServiceSettingsPageState extends State<ServiceSettingsPage> {
  late final ServiceSettingsApi _api = widget.api ?? ServiceSettingsApi();
  String _caption = 'ตั้งค่าระบบบริการ';
  String? _loadError;
  bool _canEdit = false;
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
    _resolveCaption();
  }

  Future<void> _resolveCaption() async {
    try {
      final name = await NavigationMenuRepository().resolveMenuName(
        menuCode: '18001',
        routeName: 'serviceSettings',
        fallback: _caption,
      );
      if (mounted) setState(() => _caption = name);
    } catch (_) {}
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final value = await _api.get();
      if (!mounted) return;
      setState(() {
        _serviceEnabled = value['serviceEnabled'] == true;
        _canEdit = value['canEdit'] == true;
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
      setState(() {
        _loading = false;
        _canEdit = false;
        _loadError = error is ApiException
            ? 'ไม่สามารถโหลดตั้งค่าระบบบริการได้\nรายละเอียดเพิ่มเติม: ${error.description ?? error.message}'
            : 'ไม่สามารถโหลดตั้งค่าระบบบริการได้\nรายละเอียดเพิ่มเติม: กรุณาตรวจสอบการเชื่อมต่อและลองอีกครั้ง';
      });
    }
  }

  Future<void> _save() async {
    if (_saving || !_canEdit) return;
    setState(() => _saving = true);
    try {
      await _api.update({
        'serviceEnabled': _serviceEnabled,
        'allowWalkIn': _allowWalkIn,
        'requireEquipment': _requireEquipment,
        'attachmentRequired': _attachmentRequired,
        'workflowEnabled': _workflowEnabled,
      });
      await _load();
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
    pageTitle: _caption,
    activeMenu: 'serviceSettings',
    menuScope: WorkspaceMenuScope.company,
    child: _loading
        ? const Center(child: CircularProgressIndicator())
        : _loadError != null
        ? Padding(
            padding: const EdgeInsets.all(LaooLayout.cardMargin),
            child: Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(LaooLayout.cardPadding),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_loadError!),
                    const SizedBox(height: LaooLayout.cardSpacing),
                    OutlinedButton(
                      onPressed: _load,
                      child: const Text('ลองอีกครั้ง'),
                    ),
                  ],
                ),
              ),
            ),
          )
        : SingleChildScrollView(
            padding: const EdgeInsets.all(LaooLayout.cardMargin),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _section(
                  icon: Icons.settings_outlined,
                  title: 'การรับแจ้งบริการ',
                  children: [
                    _setting(
                      title: 'เปิดใช้งานระบบบริการ',
                      detail: 'อนุญาตให้ผู้มีสิทธิ์สร้างและติดตามใบแจ้งซ่อม',
                      value: _serviceEnabled,
                      onChanged: _canEdit
                          ? (value) => setState(() => _serviceEnabled = value)
                          : null,
                    ),
                    _setting(
                      title: 'รับแจ้งจากลูกค้า Walk-in',
                      detail: 'แสดงผู้ใช้บริการภายนอกเป็นผู้แจ้งได้',
                      value: _allowWalkIn,
                      onChanged: _canEdit && _serviceEnabled
                          ? (value) => setState(() => _allowWalkIn = value)
                          : null,
                    ),
                    _setting(
                      title: 'บังคับเลือกอุปกรณ์',
                      detail: 'ใบแจ้งซ่อมต้องระบุอุปกรณ์ที่อยู่ในระบบ Service',
                      value: _requireEquipment,
                      onChanged: _canEdit && _serviceEnabled
                          ? (value) => setState(() => _requireEquipment = value)
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
                      onChanged: _canEdit && _serviceEnabled
                          ? (value) => setState(() => _workflowEnabled = value)
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
                      onChanged: _canEdit && _serviceEnabled
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
                if (_canEdit) ...[
                  const SizedBox(height: LaooLayout.cardSpacing),
                  Card(
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.all(LaooLayout.cardPadding),
                      child: Align(
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
                              borderRadius: BorderRadius.circular(
                                LaooRadius.xs,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
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
              const SizedBox(width: LaooLayout.listSectionSpacing),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: LaooTypography.sectionTitle,
                    fontWeight: FontWeight.w700,
                  ),
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
