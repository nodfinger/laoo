import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/widgets/auto_dismiss_message.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/workspace_theme_presets.dart';
import '../../../../core/api/api_exception.dart';
import '../../../../core/company_setup/company_setup_controller.dart';
import '../../../../core/platform/window_title_service.dart';
import '../../../../core/widgets/combo_box_text.dart';
import '../data/company_setup_api.dart';
import '../models/company_setup_constants.dart';
import '../models/company_setup_model.dart';
import '../../presentation/widgets/support_workspace_shell.dart';

class CompanySetupPage extends StatefulWidget {
  const CompanySetupPage({super.key, this.additionalOnly = false});

  final bool additionalOnly;

  @override
  State<CompanySetupPage> createState() => _CompanySetupPageState();
}

class _CompanySetupPageState extends State<CompanySetupPage> {
  final _formKey = GlobalKey<FormState>();
  final _ownerCode = TextEditingController(text: 'C000001');
  final _ownerName = TextEditingController(text: 'Laoo Foods');
  final _titleHeader = TextEditingController(text: 'Laoo Foods');
  final _customerNameTh = TextEditingController(text: 'ละออแปรรูป');
  final _customerNameEn = TextEditingController(text: 'Laoo Foods');
  final _address = TextEditingController(text: '7/1');
  final _telephone = TextEditingController(text: '086-346-7319');
  final _taxId = TextEditingController(text: '0105566000001');
  final _email = TextEditingController(text: 'm086086@hotmail.com');
  final _rowStd = TextEditingController(text: '30');
  final _rowCardStd = TextEditingController(text: '30');
  final _timeAlert = TextEditingController(text: '30');
  final _itemDigit = TextEditingController(text: '3');
  final _markItem = TextEditingController();
  final _versionId = TextEditingController(text: '1.0.0');
  final _emailHost = TextEditingController(text: 'smtp.gmail.com');
  final _emailPort = TextEditingController(text: '587');
  final _emailCenter = TextEditingController(text: 'nodfinger@gmail.com');
  final _emailAdmin = TextEditingController(text: 'nodfinger@gmail.com');
  final _emailPasswordCenter = TextEditingController();
  final _superUserName = TextEditingController();
  final _passwordCry = TextEditingController();
  final _passwordEmpDefault = TextEditingController();

  final _api = CompanySetupApi();
  bool _loading = true;
  bool _messageIsError = false;
  String _yearFormat = CompanySetupConstants.yearFormatAd;
  int _orgStructureType = 1;
  int _passwordPolicyCode = 3;
  String? _runItem;
  List<Map<String, dynamic>> _runItemOptions = const [];
  String? _runCus;
  List<Map<String, dynamic>> _runCusOptions = const [];
  final _customerDigit = TextEditingController(text: '5');
  final _markCus = TextEditingController();

