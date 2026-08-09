import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/workspace_theme_presets.dart';
import '../../../../core/api/api_exception.dart';
import '../../../../core/company_setup/company_setup_controller.dart';
import '../../../../core/platform/window_title_service.dart';
import '../data/company_setup_api.dart';
import '../models/company_setup_model.dart';
import '../../presentation/widgets/support_workspace_shell.dart';

class CompanySetupPage extends StatefulWidget {
  const CompanySetupPage({super.key});

  @override
  State<CompanySetupPage> createState() => _CompanySetupPageState();
}

class _CompanySetupPageState extends State<CompanySetupPage> {
  final _formKey = GlobalKey<FormState>();
  final _api = CompanySetupApi();
  bool _loading = true;
  CompanySetupModel? _loadedSetup;

  final _ownerCode = TextEditingController();
  final _ownerName = TextEditingController();
  final _name = TextEditingController(text: 'Laoo Solutions');
  final _titleHeader = TextEditingController(text: 'Laoo Solutions');
  final _rowStd = TextEditingController(text: '30');
  final _rowCardStd = TextEditingController(text: '30');
  final _timeAlert = TextEditingController(text: '30');
  final _versionId = TextEditingController(text: '1.0.0');
  final _emailHost = TextEditingController();
  final _emailPort = TextEditingController(text: '587');
  final _emailCenter = TextEditingController();
  final _emailAdmin = TextEditingController();

  final _superUserName = TextEditingController();
  final _passwordCry = TextEditingController();
  final _emailPasswordCenter = TextEditingController();
  final _passwordEmpDefault = TextEditingController();
  final _passwordDirect = TextEditingController();

