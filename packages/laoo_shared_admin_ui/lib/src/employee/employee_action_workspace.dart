import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:laoo_shared_admin/laoo_shared_admin.dart';

import '../shared/shared_admin_ui_tokens.dart';
import 'employee_workspace_dependencies.dart';

typedef EmployeeImagePicker = Future<EmployeeImageInput?> Function();
typedef EmployeeActionSaved =
    Future<void> Function(EmployeeRecord? original, int employeeId);
typedef EmployeeActionMessage = void Function(String message, bool error);

class EmployeeActionWorkspace extends StatefulWidget {
  const EmployeeActionWorkspace({
    super.key,
    required this.caption,
    required this.repository,
    required this.employee,
    required this.companyId,
    required this.customerScope,
    required this.companies,
    required this.organizationUnits,
    required this.organizationMode,
    required this.roleGroups,
    required this.carTypes,
    required this.oilTypes,
    required this.canSave,
    required this.titleBuilder,
    required this.tokens,
    required this.formatDate,
    required this.errorText,
    required this.onCancel,
    required this.onSaved,
    required this.onMessage,
    this.pickImage,
  });

  final String caption;
  final EmployeeRepository repository;
  final EmployeeRecord? employee;
  final int? companyId;
  final bool customerScope;
  final List<EmployeeCompanyOption> companies;
  final List<OrganizationUnitRecord> organizationUnits;
  final int organizationMode;
  final List<EmployeeRoleGroupOption> roleGroups;
  final List<EmployeeMasterOption> carTypes;
  final List<EmployeeMasterOption> oilTypes;
  final bool canSave;
  final SharedAdminTitleBuilder titleBuilder;
  final SharedAdminUiTokens tokens;
  final EmployeeDateText formatDate;
  final SharedAdminErrorText errorText;
  final VoidCallback onCancel;
  final EmployeeActionSaved onSaved;
  final EmployeeActionMessage onMessage;
  final EmployeeImagePicker? pickImage;

  @override
  State<EmployeeActionWorkspace> createState() =>
      _EmployeeActionWorkspaceState();
}