  bool _saving = false;
  bool _canEdit = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _loadActions();
    _load();
  }

  Future<void> _loadActions() async {
    try {
      final permissions = await _api.actions();
      if (mounted) {
        setState(() => _canEdit = permissions['edit'] == true);
      }
    } catch (_) {}
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _api.load(),
        _api.runItemOptions(),
        _api.runItemOptions(groupCode: CompanySetupConstants.cConstRunCus),
      ]);
      final setup = results[0] as CompanySetupModel;
      final itemOptions = results[1] as List<Map<String, dynamic>>;
      final customerOptions = results[2] as List<Map<String, dynamic>>;
      if (!mounted) return;
      _ownerCode.text = setup.ownerCode;
      _ownerName.text = setup.name;
      _titleHeader.text = setup.titleHeader;
      _customerNameTh.text = setup.customerNameTh ?? '';
      _customerNameEn.text = setup.customerNameEn ?? '';
      _address.text = setup.addressText ?? '';
      _telephone.text = setup.telephone ?? '';
      _taxId.text = setup.taxId ?? '';
      _email.text = setup.customerEmail ?? '';
      _rowStd.text = setup.rowStd.toString();
      _rowCardStd.text = setup.rowCardStd.toString();
      _timeAlert.text = setup.timeAlert.toString();
      _itemDigit.text = setup.itemDigit.toString();
      _markItem.text = setup.markItem ?? '';
      _customerDigit.text = setup.customerDigit.toString();
      _markCus.text = setup.markCus ?? '';
      _orgStructureType = setup.orgStructureType;
      _passwordPolicyCode = setup.passwordPolicyCode;
      _versionId.text = setup.versionId ?? '';
      _emailHost.text = setup.emailHost ?? '';
      _emailPort.text = setup.emailPort?.toString() ?? '';
      _emailCenter.text = setup.emailCenter ?? '';
      _emailAdmin.text = setup.emailAdmin ?? '';
      _yearFormat = setup.yearFormat == CompanySetupConstants.yearFormatBe
          ? CompanySetupConstants.yearFormatBe
          : CompanySetupConstants.yearFormatAd;
      _runItemOptions = itemOptions;
      _runItem =
          setup.runItem ??
          (itemOptions.isEmpty ? null : '${itemOptions.first['code']}');
      _runCusOptions = customerOptions;
      _runCus =
          setup.runCus ??
          (customerOptions.isEmpty ? null : '${customerOptions.first['code']}');
      setState(() => _loading = false);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _messageIsError = true;
        _message = _apiMessage(error);
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
      _titleHeader,
      _customerNameTh,
      _customerNameEn,
      _address,
      _telephone,
      _taxId,
      _email,
      _rowStd,
      _rowCardStd,
      _timeAlert,
      _itemDigit,
      _markItem,
      _customerDigit,
      _markCus,
      _versionId,
      _emailHost,
      _emailPort,
      _emailCenter,
      _emailAdmin,
      _emailPasswordCenter,
      _superUserName,
      _passwordCry,
      _passwordEmpDefault,
    ]) {
      controller.dispose();
    }
    _api.dispose();
    super.dispose();
  }

  String _apiMessage(ApiException error) => error.statusCode == null
      ? error.message
      : '${error.message} (HTTP ${error.statusCode})';

  Future<void> _save() async {
    if (_saving) return;
    final invalidEmail = [_email, _emailCenter, _emailAdmin].any(
      (controller) =>
          controller.text.trim().isNotEmpty && !_isValidEmail(controller.text),
    );
    if (invalidEmail) {
      setState(() {
        _messageIsError = true;
        _message = 'คุณกำหนดรูปแบบ email ไม่ถูกต้อง';
      });
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    if (DateTime.now().millisecondsSinceEpoch >= 0) {
      try {
        final savedSetup = await _api.save(
          CompanySetupUpdateInput(
            customerNameTh: _customerNameTh.text,
            customerNameEn: _customerNameEn.text,
            addressText: _address.text,
            telephone: _telephone.text,
            taxId: _taxId.text,
            customerEmail: _email.text,
            name: _ownerName.text,
            titleHeader: _titleHeader.text,
            runItem: _runItem,
            markItem: _markItem.text,
            rowStd: int.tryParse(_rowStd.text) ?? 30,
            rowCardStd: int.tryParse(_rowCardStd.text) ?? 30,
            timeAlert: int.tryParse(_timeAlert.text) ?? 30,
            itemDigit: int.tryParse(_itemDigit.text) ?? 3,
            runCus: _runCus,
            markCus: _markCus.text,
            customerDigit: int.tryParse(_customerDigit.text) ?? 5,
            orgStructureType: _orgStructureType,
            passwordPolicyCode: _passwordPolicyCode,
            yearFormat: _yearFormat,
            versionId: _versionId.text,
            emailHost: _emailHost.text,
            emailPort: int.tryParse(_emailPort.text),
            emailCenter: _emailCenter.text,
            emailAdmin: _emailAdmin.text,
            emailPasswordCenter: _emailPasswordCenter.text,
            superUserName: _superUserName.text,
            passwordCry: _passwordCry.text,
            passwordEmpDefault: _passwordEmpDefault.text,
          ),
          additionalOnly: widget.additionalOnly,
        );
        _itemDigit.text = savedSetup.itemDigit.toString();
        await companySetupController.load();
        WindowTitleService.setTitle(companySetupController.appTitle);
        if (!mounted) return;
        _superUserName.clear();
        _passwordCry.clear();
        _passwordEmpDefault.clear();
        _emailPasswordCenter.clear();
        setState(() {
          _saving = false;
          _messageIsError = false;
          _message = 'บันทึกข้อมูลกำหนดค่าระบบสำเร็จ';
        });
      } on ApiException catch (error) {
        if (!mounted) return;
        setState(() {
          _saving = false;
          _messageIsError = true;
          _message = _apiMessage(error);
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _saving = false;
          _messageIsError = true;
          _message = 'ไม่สามารถบันทึกข้อมูลได้';
        });
      }
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (!mounted) return;
    setState(() {
      _saving = false;
      _message = 'บันทึกตัวอย่างหน้าจอสำเร็จ (UX Demo ยังไม่เชื่อม API)';
    });
  }

  Widget _runItemCard(Color accent) {
    return Card(
      margin: EdgeInsets.zero,
      color: Colors.white,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!widget.additionalOnly) ...[
              Text(
                'กำหนดค่าระบบเพิ่มเติม',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
            ],
            Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: widget.additionalOnly ? 420 : double.infinity,
                child: DropdownButtonFormField<String>(
                  value: _runItemOptions.any((x) => '${x['code']}' == _runItem)
                      ? _runItem
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'รูปแบบการสร้างรหัสสินค้า',
                  ),
                  items: _runItemOptions
                      .map(
                        (x) => DropdownMenuItem<String>(
                          value: '${x['code']}',
                          child: LaooComboBoxText('${x['name']}'),
                        ),
                      )
                      .toList(),
                  onChanged: _canEdit
                      ? (value) => setState(() => _runItem = value)
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: widget.additionalOnly ? 180 : 240,
                child: TextFormField(
                  controller: _markItem,
                  enabled: _canEdit,
                  style: const TextStyle(fontSize: 12),
                  decoration: const InputDecoration(
                    labelText: 'สัญลักษณ์ก่อนลำดับสินค้า',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: widget.additionalOnly ? 180 : 240,
                child: TextFormField(
                  controller: _itemDigit,
                  enabled: _canEdit,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(fontSize: 12),
                  decoration: const InputDecoration(
                    labelText: 'จำนวนหลักของสินค้า',
                  ),
                  validator: (value) {
                    final digits = int.tryParse(value?.trim() ?? '');
                    return digits == null || digits < 1 || digits > 10
                        ? 'ระบุ 1-10 หลัก'
                        : null;
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: widget.additionalOnly ? 420 : double.infinity,
                child: DropdownButtonFormField<String>(
                  value: _runCusOptions.any((x) => '${x['code']}' == _runCus)
                      ? _runCus
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'รูปแบบการสร้างรหัสลูกค้า',
                  ),
                  items: _runCusOptions
                      .map(
                        (x) => DropdownMenuItem<String>(
                          value: '${x['code']}',
                          child: LaooComboBoxText('${x['name']}'),
                        ),
                      )
                      .toList(),
                  onChanged: _canEdit
                      ? (value) => setState(() => _runCus = value)
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: widget.additionalOnly ? 180 : 240,
                child: TextFormField(
                  controller: _markCus,
                  enabled: _canEdit,
                  style: const TextStyle(fontSize: 12),
                  decoration: const InputDecoration(
                    labelText: 'สัญลักษณ์ก่อนลำดับลูกค้า',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: widget.additionalOnly ? 180 : 240,
                child: TextFormField(
                  controller: _customerDigit,
                  enabled: _canEdit,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(fontSize: 12),
                  decoration: const InputDecoration(
                    labelText: 'จำนวนหลักรหัสลูกค้า',
                  ),
                  validator: (value) {
                    final digits = int.tryParse(value?.trim() ?? '');
                    return digits == null || digits < 1 || digits > 10
                        ? 'ระบุ 1-10 หลัก'
                        : null;
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isValidEmail(String value) =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim());

  void _cancel() => context.goNamed(RouteNames.authenticatedHome);

  @override
  Widget build(BuildContext context) {
    final preset = workspaceThemeController.value;
    return ColoredBox(
      color: preset.isDark ? preset.background : const Color(0xFFF8F9FB),
      child: Form(
        key: _formKey,
        child: Stack(
          children: [
            _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    children: [
                      Card(
                        margin: EdgeInsets.zero,
                        color: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                          side: BorderSide.none,
                        ),
                        child: Container(
                          decoration: const BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: Color(0xFFF5F6F7)),
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: WorkspacePageTitle(
                                  title: widget.additionalOnly
                                      ? 'กำหนดค่าระบบเพิ่มเติม'
                                      : 'กำหนดค่าระบบ',
                                  favoriteKey: widget.additionalOnly
                                      ? '05003'
                                      : '05001',
                                  titleColor: Colors.black,
                                  titleFontSize: 18,
                                ),
                              ),
                              _TopActions(
                                saving: _saving,
                                canSave: _canEdit,
                                onCancel: _cancel,
                                onSave: _save,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (!widget.additionalOnly) ...[
                        const SizedBox(height: 4),
                        _CompanySetupUxForm(
                          ownerCode: _ownerCode,
                          ownerName: _ownerName,
                          titleHeader: _titleHeader,
                          customerNameTh: _customerNameTh,
                          customerNameEn: _customerNameEn,
                          address: _address,
                          telephone: _telephone,
                          taxId: _taxId,
                          email: _email,
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (widget.additionalOnly) _runItemCard(preset.primary),
                      if (!widget.additionalOnly) ...[
                        const SizedBox(height: 8),
                        _LegacySetupCards(
                          controllers: {
                            'rowStd': _rowStd,
                            'rowCardStd': _rowCardStd,
                            'timeAlert': _timeAlert,
                            'versionId': _versionId,
                            'emailHost': _emailHost,
                            'emailPort': _emailPort,
                            'emailCenter': _emailCenter,
                            'emailAdmin': _emailAdmin,
                            'emailPasswordCenter': _emailPasswordCenter,
                            'superUserName': _superUserName,
                            'passwordCry': _passwordCry,
                            'passwordEmpDefault': _passwordEmpDefault,
                          },
                          yearFormat: _yearFormat,
                          onYearFormatChanged: (value) =>
                              setState(() => _yearFormat = value),
                          orgStructureType: _orgStructureType,
                          onOrgStructureTypeChanged: (value) =>
                              setState(() => _orgStructureType = value),
                          passwordPolicyCode: _passwordPolicyCode,
                          onPasswordPolicyCodeChanged: (value) =>
                              setState(() => _passwordPolicyCode = value),
                        ),
                      ],
                    ],
                  ),
            if (_message != null)
              Positioned(
                top: 12,
                right: 24,
                child: AutoDismissMessage(
                  key: ValueKey(_message),
                  message: _message!,
                  error: _messageIsError,
                  onClose: () => setState(() => _message = null),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LegacySetupCards extends StatelessWidget {
  const _LegacySetupCards({
    required this.controllers,
    required this.yearFormat,
    required this.onYearFormatChanged,
    required this.orgStructureType,
    required this.onOrgStructureTypeChanged,
    required this.passwordPolicyCode,
    required this.onPasswordPolicyCodeChanged,
  });

  final Map<String, TextEditingController> controllers;
  final String yearFormat;
  final ValueChanged<String> onYearFormatChanged;
  final int orgStructureType;
  final ValueChanged<int> onOrgStructureTypeChanged;
  final int passwordPolicyCode;
  final ValueChanged<int> onPasswordPolicyCodeChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 6.0;
        final columns = constraints.maxWidth >= 1050
            ? 3
            : constraints.maxWidth >= 700
            ? 2
            : 1;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            SizedBox(
              width: width,
              child: _SetupCard(
                title: 'โครงสร้างองค์กร',
                icon: Icons.account_tree_outlined,
                children: [
                  _OrgStructureField(
                    value: orgStructureType,
                    onChanged: onOrgStructureTypeChanged,
                  ),
                  _PasswordPolicyField(
                    value: passwordPolicyCode,
                    onChanged: onPasswordPolicyCodeChanged,
                  ),
                ],
              ),
            ),
            if (DateTime.now().millisecondsSinceEpoch < 0)
              SizedBox(
                width: width,
                child: _SetupCard(
                  title: 'ข้อมูลบริษัท',
                  icon: Icons.apartment_outlined,
                  children: [
                    _LegacyField(label: 'รหัสเจ้าของ', value: 'C000001'),
                    _LegacyField(label: 'ชื่อเจ้าของระบบ', value: 'Laoo Foods'),
                    _LegacyField(label: 'หัวข้อระบบ', value: 'Laoo Foods'),
                  ],
                ),
              ),
            SizedBox(
              width: width,
              child: _SetupCard(
                title: 'การแสดงผล',
                icon: Icons.monitor_outlined,
                children: [
                  _LegacyField(
                    label: 'จำนวนแถว List',
                    value: '30',
                    controller: controllers['rowStd'],
                  ),
                  _LegacyField(
                    label: 'จำนวน Card',
                    value: '30',
                    controller: controllers['rowCardStd'],
                  ),
                  _LegacyField(
                    label: 'เวลา Alert (วินาที)',
                    value: '30',
                    controller: controllers['timeAlert'],
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
                  _YearFormatField(
                    value: yearFormat,
                    onChanged: onYearFormatChanged,
                  ),
                  _LegacyField(
                    label: 'Version',
                    value: '1.0.0',
                    controller: controllers['versionId'],
                  ),
                  _LegacyField(label: 'Theme', value: 'ตาม Theme Standard'),
                ],
              ),
            ),
            SizedBox(
              width: width,
              child: _SetupCard(
                title: 'Audit (แถวบน)',
                icon: Icons.history_rounded,
                children: [
                  _LegacyField(label: 'สถานะ', value: 'ใช้งาน'),
                  _LegacyField(label: 'สร้างเมื่อ', value: '08/08/2569'),
                  _LegacyField(label: 'แก้ไขล่าสุด', value: '11/08/2569'),
                ],
              ),
            ),
            SizedBox(
              width: width,
              child: _SetupCard(
                title: 'Email Configuration',
                icon: Icons.mail_outline_rounded,
                children: [
                  _LegacyField(
                    label: 'Email Host',
                    value: 'smtp.gmail.com',
                    controller: controllers['emailHost'],
                  ),
                  _LegacyField(
                    label: 'Email Port',
                    value: '587',
                    controller: controllers['emailPort'],
                  ),
                  _LegacyField(
                    label: 'Email Center (ส่งออกอัตโนมัติ)',
                    value: 'nodfinger@gmail.com',
                    controller: controllers['emailCenter'],
                  ),
                  _LegacyField(
                    label: 'Email Center (User แจ้งปัญหา)',
                    value: 'nodfinger@gmail.com',
                    controller: controllers['emailAdmin'],
                  ),
                  if (controllers['emailPasswordCenter'] case final controller?)
                    _SecretField(
                      label: 'Email Password / App Password',
                      controller: controller,
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
                  _LegacyField(
                    label: 'Super User',
                    value: 'ตั้งค่าแล้ว',
                    controller: controllers['superUserName'],
                  ),
                  _LegacyField(
                    label: 'PasswordCry',
                    value: 'ตั้งค่าแล้ว',
                    controller: controllers['passwordCry'],
                  ),
                  _LegacyField(
                    label: 'Password พนักงาน',
                    value: 'ยังไม่ตั้งค่า',
                    controller: controllers['passwordEmpDefault'],
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
                  _LegacyField(label: 'สถานะ', value: 'ใช้งาน'),
                  _LegacyField(label: 'สร้างเมื่อ', value: '08/08/2569'),
                  _LegacyField(label: 'แก้ไขล่าสุด', value: '11/08/2569'),
                ],
              ),
            ),
          ],
        );
      },
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
    if (title.endsWith('Audit')) return const SizedBox.shrink();
    final accent = Theme.of(context).colorScheme.primary;
    return Card(
      margin: EdgeInsets.zero,
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: BorderSide.none,
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
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _LegacyField extends StatelessWidget {
  const _LegacyField({
    required this.label,
    required this.value,
    this.controller,
  });

  final String label;
  final String value;
  final TextEditingController? controller;

  @override
  Widget build(BuildContext context) {
    final resolvedLabel = switch (label) {
      'Super User' => 'Super User (เข้าได้ทุกเมนู)',
      'PasswordCry' => 'Password Super User',
      _ => label,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        initialValue: controller == null ? value : null,
        decoration: InputDecoration(labelText: resolvedLabel),
      ),
    );
  }
}

class _SecretField extends StatefulWidget {
  const _SecretField({required this.label, required this.controller});

  final String label;
  final TextEditingController controller;

  @override
  State<_SecretField> createState() => _SecretFieldState();
}

class _SecretFieldState extends State<_SecretField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: widget.controller,
        obscureText: _obscure,
        autofillHints: const [AutofillHints.password],
        decoration: InputDecoration(
          labelText: widget.label,
          suffixIcon: IconButton(
            tooltip: _obscure ? 'แสดงรหัสผ่าน' : 'ซ่อนรหัสผ่าน',
            icon: Icon(
              _obscure
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
            ),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        ),
      ),
    );
  }
}

class _OrgStructureField extends StatelessWidget {
  const _OrgStructureField({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<int>(
    initialValue: value,
    decoration: const InputDecoration(labelText: 'โครงสร้างองค์กร'),
    items: const [
      DropdownMenuItem(value: 1, child: LaooComboBoxText('แผนกเท่านั้น')),
      DropdownMenuItem(value: 2, child: LaooComboBoxText('ฝ่าย > แผนก')),
    ],
    onChanged: (next) {
      if (next != null) onChanged(next);
    },
  );
}

class _PasswordPolicyField extends StatelessWidget {
  const _PasswordPolicyField({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 12),
    child: DropdownButtonFormField<int>(
      initialValue: const [1, 2, 3].contains(value) ? value : 3,
      style: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(fontSize: 13, height: 1.35),
      decoration: const InputDecoration(
        labelText: 'Password Policy',
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      items: const [
        DropdownMenuItem(
          value: 1,
          child: Text(
            '1 - อิสระ อย่างน้อย 1 ตัว',
            style: TextStyle(fontSize: 13),
          ),
        ),
        DropdownMenuItem(
          value: 2,
          child: Text('2 - ขั้นต่ำ 4 ตัว', style: TextStyle(fontSize: 13)),
        ),
        DropdownMenuItem(
          value: 3,
          child: Text(
            '3 - ขั้นต่ำ 6 ตัว + เงื่อนไข',
            style: TextStyle(fontSize: 13),
          ),
        ),
      ],
      onChanged: (next) {
        if (next != null) onChanged(next);
      },
    ),
  );
}

class _YearFormatField extends StatelessWidget {
  const _YearFormatField({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        initialValue: CompanySetupConstants.yearFormatOptions.contains(value)
            ? value
            : CompanySetupConstants.yearFormatAd,
        decoration: const InputDecoration(labelText: 'รูปแบบปี'),
        items: CompanySetupConstants.yearFormatOptions
            .map(
              (item) => DropdownMenuItem<String>(
                value: item,
                child: LaooComboBoxText(
                  CompanySetupConstants.yearFormatLabel(item),
                ),
              ),
            )
            .toList(),
        onChanged: (next) {
          if (next != null) onChanged(next);
        },
      ),
    );
  }
}

class _CompanySetupUxForm extends StatelessWidget {
  const _CompanySetupUxForm({
    required this.ownerCode,
    required this.ownerName,
    required this.titleHeader,
    required this.customerNameTh,
    required this.customerNameEn,
    required this.address,
    required this.telephone,
    required this.taxId,
    required this.email,
  });

  final TextEditingController ownerCode;
  final TextEditingController ownerName;
  final TextEditingController titleHeader;
  final TextEditingController customerNameTh;
  final TextEditingController customerNameEn;
  final TextEditingController address;
  final TextEditingController telephone;
  final TextEditingController taxId;
  final TextEditingController email;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            const gap = 14.0;
            final threeColumns = constraints.maxWidth >= 900;
            final twoColumns = constraints.maxWidth >= 620;
            final thirdWidth = (constraints.maxWidth - gap * 2) / 3;
            final halfWidth = (constraints.maxWidth - gap) / 2;

            SizedBox field(Widget child, double width) =>
                SizedBox(width: width, child: child);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _SectionHeader(title: 'ข้อมูลพื้นฐาน'),
                const SizedBox(height: 18),
                Wrap(
                  spacing: gap,
                  runSpacing: 14,
                  children: [
                    field(
                      _text(ownerCode, 'รหัสเจ้าของ', readOnly: true),
                      threeColumns ? thirdWidth : constraints.maxWidth,
                    ),
                    field(
                      _text(ownerName, 'ข้อความแสดง title bar'),
                      threeColumns ? thirdWidth : constraints.maxWidth,
                    ),
                    field(
                      _text(titleHeader, 'หัวข้อระบบ'),
                      threeColumns ? thirdWidth : constraints.maxWidth,
                    ),
                    field(
                      _text(
                        customerNameTh,
                        'ชื่อลูกค้า (ภาษาไทย)',
                        required: true,
                      ),
                      constraints.maxWidth,
                    ),
                    field(
                      _text(
                        customerNameEn,
                        'ชื่อลูกค้า (ภาษาอังกฤษ)',
                        required: false,
                      ),
                      constraints.maxWidth,
                    ),
                    field(
                      _text(address, 'ที่อยู่', maxLines: 2),
                      constraints.maxWidth,
                    ),
                    field(
                      _text(
                        telephone,
                        'โทรศัพท์',
                        keyboardType: TextInputType.phone,
                      ),
                      constraints.maxWidth,
                    ),
                    field(
                      _text(taxId, 'เลขผู้เสียภาษี'),
                      twoColumns ? halfWidth : constraints.maxWidth,
                    ),
                    field(
                      _text(
                        email,
                        'Email',
                        keyboardType: TextInputType.emailAddress,
                      ),
                      twoColumns ? halfWidth : constraints.maxWidth,
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _text(
    TextEditingController controller,
    String label, {
    bool readOnly = false,
    bool required = false,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        label: _RequiredLabel(label, required: required),
      ),
      validator: required
          ? (value) =>
                value == null || value.trim().isEmpty ? 'กรุณาระบุ$label' : null
          : null,
    );
  }
}

class _RequiredLabel extends StatelessWidget {
  const _RequiredLabel(this.text, {this.required = false});

  final String text;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: text),
          if (required)
            const TextSpan(
              text: ' *',
              style: TextStyle(color: Colors.red),
            ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title}) : description = null;

  final String title;
  final String? description;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: Colors.black,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (description?.trim().isNotEmpty == true) ...[
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              description!,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _TopActions extends StatelessWidget {
  const _TopActions({
    required this.saving,
    required this.onCancel,
    required this.onSave,
    required this.canSave,
  });

  final bool saving;
  final VoidCallback onCancel;
  final VoidCallback onSave;
  final bool canSave;

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
        if (canSave)
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
