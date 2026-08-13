import 'package:flutter/material.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/auth/app_auth_controller.dart';
import '../../../../core/navigation/navigation_menu_repository.dart';
import '../../../../core/widgets/auto_dismiss_message.dart';
import '../../../../core/widgets/combo_box_text.dart';
import '../../presentation/widgets/support_workspace_shell.dart';
import '../data/organization_repository.dart';

class OrganizationStructurePage extends StatefulWidget {
  const OrganizationStructurePage({super.key});

  @override
  State<OrganizationStructurePage> createState() =>
      _OrganizationStructurePageState();
}

class _OrganizationStructurePageState extends State<OrganizationStructurePage> {
  final _repository = OrganizationRepository();
  final _code = TextEditingController();
  final _name = TextEditingController();
  final _nameEn = TextEditingController();

  List<Map<String, dynamic>> _units = [];
  String _caption = '';
  int _mode = 1;
  int? _selectedDivisionId;
  Map<String, dynamic>? _editing;
  String? _formType;
  bool _loading = true;
  bool _saving = false;
  bool _active = true;
  String? _message;

  String _errorMessage(Object error) =>
      error is ApiException ? error.message : error.toString();
  bool _messageError = false;

  @override
  void initState() {
    super.initState();
    _resolveCaption();
    _load();
  }

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _nameEn.dispose();
    super.dispose();
  }

  Future<void> _resolveCaption() async {
    final menuCode = appAuthController.isPartnerUser
        ? '11005'
        : appAuthController.isCompanyUser
        ? '10005'
        : '12005';
    final value = await NavigationMenuRepository().resolveMenuName(
      menuCode: menuCode,
      routeName: 'organizationStructure',
      fallback: '',
    );
    if (mounted) setState(() => _caption = value);
  }

  Future<void> _load({bool clearMessage = true}) async {
    setState(() {
      _loading = true;
      if (clearMessage) _message = null;
    });
    try {
      final result = await _repository.load();
      if (!mounted) return;
      final units = List<Map<String, dynamic>>.from(
        result['units'] as List? ?? const [],
      );
      final divisions = units.where((x) => x['unitType'] == 'DIV').toList();
      setState(() {
        _mode = result['orgStructureType'] as int? ?? 1;
        _units = units;
        if (_mode == 2 &&
            !divisions.any((x) => x['orgUnitId'] == _selectedDivisionId)) {
          _selectedDivisionId = divisions.isEmpty
              ? null
              : divisions.first['orgUnitId'] as int;
        }
      });
    } catch (error) {
      if (mounted) _showMessage(_errorMessage(error), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showMessage(String value, {bool error = false}) {
    setState(() {
      _message = value;
      _messageError = error;
    });
  }

  @override
  Widget build(BuildContext context) => SupportWorkspaceShell(
        pageTitle: _caption,
        activeMenu: 'organizationStructure',
        menuScope: appAuthController.isPartnerUser
            ? WorkspaceMenuScope.partner
            : appAuthController.isCompanyUser
            ? WorkspaceMenuScope.company
            : WorkspaceMenuScope.support,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: _formType == null ? _buildList() : _buildForm(),
            ),
            if (_message != null)
              Positioned(
                top: 12,
                right: 24,
                child: _messageBox(),
              ),
          ],
        ),
      );

  Widget _buildList() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: WorkspacePageTitle(
                  title: _caption,
                  favoriteKey: 'organizationStructure',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_loading) const LinearProgressIndicator(),
          if (!_loading)
            Expanded(
              child: _mode == 1
                  ? _departmentPanel()
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(width: 330, child: _divisionPanel()),
                        const SizedBox(width: 12),
                        Expanded(child: _departmentPanel()),
                      ],
                    ),
            ),
        ],
      );

  Widget _modeCard() => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'รูปแบบโครงสร้างองค์กร',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const Text(
                      'หน้าพนักงานจะอ่านค่านี้และปรับช่องฝ่าย/แผนกอัตโนมัติ',
                    ),
                  ],
                ),
              ),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 1, label: Text('แผนกเท่านั้น')),
                  ButtonSegment(value: 2, label: Text('ฝ่าย > แผนก')),
                ],
                selected: {_mode},
                onSelectionChanged: null,
              ),
            ],
          ),
        ),
      );

  Widget _divisionPanel() {
    final divisions = _units.where((x) => x['unitType'] == 'DIV').toList();
    return Card(
      child: Column(
        children: [
          _panelHeader('ฝ่าย', 'เพิ่มฝ่าย', () => _openForm('DIV')),
          const Divider(height: 1),
          if (divisions.isEmpty)
            const Expanded(child: Center(child: Text('ยังไม่มีข้อมูลฝ่าย')))
          else
            Expanded(
              child: ListView.separated(
                itemCount: divisions.length,
                separatorBuilder: (_, _) => Divider(height: 1, color: Colors.grey.shade300),
                itemBuilder: (context, index) {
                  final item = divisions[index];
                  final departmentCount = _units.where((unit) =>
                      unit['unitType'] == 'DEP' &&
                      unit['parentOrgUnitId'] == item['orgUnitId']).length;
                  return ListTile(
                    selected: item['orgUnitId'] == _selectedDivisionId,
                    leading: const Icon(Icons.account_tree_outlined),
                    title: Text('${item['unitCode']} - ${item['nameTh']}'),
                    subtitle: Text('แผนก $departmentCount รายการ'),
                    onTap: () => setState(
                      () => _selectedDivisionId = item['orgUnitId'] as int,
                    ),
                    trailing: Wrap(
                      children: [
                        IconButton(
                          tooltip: 'แก้ไข',
                          onPressed: () => _openForm('DIV', item: item),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          tooltip: 'ลบ',
                          onPressed: () => _confirmDelete(item),
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _departmentPanel() {
    Map<String, dynamic>? selectedDivision;
    for (final item in _units) {
      if (item['orgUnitId'] == _selectedDivisionId) {
        selectedDivision = item;
        break;
      }
    }
    final departmentTitle = _mode == 1
        ? 'รายการแผนก'
        : selectedDivision == null
        ? 'แผนก'
        : 'ฝ่าย: ${selectedDivision['nameTh']} → แผนก';
    final departments = _units.where((item) {
      if (item['unitType'] != 'DEP') return false;
      return _mode == 1 || item['parentOrgUnitId'] == _selectedDivisionId;
    }).toList();
    final enabled = _mode == 1 || _selectedDivisionId != null;
    return Card(
      child: Column(
        children: [
          _panelHeader(
            departmentTitle,
            'เพิ่มแผนก',
            enabled ? () => _openForm('DEP') : null,
          ),
          Divider(height: 1, color: Colors.grey.shade300),
          if (!enabled)
            const Expanded(child: Center(child: Text('กรุณาเลือกฝ่าย')))
          else if (departments.isEmpty)
            const Expanded(child: Center(child: Text('ยังไม่มีข้อมูลแผนก')))
          else
            Expanded(
              child: ListView.separated(
                itemCount: departments.length,
                separatorBuilder: (_, _) => const SizedBox.shrink(),
                itemBuilder: (context, index) {
                  final item = departments[index];
                  return Container(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    child: ListTile(
                    leading: Text('${index + 1}'),
                    title: Text('${item['unitCode']} - ${item['nameTh']}'),
                    trailing: Wrap(
                      children: [
                        IconButton(
                          tooltip: 'แก้ไข',
                          onPressed: () => _openForm('DEP', item: item),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          tooltip: 'ลบ',
                          onPressed: () => _confirmDelete(item),
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _panelHeader(String title, String buttonText, VoidCallback? onTap) =>
      Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            FilledButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.add),
              label: Text(buttonText),
            ),
          ],
        ),
      );

  Widget _buildForm() {
    final action = _editing == null ? 'เพิ่ม' : 'แก้ไข';
    final unitName = _formType == 'DIV' ? 'ฝ่าย' : 'แผนก';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: WorkspacePageTitle(
                title: '$_caption > $action$unitName',
                favoriteKey: 'organizationStructure',
              ),
            ),
            _formButtons(),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Text('สถานะ'),
                      Transform.translate(
                        offset: const Offset(0, -6),
                        child: Switch(
                          value: _active,
                          onChanged: (value) => setState(() => _active = value),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_formType == 'DEP' && _mode == 2) ...[
                    DropdownButtonFormField<int>(
                      key: ValueKey(_selectedDivisionId),
                      initialValue: _selectedDivisionId,
                      decoration: const InputDecoration(labelText: 'ฝ่าย *'),
                      items: _units
                          .where((item) => item['unitType'] == 'DIV')
                          .map(
                            (item) => DropdownMenuItem<int>(
                              value: item['orgUnitId'] as int,
                              child: LaooComboBoxText(
                                '${item['unitCode']} - ${item['nameTh']}',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setState(() => _selectedDivisionId = value),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: _code,
                    decoration: InputDecoration(labelText: 'รหัส$unitName *'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _name,
                    decoration: InputDecoration(labelText: 'ชื่อ$unitName *'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nameEn,
                    decoration: InputDecoration(
                      labelText: 'ชื่อ$unitName (ภาษาอังกฤษ)',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Align(alignment: Alignment.centerRight, child: _formButtons()),
      ],
    );
  }

  Widget _formButtons() => Wrap(
        spacing: 8,
        children: [
          OutlinedButton(onPressed: _saving ? null : _closeForm, child: const Text('ยกเลิก')),
          FilledButton(onPressed: _saving ? null : _save, child: const Text('บันทึก')),
        ],
      );

  Widget _messageBox() {
    return AutoDismissMessage(
      key: ValueKey(_message),
      message: _message!,
      error: _messageError,
      onClose: () => setState(() => _message = null),
    );
  }

  Future<void> _changeMode(int value) async {
    if (value == _mode) return;
    setState(() => _saving = true);
    try {
      await _repository.updateMode(value);
      setState(() {
        _mode = value;
        _selectedDivisionId = null;
      });
      _showMessage('บันทึกรูปแบบโครงสร้างองค์กรสำเร็จ');
      await _load(clearMessage: false);
    } catch (error) {
      _showMessage(_errorMessage(error), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _openForm(String type, {Map<String, dynamic>? item}) {
    setState(() {
      _formType = type;
      _editing = item;
      _code.text = item?['unitCode']?.toString() ?? '';
      _name.text = item?['nameTh']?.toString() ?? '';
      _nameEn.text = item?['nameEn']?.toString() ?? '';
      _active = item?['isActive'] as bool? ?? true;
      if (type == 'DEP' && item != null) {
        _selectedDivisionId = item['parentOrgUnitId'] as int?;
      }
      _message = null;
    });
  }

  void _closeForm() => setState(() {
        _formType = null;
        _editing = null;
        _message = null;
      });

  Future<void> _save() async {
    if (_code.text.trim().isEmpty || _name.text.trim().isEmpty) {
      _showMessage('กรุณากรอกรหัสและชื่อให้ครบ', error: true);
      return;
    }
    if (_formType == 'DEP' && _mode == 2 && _selectedDivisionId == null) {
      _showMessage('กรุณาเลือกฝ่าย', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final body = {
        'unitType': _formType,
        'parentOrgUnitId': _formType == 'DEP' && _mode == 2
            ? _selectedDivisionId
            : null,
        'unitCode': _code.text.trim().toUpperCase(),
        'nameTh': _name.text.trim(),
        'nameEn': _nameEn.text.trim().isEmpty ? null : _nameEn.text.trim(),
        'isActive': _active,
      };
      if (_editing == null) {
        await _repository.create(body);
        _code.clear();
        _name.clear();
        _nameEn.clear();
        _showMessage('เพิ่มข้อมูลสำเร็จ');
        await _load(clearMessage: false);
      } else {
        await _repository.update(
          _editing!['orgUnitId'] as int,
          body,
        );
        _closeForm();
        await _load(clearMessage: false);
        _showMessage('แก้ไขข้อมูลสำเร็จ');
      }
    } catch (error) {
      _showMessage(_errorMessage(error), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmDelete(Map<String, dynamic> item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final red = Theme.of(dialogContext).colorScheme.error;
        return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: red),
        ),
        title: Row(children: [
          Icon(Icons.delete_outline, color: red),
          const SizedBox(width: 8),
          Text('ยืนยันการลบ', style: TextStyle(color: red)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: red.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('${item['unitCode']} - ${item['nameTh']}'),
          ),
          const SizedBox(height: 12),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('ข้อมูลที่ลบแล้วไม่สามารถเรียกคืนได้'),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.delete_outline),
              SizedBox(width: 6),
              Text('ลบ'),
            ]),
          ),
        ],
      );
      },
    );
    if (confirmed != true) return;
    try {
      await _repository.delete(item['orgUnitId'] as int);
      await _load(clearMessage: false);
      _showMessage('ลบข้อมูลสำเร็จ', error: true);
    } catch (error) {
      _showMessage(_errorMessage(error), error: true);
    }
  }
}