class _EmployeeActionWorkspaceState extends State<EmployeeActionWorkspace> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _fields = {
    for (final key in const [
      'employeeCode',
      'fullName',
      'nickName',
      'position',
      'email',
      'telephone',
      'username',
      'password',
      'contactName1',
      'contactRelation1',
      'contactPhone1',
      'contactName2',
      'contactRelation2',
      'contactPhone2',
      'carId1',
      'carColor1',
      'carId2',
      'carColor2',
    ])
      key: TextEditingController(),
  };

  int? _companyId;
  int? _divisionId;
  int? _departmentId;
  int? _roleGroupId;
  String? _carType1;
  String? _carOil1;
  String? _carType2;
  String? _carOil2;
  DateTime? _startDate;
  bool _active = true;
  bool _notifyEmail = false;
  bool _notifySystem = true;
  bool _saving = false;
  bool _mediaBusy = false;
  Uint8List? _formalImage;
  Uint8List? _carImage1;
  Uint8List? _carImage2;
  String? _formalImageName;
  String? _carImageName1;
  String? _carImageName2;

  EmployeeRecord? get employee => widget.employee;
  bool get editing => employee != null;
  TextEditingController field(String key) => _fields[key]!;

  List<OrganizationUnitRecord> get _scopedUnits => widget.organizationUnits
      .where(
        (unit) =>
            unit.isActive &&
            (!widget.customerScope ||
                _companyId == null ||
                unit.companyId == _companyId),
      )
      .toList(growable: false);

  List<OrganizationUnitRecord> get _divisions => _scopedUnits
      .where((unit) => unit.unitType == OrganizationUnitTypes.division)
      .toList(growable: false);

  List<OrganizationUnitRecord> get _departments => _scopedUnits
      .where(
        (unit) =>
            unit.unitType == OrganizationUnitTypes.department &&
            (widget.organizationMode != 2 ||
                _divisionId == null ||
                unit.parentOrgUnitId == _divisionId),
      )
      .toList(growable: false);

  @override
  void initState() {
    super.initState();
    _seedEmployee();
    if (editing) _loadRelatedData();
  }

  void _seedEmployee() {
    final value = employee;
    _companyId = value?.companyId ?? widget.companyId;
    _divisionId = value?.divisionOrgUnitId;
    _departmentId = value?.departmentOrgUnitId;
    _active = value?.isActive ?? true;
    _notifyEmail = value?.notifyByEmail ?? false;
    _notifySystem = value?.notifyInSystem ?? true;
    _startDate = value?.startWorkDate;
    field('employeeCode').text = value?.employeeCode ?? '';
    field('fullName').text = value?.fullName ?? '';
    field('nickName').text = value?.nickName ?? '';
    field('position').text = value?.positionCode ?? '';
    field('email').text = value?.email ?? '';
    field('telephone').text = value?.telephone ?? '';
    field('contactName1').text = value?.contName1 ?? '';
    field('contactRelation1').text = value?.contRelation1 ?? '';
    field('contactPhone1').text = value?.contPhone1 ?? '';
    field('contactName2').text = value?.contName2 ?? '';
    field('contactRelation2').text = value?.contRelation2 ?? '';
    field('contactPhone2').text = value?.contPhone2 ?? '';
    field('carId1').text = value?.carId1 ?? '';
    field('carColor1').text = value?.carColor1 ?? '';
    field('carId2').text = value?.carId2 ?? '';
    field('carColor2').text = value?.carColor2 ?? '';
    _carType1 = _nullable(value?.carTypeCode1);
    _carOil1 = _nullable(value?.carOilType1);
    _carType2 = _nullable(value?.carTypeCode2);
    _carOil2 = _nullable(value?.carOilType2);
  }

  Future<void> _loadRelatedData() async {
    final id = employee!.employeeId;
    EmployeeUserRecord? user;
    try {
      user = await widget.repository.getEmployeeUser(id, companyId: _companyId);
    } catch (_) {
      // An employee is allowed to exist without a linked user.
    }
    final images = await Future.wait([
      widget.repository.getFormalImage(id, companyId: _companyId),
      widget.repository.getCarImage(id, 1, companyId: _companyId),
      widget.repository.getCarImage(id, 2, companyId: _companyId),
    ]);
    if (!mounted) return;
    setState(() {
      if (user != null) {
        field('username').text = user.username;
        field('password').text = user.username.isEmpty ? '' : '****';
        _roleGroupId = user.roleGroupId;
      }
      _formalImage = _decodeImage(images[0]);
      _carImage1 = _decodeImage(images[1]);
      _carImage2 = _decodeImage(images[2]);
      _formalImageName = images[0]?['fileName']?.toString();
      _carImageName1 = images[1]?['fileName']?.toString();
      _carImageName2 = images[2]?['fileName']?.toString();
    });
  }

  Uint8List? _decodeImage(Map<String, dynamic>? value) {
    final encoded = value?['imageDataBase64'];
    if (encoded is! String || encoded.isEmpty) return null;
    try {
      return base64Decode(encoded);
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    for (final controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    borderRadius: BorderRadius.circular(widget.tokens.radius),
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(),
        const Divider(height: 1),
        Expanded(
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: widget.tokens.cardPadding.left,
                top: widget.tokens.cardPadding.top,
                right: widget.tokens.cardPadding.right,
                bottom: widget.tokens.cardPadding.bottom * 2,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _generalSection(),
                  SizedBox(height: widget.tokens.cardSpacing),
                  _emergencySection(),
                  SizedBox(height: widget.tokens.cardSpacing),
                  _vehicleSection(),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _header() => Padding(
    padding: widget.tokens.cardPadding,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final title = widget.titleBuilder(
          context,
          '${widget.caption} > ${editing ? 'แก้ไข' : 'เพิ่ม'}',
          true,
        );
        final actions = <Widget>[
          OutlinedButton.icon(
            onPressed: _saving ? null : widget.onCancel,
            icon: const Icon(Icons.close),
            label: const Text('ยกเลิก'),
          ),
          if (widget.canSave)
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: const Text('บันทึก'),
            ),
        ];
        if (constraints.maxWidth < widget.tokens.compactBreakpoint) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              title,
              SizedBox(height: widget.tokens.itemSpacing),
              Wrap(
                alignment: WrapAlignment.end,
                spacing: widget.tokens.itemSpacing,
                runSpacing: widget.tokens.itemSpacing,
                children: actions,
              ),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: title),
            ...actions.expand(
              (item) => <Widget>[
                SizedBox(width: widget.tokens.itemSpacing),
                item,
              ],
            ),
          ],
        );
      },
    ),
  );

  Widget _generalSection() => _section(
    title: 'ข้อมูลพนักงาน',
    icon: Icons.badge_outlined,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final form = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _status(),
            SizedBox(height: widget.tokens.cardSpacing),
            _fieldGrid(constraints.maxWidth, [
              if (widget.customerScope) _companyField(),
              if (widget.organizationMode == 2) _divisionField(),
              _departmentField(),
              _textField('รหัสพนักงาน *', 'employeeCode', required: true),
              _textField('ชื่อ-นามสกุล *', 'fullName', required: true),
              _textField('ชื่อเล่น', 'nickName'),
              _textField('ตำแหน่ง', 'position'),
              _emailField(),
              _textField('โทรศัพท์', 'telephone'),
              _dateField(),
            ]),
            SizedBox(height: widget.tokens.cardSpacing),
            _notificationField(),
            SizedBox(height: widget.tokens.cardSpacing),
            _userSection(constraints.maxWidth),
          ],
        );
        if (constraints.maxWidth < widget.tokens.compactBreakpoint) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _formalImageCard(),
              SizedBox(height: widget.tokens.cardSpacing),
              form,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: form),
            SizedBox(width: widget.tokens.cardSpacing),
            SizedBox(width: 160, child: _formalImageCard()),
          ],
        );
      },
    ),
  );

  Widget _status() => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Text('สถานะ'),
      SizedBox(width: widget.tokens.itemSpacing),
      Switch(
        value: _active,
        onChanged: (value) => setState(() => _active = value),
      ),
      Text(_active ? 'เปิดใช้งาน' : 'ปิดใช้งาน'),
    ],
  );

  Widget _companyField() => DropdownButtonFormField<int>(
    key: ValueKey(('company', _companyId)),
    initialValue: _companyId,
    isExpanded: true,
    decoration: const InputDecoration(labelText: 'ลูกค้า *'),
    validator: (value) => value == null ? 'กรุณาเลือกลูกค้า' : null,
    items: widget.companies
        .map(
          (item) => DropdownMenuItem(
            value: item.id,
            child: Text(item.name, overflow: TextOverflow.ellipsis),
          ),
        )
        .toList(growable: false),
    onChanged: (value) => setState(() {
      _companyId = value;
      _divisionId = null;
      _departmentId = null;
    }),
  );

  Widget _divisionField() => _organizationField(
    label: 'ฝ่าย *',
    value: _divisionId,
    values: _divisions,
    onChanged: (value) => setState(() {
      _divisionId = value;
      _departmentId = null;
    }),
  );

  Widget _departmentField() => _organizationField(
    label: 'แผนก *',
    value: _departmentId,
    values: _departments,
    onChanged: (value) => setState(() => _departmentId = value),
  );

  Widget _organizationField({
    required String label,
    required int? value,
    required List<OrganizationUnitRecord> values,
    required ValueChanged<int?> onChanged,
  }) => DropdownButtonFormField<int>(
    key: ValueKey((label, value, _companyId, _divisionId)),
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(labelText: label),
    validator: (selected) =>
        selected == null ? 'กรุณาเลือก${label.replaceAll(' *', '')}' : null,
    items: values
        .map(
          (unit) => DropdownMenuItem(
            value: unit.orgUnitId,
            child: Text(
              '${unit.unitCode} - ${unit.nameTh}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        )
        .toList(growable: false),
    onChanged: onChanged,
  );

  Widget _textField(String label, String key, {bool required = false}) =>
      TextFormField(
        controller: field(key),
        onTap: key == 'password' && field(key).text == '****'
            ? field(key).clear
            : null,
        validator: required
            ? (value) => value == null || value.trim().isEmpty
                  ? 'กรุณากรอก${label.replaceAll(' *', '')}'
                  : null
            : null,
        decoration: InputDecoration(labelText: label),
      );

  Widget _emailField() => TextFormField(
    controller: field('email'),
    keyboardType: TextInputType.emailAddress,
    validator: (value) {
      final email = value?.trim() ?? '';
      if (_notifyEmail && email.isEmpty) {
        return 'กรุณาระบุ Email สำหรับการแจ้งเตือน';
      }
      if (email.isNotEmpty &&
          !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
        return 'รูปแบบ Email ไม่ถูกต้อง';
      }
      return null;
    },
    decoration: const InputDecoration(labelText: 'Email'),
  );

  Widget _dateField() => InkWell(
    onTap: _pickDate,
    child: InputDecorator(
      decoration: const InputDecoration(
        labelText: 'วันที่เริ่มงาน',
        suffixIcon: Icon(Icons.calendar_month_outlined),
      ),
      child: Text(
        _startDate == null ? 'เลือกวันที่' : widget.formatDate(_startDate!),
      ),
    ),
  );

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(1950),
      lastDate: DateTime(2100),
    );
    if (selected != null && mounted) setState(() => _startDate = selected);
  }

  Widget _notificationField() => FormField<bool>(
    initialValue: true,
    validator: (_) => !_notifyEmail && !_notifySystem
        ? 'กรุณาเลือกรูปแบบแจ้งเตือนอย่างน้อย 1 รูปแบบ'
        : null,
    builder: (state) => InputDecorator(
      decoration: InputDecoration(
        labelText: 'รูปแบบแจ้งเตือน *',
        errorText: state.errorText,
      ),
      child: Wrap(
        spacing: widget.tokens.cardSpacing,
        runSpacing: widget.tokens.itemSpacing,
        children: [
          _checkOption(
            icon: Icons.email_outlined,
            label: 'Email',
            value: _notifyEmail,
            changed: (value) {
              setState(() => _notifyEmail = value);
              state.didChange(true);
            },
          ),
          _checkOption(
            icon: Icons.notifications_active_outlined,
            label: 'ระบบ',
            value: _notifySystem,
            changed: (value) {
              setState(() => _notifySystem = value);
              state.didChange(true);
            },
          ),
        ],
      ),
    ),
  );

  Widget _checkOption({
    required IconData icon,
    required String label,
    required bool value,
    required ValueChanged<bool> changed,
  }) => InkWell(
    onTap: () => changed(!value),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Checkbox(
          value: value,
          onChanged: (selected) => changed(selected ?? false),
          visualDensity: VisualDensity.compact,
        ),
        Icon(icon, size: 20),
        SizedBox(width: widget.tokens.itemSpacing),
        Text(label),
      ],
    ),
  );

  Widget _userSection(double width) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _sectionTitle(Icons.manage_accounts_outlined, 'User Login'),
      SizedBox(height: widget.tokens.cardSpacing),
      _fieldGrid(width, [
        _textField('Username', 'username'),
        TextFormField(
          controller: field('password'),
          obscureText: true,
          onTap: field('password').text == '****'
              ? field('password').clear
              : null,
          validator: (value) {
            if (field('username').text.trim().isEmpty) return null;
            if (!editing && (value == null || value.isEmpty)) {
              return 'กรุณากรอก Password';
            }
            return null;
          },
          decoration: const InputDecoration(labelText: 'Password'),
        ),
        DropdownButtonFormField<int>(
          key: ValueKey(('role', _roleGroupId)),
          initialValue: _roleGroupId,
          isExpanded: true,
          validator: (value) =>
              field('username').text.trim().isNotEmpty && value == null
              ? 'กรุณาเลือกกลุ่มสิทธิ์'
              : null,
          decoration: const InputDecoration(labelText: 'กลุ่มสิทธิ์'),
          items: widget.roleGroups
              .map(
                (item) => DropdownMenuItem(
                  value: item.id,
                  child: Text(item.name, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(growable: false),
          onChanged: (value) => setState(() => _roleGroupId = value),
        ),
      ]),
    ],
  );

  Widget _emergencySection() => _section(
    title: 'กรณีฉุกเฉิน',
    icon: Icons.emergency_outlined,
    child: LayoutBuilder(
      builder: (_, constraints) => Column(
        children: [
          _fieldGrid(constraints.maxWidth, [
            _textField('ผู้ติดต่อคนที่ 1', 'contactName1'),
            _textField('ความสัมพันธ์', 'contactRelation1'),
            _textField('โทรศัพท์', 'contactPhone1'),
          ]),
          SizedBox(height: widget.tokens.cardSpacing),
          _fieldGrid(constraints.maxWidth, [
            _textField('ผู้ติดต่อคนที่ 2', 'contactName2'),
            _textField('ความสัมพันธ์', 'contactRelation2'),
            _textField('โทรศัพท์', 'contactPhone2'),
          ]),
        ],
      ),
    ),
  );

  Widget _vehicleSection() => _section(
    title: 'ยานพาหนะที่ใช้',
    icon: Icons.directions_car_outlined,
    child: LayoutBuilder(
      builder: (_, constraints) => Column(
        children: [
          _vehicleRow(
            constraints.maxWidth,
            1,
            'carId1',
            'carColor1',
            _carType1,
            _carOil1,
          ),
          SizedBox(height: widget.tokens.cardSpacing),
          _vehicleRow(
            constraints.maxWidth,
            2,
            'carId2',
            'carColor2',
            _carType2,
            _carOil2,
          ),
        ],
      ),
    ),
  );

  Widget _vehicleRow(
    double width,
    int number,
    String idKey,
    String colorKey,
    String? carType,
    String? oilType,
  ) => Material(
    color: Theme.of(context).colorScheme.surfaceContainerLowest,
    borderRadius: BorderRadius.circular(widget.tokens.radius),
    child: Padding(
      padding: widget.tokens.cardPadding,
      child: LayoutBuilder(
        builder: (_, constraints) {
          final fields = _fieldGrid(constraints.maxWidth, [
            _textField('ทะเบียนรถ', idKey),
            _textField('สีรถ', colorKey),
            _masterField(
              'ประเภทรถ',
              carType,
              widget.carTypes,
              (value) => setState(() {
                if (number == 1) {
                  _carType1 = value;
                } else {
                  _carType2 = value;
                }
              }),
            ),
            _masterField(
              'เชื้อเพลิง',
              oilType,
              widget.oilTypes,
              (value) => setState(() {
                if (number == 1) {
                  _carOil1 = value;
                } else {
                  _carOil2 = value;
                }
              }),
            ),
          ]);
          if (width < widget.tokens.compactBreakpoint) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('รถคันที่ $number'),
                SizedBox(height: widget.tokens.itemSpacing),
                _carImageBox(number),
                SizedBox(height: widget.tokens.cardSpacing),
                fields,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 110, child: _carImageBox(number)),
              SizedBox(width: widget.tokens.cardSpacing),
              Expanded(child: fields),
            ],
          );
        },
      ),
    ),
  );

  Widget _masterField(
    String label,
    String? value,
    List<EmployeeMasterOption> values,
    ValueChanged<String?> changed,
  ) => DropdownButtonFormField<String>(
    key: ValueKey((label, value)),
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(labelText: label),
    items: values
        .map(
          (item) => DropdownMenuItem(
            value: item.code,
            child: Text(item.name, overflow: TextOverflow.ellipsis),
          ),
        )
        .toList(growable: false),
    onChanged: changed,
  );

  Widget _formalImageCard() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _sectionTitle(Icons.person_outline, 'รูปพนักงาน'),
      SizedBox(height: widget.tokens.itemSpacing),
      AspectRatio(
        aspectRatio: 4 / 5,
        child: _imageSurface(
          bytes: _formalImage,
          placeholder: Icons.person_outline,
          onTap: () => _pickMedia(0),
        ),
      ),
      _imageActions(0, _formalImage != null),
    ],
  );

  Widget _carImageBox(int number) {
    final bytes = number == 1 ? _carImage1 : _carImage2;
    return Column(
      children: [
        Text('รูปรถคันที่ $number'),
        SizedBox(height: widget.tokens.itemSpacing),
        SizedBox(
          height: 72,
          child: _imageSurface(
            bytes: bytes,
            placeholder: Icons.directions_car_outlined,
            onTap: () => _pickMedia(number),
          ),
        ),
        _imageActions(number, bytes != null),
      ],
    );
  }

  Widget _imageSurface({
    required Uint8List? bytes,
    required IconData placeholder,
    required VoidCallback onTap,
  }) => Material(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    borderRadius: BorderRadius.circular(widget.tokens.radius),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: _mediaBusy || widget.pickImage == null ? null : onTap,
      child: bytes == null
          ? Icon(placeholder, color: Theme.of(context).colorScheme.primary)
          : Image.memory(bytes, fit: BoxFit.cover),
    ),
  );

  Widget _imageActions(int number, bool hasImage) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      IconButton(
        tooltip: 'เลือกรูป',
        onPressed: _mediaBusy || widget.pickImage == null
            ? null
            : () => _pickMedia(number),
        icon: const Icon(Icons.image_outlined),
      ),
      IconButton(
        tooltip: 'ลบรูป',
        onPressed: !hasImage || _mediaBusy ? null : () => _removeMedia(number),
        color: Theme.of(context).colorScheme.error,
        icon: const Icon(Icons.delete_outline),
      ),
    ],
  );

  Future<void> _pickMedia(int number) async {
    final picker = widget.pickImage;
    if (picker == null) return;
    setState(() => _mediaBusy = true);
    try {
      final selected = await picker();
      if (selected == null || !mounted) return;
      setState(() {
        if (number == 0) {
          _formalImage = selected.bytes;
          _formalImageName = selected.fileName;
        } else if (number == 1) {
          _carImage1 = selected.bytes;
          _carImageName1 = selected.fileName;
        } else {
          _carImage2 = selected.bytes;
          _carImageName2 = selected.fileName;
        }
      });
    } catch (error) {
      widget.onMessage(widget.errorText(error), true);
    } finally {
      if (mounted) setState(() => _mediaBusy = false);
    }
  }

  Future<void> _removeMedia(int number) async {
    if (number > 0 && editing) {
      try {
        await widget.repository.deleteCarImage(
          employee!.employeeId,
          number,
          companyId: _companyId,
        );
      } catch (error) {
        widget.onMessage(widget.errorText(error), true);
        return;
      }
    }
    if (!mounted) return;
    setState(() {
      if (number == 0) {
        _formalImage = null;
        _formalImageName = null;
      } else if (number == 1) {
        _carImage1 = null;
        _carImageName1 = null;
      } else {
        _carImage2 = null;
        _carImageName2 = null;
      }
    });
  }

  Widget _section({
    required String title,
    required IconData icon,
    required Widget child,
  }) => Material(
    color: Theme.of(context).colorScheme.surface,
    borderRadius: BorderRadius.circular(widget.tokens.radius),
    child: Padding(
      padding: widget.tokens.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionTitle(icon, title),
          SizedBox(height: widget.tokens.cardSpacing),
          child,
        ],
      ),
    ),
  );

  Widget _sectionTitle(IconData icon, String title) => Row(
    children: [
      Icon(icon, color: Theme.of(context).colorScheme.primary),
      SizedBox(width: widget.tokens.itemSpacing),
      Expanded(
        child: Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    ],
  );

  Widget _fieldGrid(double width, List<Widget> fields) {
    final columns = width >= 960
        ? 3
        : width >= 600
        ? 2
        : 1;
    final fieldWidth =
        (width - (widget.tokens.cardSpacing * (columns - 1))) / columns;
    return Wrap(
      spacing: widget.tokens.cardSpacing,
      runSpacing: widget.tokens.cardSpacing,
      children: fields
          .map((item) => SizedBox(width: fieldWidth, child: item))
          .toList(growable: false),
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final input = _buildInput();
      final id = await EmployeeFormService(
        widget.repository,
      ).save(input, organizationMode: widget.organizationMode);
      widget.onMessage(
        editing ? 'แก้ไขพนักงานสำเร็จ' : 'เพิ่มข้อมูลใหม่สำเร็จ',
        false,
      );
      await widget.onSaved(employee, id);
    } on EmployeeFormValidationException catch (error) {
      widget.onMessage(error.message, true);
    } catch (error) {
      widget.onMessage(
        'บันทึกข้อมูลพนักงานไม่สำเร็จ: ${widget.errorText(error)}',
        true,
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  EmployeeFormInput _buildInput() => EmployeeFormInput(
    employeeId: employee?.employeeId,
    companyId: _companyId,
    divisionOrgUnitId: _divisionId,
    departmentOrgUnitId: _departmentId,
    employeeCode: field('employeeCode').text,
    fullName: field('fullName').text,
    nickName: field('nickName').text,
    positionCode: field('position').text,
    email: field('email').text,
    notifyByEmail: _notifyEmail,
    notifyInSystem: _notifySystem,
    telephone: field('telephone').text,
    contact1: EmployeeEmergencyContactInput(
      name: field('contactName1').text,
      relation: field('contactRelation1').text,
      phone: field('contactPhone1').text,
    ),
    contact2: EmployeeEmergencyContactInput(
      name: field('contactName2').text,
      relation: field('contactRelation2').text,
      phone: field('contactPhone2').text,
    ),
    vehicle1: EmployeeVehicleInput(
      registration: field('carId1').text,
      color: field('carColor1').text,
      typeCode: _carType1,
      oilTypeCode: _carOil1,
    ),
    vehicle2: EmployeeVehicleInput(
      registration: field('carId2').text,
      color: field('carColor2').text,
      typeCode: _carType2,
      oilTypeCode: _carOil2,
    ),
    startWorkDate: _startDate,
    isActive: _active,
    username: field('username').text,
    password: field('password').text == '****' ? null : field('password').text,
    roleGroupId: _roleGroupId,
    formalImage: _imageInput(
      _formalImage,
      _formalImageName,
      'employee-formal.jpg',
    ),
    carImage1: _imageInput(_carImage1, _carImageName1, 'employee-car-1.jpg'),
    carImage2: _imageInput(_carImage2, _carImageName2, 'employee-car-2.jpg'),
  );

  EmployeeImageInput? _imageInput(
    Uint8List? bytes,
    String? fileName,
    String fallback,
  ) => bytes == null
      ? null
      : EmployeeImageInput(bytes: bytes, fileName: fileName ?? fallback);

  static String? _nullable(String? value) {
    final normalized = value?.trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }
}