  String _yearFormat = 'AD';
  bool _saving = false;
  String? _message;
  bool _messageIsError = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _message = null;
    });

    try {
      final setup = await _api.load();
      if (!mounted) return;

      _loadedSetup = setup;
      _ownerCode.text = setup.ownerCode;
      _ownerName.text = setup.ownerName;
      _name.text = setup.name;
      _titleHeader.text = setup.titleHeader;
      _rowStd.text = setup.rowStd.toString();
      _rowCardStd.text = setup.rowCardStd.toString();
      _timeAlert.text = setup.timeAlert.toString();
      _yearFormat = {'AD', 'BE'}.contains(setup.yearFormat)
          ? setup.yearFormat!
          : 'AD';
      _versionId.text = setup.versionId ?? '';
      _emailHost.text = setup.emailHost ?? '';
      _emailPort.text = setup.emailPort?.toString() ?? '';
      _emailCenter.text = setup.emailCenter ?? '';
      _emailAdmin.text = setup.emailAdmin ?? '';

      setState(() {
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _messageIsError = true;
        _message = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _messageIsError = true;
        _message = 'ไม่สามารถโหลดข้อมูลกำหนดค่าระบบได้';
      });
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _ownerCode,
      _ownerName,
      _name,
      _titleHeader,
      _rowStd,
      _rowCardStd,
      _timeAlert,
      _versionId,
      _emailHost,
      _emailPort,
      _emailCenter,
      _emailAdmin,
      _superUserName,
      _passwordCry,
      _emailPasswordCenter,
      _passwordEmpDefault,
      _passwordDirect,
    ]) {
      controller.dispose();
    }
    _api.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _message = null;
    });

    try {
      final setup = await _api.save(
        CompanySetupUpdateInput(
          name: _name.text.trim(),
          titleHeader: _titleHeader.text.trim(),
          rowStd: int.parse(_rowStd.text.trim()),
          rowCardStd: int.parse(_rowCardStd.text.trim()),
          timeAlert: int.parse(_timeAlert.text.trim()),
          yearFormat: _yearFormat,
          versionId: _nullIfBlank(_versionId.text),
          emailHost: _nullIfBlank(_emailHost.text),
          emailPort: int.tryParse(_emailPort.text.trim()),
          emailCenter: _nullIfBlank(_emailCenter.text),
          emailAdmin: _nullIfBlank(_emailAdmin.text),
          superUserName: _nullIfBlank(_superUserName.text),
          passwordCry: _nullIfBlank(_passwordCry.text),
          emailPasswordCenter: _nullIfBlank(_emailPasswordCenter.text),
          passwordEmpDefault: _nullIfBlank(_passwordEmpDefault.text),
          passwordDirect: _nullIfBlank(_passwordDirect.text),
        ),
      );

      await companySetupController.load();
      WindowTitleService.setTitle(companySetupController.appTitle);

      if (!mounted) return;

      _loadedSetup = setup;
      _superUserName.clear();
      _passwordCry.clear();
      _emailPasswordCenter.clear();
      _passwordEmpDefault.clear();
      _passwordDirect.clear();

      setState(() {
        _messageIsError = false;
        _message = 'แก้ไขข้อมูล กำหนดค่าระบบ สำเร็จ';
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _messageIsError = true;
        _message = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _messageIsError = true;
        _message = 'ไม่สามารถบันทึกข้อมูลกำหนดค่าระบบได้';
      });
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  String? _nullIfBlank(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  void _cancel() {
    context.goNamed(RouteNames.supportHome);
  }

  @override
  Widget build(BuildContext context) {
    final preset = workspaceThemeController.value;
    final accent = Theme.of(context).colorScheme.primary;

    return ColoredBox(
      color: preset.isDark ? preset.background : Colors.white,
      child: Form(
        key: _formKey,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Expanded(
                        child: WorkspacePageTitle(
                          title: 'กำหนดค่าระบบ',
                          favoriteKey: 'กำหนดค่าระบบ',
                        ),
                      ),
                      _TopActions(
                        saving: _saving,
                        onCancel: _cancel,
                        onSave: _save,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_message != null) ...[
                    _InlineMessage(
                      message: _message!,
                      error: _messageIsError,
                      onClose: () => setState(() => _message = null),
                    ),
                    const SizedBox(height: 16),
                  ],
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth >= 1050;
                      final medium = constraints.maxWidth >= 700;
                      final columns = wide ? 3 : (medium ? 2 : 1);
                      final gap = 16.0;
                      final width =
                          (constraints.maxWidth - (gap * (columns - 1))) /
                          columns;

                      return Wrap(
                        spacing: gap,
                        runSpacing: gap,
                        children: [
                          SizedBox(
                            width: width,
                            child: _SetupCard(
                              title: 'ข้อมูลบริษัท',
                              icon: Icons.apartment_outlined,
                              children: [
                                TextFormField(
                                  controller: _ownerCode,
                                  readOnly: true,
                                  decoration: const InputDecoration(
                                    labelText: 'รหัสเจ้าของ',
                                    hintText: 'อ่านจากผู้ใช้งานที่ Login',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _name,
                                  decoration: const InputDecoration(
                                    label: _RequiredLabel('ชื่อเจ้าของระบบ (แสดงที่ Title Bar)'),
                                  ),
                                  validator: _required('กรุณาระบุชื่อเจ้าของระบบ'),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _titleHeader,
                                  decoration: const InputDecoration(
                                    label: _RequiredLabel('หัวข้อระบบ'),
                                  ),
                                  validator: _required('กรุณาระบุหัวข้อระบบ'),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: width,
                            child: _SetupCard(
                              title: 'การแสดงผล',
                              icon: Icons.monitor_outlined,
                              children: [
                                TextFormField(
                                  controller: _rowStd,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    label: _RequiredLabel('จำนวนแถว List'),
                                  ),
                                  validator: _positiveInt(
                                    'กรุณาระบุจำนวนแถว List',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _rowCardStd,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    label: _RequiredLabel('จำนวน Card'),
                                  ),
                                  validator: _positiveInt(
                                    'กรุณาระบุจำนวน Card',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _timeAlert,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    label: _RequiredLabel(
                                      'เวลา Alert (วินาที)',
                                    ),
                                  ),
                                  validator: _positiveInt(
                                    'กรุณาระบุเวลา Alert เป็นวินาที',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: width,
                            child: _SetupCard(
                              title: 'ข้อมูลการแสดงผลระบบ',
                              icon: Icons.palette_outlined,
                              children: [
                                DropdownButtonFormField<String>(
                                  initialValue: _yearFormat,
                                  decoration: const InputDecoration(
                                    labelText: 'รูปแบบปี',
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'AD',
                                      child: Text('ค.ศ. (AD)'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'BE',
                                      child: Text('พ.ศ. (BE)'),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() => _yearFormat = value);
                                    }
                                  },
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _versionId,
                                  decoration: const InputDecoration(
                                    labelText: 'Version',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _InfoLine(
                                  icon: Icons.palette_outlined,
                                  text:
                                      'Theme ของ User แยกจาก Company Setup ตาม Theme Standard',
                                  color: accent,
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: width,
                            child: _SetupCard(
                              title: 'Email Configuration',
                              icon: Icons.mail_outline_rounded,
                              children: [
                                TextFormField(
                                  controller: _emailHost,
                                  decoration: const InputDecoration(
                                    labelText: 'Email Host',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _emailPort,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Email Port',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _emailCenter,
                                  decoration: const InputDecoration(
                                    labelText: 'Email Center',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _emailAdmin,
                                  decoration: const InputDecoration(
                                    labelText: 'Email Admin',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: width,
                            child: _SetupCard(
                              title: 'Security / Secret',
                              icon: Icons.lock_outline_rounded,
                              children: [
                                _SecretStatus(
                                  title: 'Super User',
                                  configured:
                                      _loadedSetup?.hasSuperUser ?? false,
                                ),
                                _SecretStatus(
                                  title: 'PasswordCry',
                                  configured:
                                      _loadedSetup?.hasPasswordCry ?? false,
                                ),
                                _SecretStatus(
                                  title: 'Email Center Password',
                                  configured:
                                      _loadedSetup?.hasEmailPasswordCenter ??
                                      false,
                                ),
                                _SecretStatus(
                                  title: 'รหัสผ่านเริ่มต้นพนักงาน',
                                  configured:
                                      _loadedSetup?.hasPasswordEmpDefault ??
                                      false,
                                ),
                                _SecretStatus(
                                  title: 'รหัสผ่านกลาง',
                                  configured:
                                      _loadedSetup?.hasPasswordDirect ?? false,
                                ),
                                TextFormField(
                                  controller: _superUserName,
                                  decoration: const InputDecoration(
                                    labelText:
                                        'SuperUserName (กรอกใหม่เพื่อเปลี่ยน)',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _SecretField(
                                  controller: _passwordCry,
                                  label: 'PasswordCry (กรอกใหม่เพื่อเปลี่ยน)',
                                ),
                                const SizedBox(height: 12),
                                _SecretField(
                                  controller: _emailPasswordCenter,
                                  label:
                                      'EmailPasswordCenter (กรอกใหม่เพื่อเปลี่ยน)',
                                ),
                                const SizedBox(height: 12),
                                _SecretField(
                                  controller: _passwordEmpDefault,
                                  label:
                                      'PasswordEmpDefault (กรอกใหม่เพื่อเปลี่ยน)',
                                ),
                                const SizedBox(height: 12),
                                _SecretField(
                                  controller: _passwordDirect,
                                  label:
                                      'PasswordDirect (กรอกใหม่เพื่อเปลี่ยน)',
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  'ค่า Secret เดิมต้องไม่แสดงกลับบน UI และช่องว่างต้องรักษาค่าเดิม',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: width,
                            child: _SetupCard(
                              title: 'สถานะและ Audit',
                              icon: Icons.history_rounded,
                              children: [
                                _AuditRow(
                                  label: 'สถานะ',
                                  value: (_loadedSetup?.isActive ?? true)
                                      ? 'ใช้งาน'
                                      : 'ไม่ใช้งาน',
                                ),
                                _AuditRow(
                                  label: 'สร้างเมื่อ',
                                  value: _loadedSetup?.createDate ?? '—',
                                ),
                                _AuditRow(
                                  label: 'สร้างโดย',
                                  value:
                                      _loadedSetup?.createBy?.toString() ?? '—',
                                ),
                                _AuditRow(
                                  label: 'แก้ไขล่าสุด',
                                  value: _loadedSetup?.updateDate ?? '—',
                                ),
                                _AuditRow(
                                  label: 'แก้ไขโดย',
                                  value:
                                      _loadedSetup?.updateBy?.toString() ?? '—',
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _TopActions(
                      saving: _saving,
                      onCancel: _cancel,
                      onSave: _save,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  FormFieldValidator<String> _required(String message) {
    return (value) => value == null || value.trim().isEmpty ? message : null;
  }

  FormFieldValidator<String> _positiveInt(String message) {
    return (value) {
      final number = int.tryParse(value?.trim() ?? '');
      if (number == null || number <= 0) return message;
      return null;
    };
  }
}

class _TopActions extends StatelessWidget {
  const _TopActions({
    required this.saving,
    required this.onCancel,
    required this.onSave,
  });

  final bool saving;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: saving ? null : onCancel,
          icon: const Icon(Icons.close_rounded),
          label: const Text('ยกเลิก'),
        ),
        FilledButton.icon(
          onPressed: saving ? null : onSave,
          icon: saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: const Text('บันทึก'),
        ),
      ],
    );
  }
}

class _SetupCard extends StatelessWidget {
  const _SetupCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final preset = workspaceThemeController.value;
    final accent = Theme.of(context).colorScheme.primary;

    return Card(
      color: preset.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: accent.withValues(alpha: 0.40)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, color: accent, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: accent,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _RequiredLabel extends StatelessWidget {
  const _RequiredLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: text),
          const TextSpan(
            text: ' *',
            style: TextStyle(color: Colors.red),
          ),
        ],
      ),
    );
  }
}

class _SecretField extends StatefulWidget {
  const _SecretField({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  State<_SecretField> createState() => _SecretFieldState();
}

class _SecretFieldState extends State<_SecretField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _obscure,
      decoration: InputDecoration(
        labelText: widget.label,
        suffixIcon: IconButton(
          tooltip: _obscure ? 'แสดงค่าที่กำลังกรอก' : 'ซ่อนค่า',
          onPressed: () => setState(() => _obscure = !_obscure),
          icon: Icon(
            _obscure
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
        ),
      ),
    );
  }
}

class _SecretStatus extends StatelessWidget {
  const _SecretStatus({required this.title, required this.configured});

  final String title;
  final bool configured;

  @override
  Widget build(BuildContext context) {
    final color = configured ? Colors.green : Colors.orange;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(
            configured
                ? Icons.check_circle_outline_rounded
                : Icons.info_outline_rounded,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 6),
          Text('$title: ${configured ? 'ตั้งค่าแล้ว' : 'ยังไม่ได้ตั้งค่า'}'),
        ],
      ),
    );
  }
}

class _AuditRow extends StatelessWidget {
  const _AuditRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({
    required this.message,
    required this.error,
    required this.onClose,
  });

  final String message;
  final bool error;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final color = error ? Colors.red : Colors.blue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            error ? Icons.error_outline_rounded : Icons.info_outline_rounded,
            color: color,
          ),
          const SizedBox(width: 9),
          Expanded(child: Text(message)),
          IconButton(
            tooltip: 'ปิด',
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}
