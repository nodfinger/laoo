import 'package:flutter/material.dart';
import '../../../app/theme/laoo_design_tokens.dart';
import '../../../app/theme/laoo_typography.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/navigation/navigation_menu_repository.dart';
import '../../../core/widgets/auto_dismiss_message.dart';
import '../presentation/widgets/support_workspace_shell.dart';

class LocationPage extends StatefulWidget {
  const LocationPage({super.key});
  @override
  State<LocationPage> createState() => _LocationPageState();
}

class _LocationPageState extends State<LocationPage> {
  final _api = ApiClient();
  final _search = TextEditingController(),
      _code = TextEditingController(),
      _name = TextEditingController();
  final _form = GlobalKey<FormState>();
  Map<String, dynamic> _data = {};
  String _caption = '', _kind = 'buildings', _query = '', _type = 'RESIDENTIAL';
  String? _message;
  int? _building, _floor, _id;
  int _page = 0;
  bool _loading = true,
      _saving = false,
      _editing = false,
      _active = true,
      _cards = false,
      _error = false;
  static const _labels = {
    'buildings': 'อาคาร/ตึก',
    'floors': 'ชั้น',
    'rooms': 'ห้อง',
  };
  static const _types = {
    'RESIDENTIAL': 'ห้องพัก',
    'OFFICE': 'ห้องทำงาน',
    'COMMON': 'พื้นที่ส่วนกลาง',
    'OTHER': 'อื่น ๆ',
  };
  List<Map<String, dynamic>> _rows(String kind) =>
      ((_data[kind] as List?) ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
  bool _can(String action) => (_data['actions'] as Map?)?[action] == true;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final caption = await NavigationMenuRepository(apiClient: _api)
          .resolveMenuName(
            menuCode: '14001',
            routeName: 'assetLocations',
            fallback: '',
          );
      final data = Map<String, dynamic>.from(
        await _api.get('/api/company/locations') as Map,
      );
      if (mounted) {
        setState(() {
          _caption = caption;
          _data = data;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _fail(e);
      }
    }
  }

  void _fail(Object e) => setState(() {
    _error = true;
    _message = e is ApiException
        ? '${e.message}\nรายละเอียดเพิ่มเติม: ${e.description ?? 'กรุณาโหลดข้อมูลใหม่แล้วลองอีกครั้ง'}'
        : 'ดำเนินการไม่สำเร็จ\nรายละเอียดเพิ่มเติม: กรุณาตรวจสอบการเชื่อมต่อแล้วลองใหม่';
  });
  String? _description;
  Future<void> _edit([Map<String, dynamic>? r]) async {
    _code.text = r?['code'] as String? ?? '';
    _name.text = r?['name'] as String? ?? '';
    setState(() {
      _id = r?['id'] as int?;
      _active = r?['active'] as bool? ?? true;
      _type = r?['type'] as String? ?? 'RESIDENTIAL';
      _description = r?['description'] as String?;
      _editing = false;
    });
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: !_saving,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) =>
            _actionDialog(dialogContext, setDialogState),
      ),
    );
  }

  Future<bool> _save({VoidCallback? onSavingChanged}) async {
    if (!_form.currentState!.validate() || _saving) return false;
    setState(() => _saving = true);
    onSavingChanged?.call();
    try {
      final body = {
        'code': _code.text.trim(),
        'name': _name.text.trim(),
        'parentId': _kind == 'floors' ? _building : _floor,
        'type': _type,
        'description': _description,
        'active': _active,
      };
      final path = '/api/company/locations/$_kind';
      final result = _id == null
          ? await _api.post(path, body: body)
          : await _api.put('$path/$_id', body: body);
      if (!mounted) return false;
      setState(() {
        _id = (result as Map)['id'] as int;
        _error = false;
        _message = 'บันทึกข้อมูลเรียบร้อย';
      });
      await _load();
      return true;
    } catch (e) {
      if (mounted) _fail(e);
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
      onSavingChanged?.call();
    }
  }

  Widget _actionDialog(BuildContext dialogContext, StateSetter setDialogState) {
    final primary = Theme.of(dialogContext).colorScheme.primary;
    final popupWidth =
        (MediaQuery.sizeOf(dialogContext).width -
                (LaooLayout.dialogInsetPadding * 2))
            .clamp(0.0, 480.0)
            .toDouble();
    final title =
        '$_caption > ${_id == null ? 'เพิ่ม' : 'แก้ไข'}${_labels[_kind]}';
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(LaooLayout.dialogInsetPadding),
      contentPadding: EdgeInsets.zero,
      titlePadding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LaooRadius.xs),
      ),
      title: Row(
        children: [
          Icon(Icons.edit_outlined, color: primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.black,
                fontSize: LaooTypography.workspaceCaption,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: popupWidth,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: LaooLayout.cardPadding,
          ),
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(height: 1, color: LaooColors.border),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text(
                      'สถานะ',
                      style: TextStyle(fontSize: LaooTypography.inputLabel),
                    ),
                    const SizedBox(width: 8),
                    Switch(
                      value: _active,
                      onChanged: _saving
                          ? null
                          : (v) => setDialogState(() => _active = v),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _code,
                  maxLength: 20,
                  style: const TextStyle(fontSize: LaooTypography.inputText),
                  decoration: _controlDecoration(labelText: 'รหัส *'),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'กรุณาระบุรหัส' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _name,
                  maxLength: 200,
                  style: const TextStyle(fontSize: LaooTypography.inputText),
                  decoration: _controlDecoration(labelText: 'ชื่อ *'),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'กรุณาระบุชื่อ' : null,
                ),
                if (_kind == 'rooms') ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _type,
                    style: const TextStyle(fontSize: LaooTypography.comboBox),
                    decoration: _controlDecoration(labelText: 'ประเภทห้อง *'),
                    items: _types.entries
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(
                              e.value,
                              style: const TextStyle(
                                fontSize: LaooTypography.comboBox,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (v) => setDialogState(() => _type = v!),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: _description,
                    maxLength: 1000,
                    maxLines: 3,
                    style: const TextStyle(fontSize: LaooTypography.inputText),
                    decoration: _controlDecoration(labelText: 'รายละเอียด'),
                    onChanged: (v) => _description = v,
                  ),
                ],
                const SizedBox(height: 12),
                const Divider(height: 1, color: LaooColors.border),
              ],
            ),
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      actions: [
        SizedBox(
          height: LaooTypography.buttonHeight,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(LaooRadius.xs),
              ),
            ),
            onPressed: _saving ? null : () => Navigator.pop(dialogContext),
            child: const Text('ยกเลิก'),
          ),
        ),
        SizedBox(
          height: LaooTypography.buttonHeight,
          child: FilledButton(
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(LaooRadius.xs),
              ),
            ),
            onPressed: _saving
                ? null
                : () async {
                    if (await _save(
                          onSavingChanged: () => setDialogState(() {}),
                        ) &&
                        dialogContext.mounted) {
                      Navigator.pop(dialogContext);
                    }
                  },
            child: Text(_saving ? 'กำลังบันทึก…' : 'บันทึก'),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _api.dispose();
    _search.dispose();
    _code.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    final primary = Theme.of(context).colorScheme.primary;
    final danger = Theme.of(context).colorScheme.error;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LaooRadius.xs),
        ),
        title: Row(
          children: [
            Icon(Icons.delete_outline, color: primary),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'ยืนยันการลบข้อมูล',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: LaooTypography.workspaceCaption,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(LaooLayout.cardPadding),
              color: danger.withValues(alpha: .1),
              child: Text('${row['code']} | ${row['name']}'),
            ),
            const SizedBox(height: 12),
            const Text('เมื่อลบแล้วจะไม่สามารถเรียกคืนได้'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: danger,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(LaooRadius.xs),
              ),
            ),
            onPressed: () => Navigator.pop(dialog, true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _api.delete('/api/company/locations/$_kind/${row['id']}');
      if (!mounted) return;
      setState(() {
        _message = 'ลบข้อมูลเรียบร้อย';
        _error = false;
      });
      await _load();
    } catch (e) {
      if (mounted) _fail(e);
    }
  }

  Widget _card(Widget child) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(LaooLayout.cardPadding),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(LaooRadius.xs),
    ),
    child: Theme(
      data: Theme.of(context).copyWith(
        filledButtonTheme: FilledButtonThemeData(
          style:
              Theme.of(context).filledButtonTheme.style?.copyWith(
                shape: WidgetStatePropertyAll(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(LaooRadius.xs),
                  ),
                ),
              ) ??
              FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(LaooRadius.xs),
                ),
              ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style:
              Theme.of(context).outlinedButtonTheme.style?.copyWith(
                shape: WidgetStatePropertyAll(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(LaooRadius.xs),
                  ),
                ),
              ) ??
              OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(LaooRadius.xs),
                ),
              ),
        ),
      ),
      child: child,
    ),
  );
  Widget _select(
    String label,
    int? value,
    List<Map<String, dynamic>> rows,
    ValueChanged<int?> change, {
    double width = 260,
  }) => SizedBox(
    width: width,
    child: DropdownButtonFormField<int>(
      key: ValueKey((label, value, rows.length)),
      initialValue: value,
      isExpanded: true,
      style: TextStyle(
        fontSize: LaooTypography.comboBox,
        color: Theme.of(context).colorScheme.onSurface,
      ),
      decoration: _controlDecoration(labelText: label),
      items: rows
          .map(
            (r) => DropdownMenuItem<int>(
              value: r['id'] as int,
              child: Text(
                '${r['code']} | ${r['name']}',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: LaooTypography.comboBox),
              ),
            ),
          )
          .toList(),
      onChanged: change,
    ),
  );

  InputDecoration _controlDecoration({
    String? labelText,
    String? hintText,
    IconData? prefixIcon,
  }) {
    final radius = BorderRadius.circular(LaooRadius.xs);
    final primary = Theme.of(context).colorScheme.primary;
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
      hintStyle: const TextStyle(fontSize: LaooTypography.inputHint),
      isDense: true,
      labelStyle: const TextStyle(fontSize: LaooTypography.inputHint),
      floatingLabelStyle: const TextStyle(fontSize: LaooTypography.inputLabel),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: LaooColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: const BorderSide(color: LaooColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: primary),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => SupportWorkspaceShell(
    pageTitle: _caption,
    activeMenu: '14001',
    menuScope: WorkspaceMenuScope.company,
    child: LayoutBuilder(
      builder: (context, box) {
        final compact = box.maxWidth < 900;
        final records = _rows(_kind)
            .where(
              (r) =>
                  (_kind == 'buildings' ||
                      r['parentId'] ==
                          (_kind == 'floors' ? _building : _floor)) &&
                  '${r['code']} ${r['name']}'.toLowerCase().contains(
                    _query.toLowerCase(),
                  ),
            )
            .toList();
        final pages = (records.length / 20).ceil(),
            current = records.isEmpty
                ? 0
                : _page.clamp(0, (records.length - 1) ~/ 20);
        final visible = records.skip(current * 20).take(20).toList();
        final primary = Theme.of(context).colorScheme.primary;
        Widget editButton(Map<String, dynamic> r) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_can('edit'))
              IconButton(
                tooltip: 'แก้ไข',
                color: primary,
                onPressed: () => _edit(r),
                icon: const Icon(Icons.edit_outlined),
              ),
            if (_can('delete'))
              IconButton(
                tooltip: 'ลบ',
                color: Theme.of(context).colorScheme.error,
                onPressed: () => _delete(r),
                icon: const Icon(Icons.delete_outline),
              ),
          ],
        );
        final searchControls = SizedBox(
          width: compact ? double.infinity : 438,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  style: const TextStyle(fontSize: LaooTypography.inputText),
                  decoration: _controlDecoration(
                    hintText: 'ค้นหารหัสหรือชื่อ',
                    prefixIcon: Icons.search,
                  ),
                  onSubmitted: (_) => setState(() {
                    _query = _search.text.trim();
                    _page = 0;
                  }),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 40,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    maximumSize: const Size(double.infinity, 40),
                  ),
                  onPressed: () => setState(() {
                    _query = _search.text.trim();
                    _page = 0;
                  }),
                  child: const Text('ค้นหา'),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 40,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    maximumSize: const Size(double.infinity, 40),
                  ),
                  onPressed: () => setState(() {
                    _search.clear();
                    _query = '';
                    _page = 0;
                  }),
                  child: const Text('ล้าง Filter'),
                ),
              ),
            ],
          ),
        );
        return Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(LaooLayout.cardMargin),
              child: Column(
                children: [
                  _card(
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        WorkspacePageTitle(
                          title: _editing
                              ? '$_caption > ${_id == null ? 'เพิ่ม' : 'แก้ไข'}${_labels[_kind]}'
                              : _caption,
                          favoriteKey: '14001',
                        ),
                        Wrap(
                          spacing: 8,
                          children: _editing
                              ? [
                                  OutlinedButton(
                                    onPressed: _saving
                                        ? null
                                        : () =>
                                              setState(() => _editing = false),
                                    child: const Text('กลับรายการ'),
                                  ),
                                  if (_can(_id == null ? 'create' : 'edit'))
                                    FilledButton(
                                      onPressed: _saving ? null : _save,
                                      child: Text(
                                        _saving ? 'กำลังบันทึก…' : 'บันทึก',
                                      ),
                                    ),
                                ]
                              : [
                                  if (!compact)
                                    IconButton(
                                      tooltip: 'สลับ Card/List',
                                      onPressed: () =>
                                          setState(() => _cards = !_cards),
                                      icon: Icon(
                                        _cards
                                            ? Icons.view_list
                                            : Icons.grid_view,
                                      ),
                                    ),
                                  if (_can('create') &&
                                      (_kind == 'buildings' ||
                                          (_kind == 'floors'
                                                  ? _building
                                                  : _floor) !=
                                              null))
                                    FilledButton.icon(
                                      style: FilledButton.styleFrom(
                                        minimumSize: const Size(
                                          0,
                                          LaooTypography.buttonHeight,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                        ),
                                      ),
                                      onPressed: () => _edit(),
                                      icon: const Icon(Icons.add),
                                      label: Text('เพิ่ม${_labels[_kind]}'),
                                    ),
                                ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (!_editing)
                    _card(
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          ..._labels.entries.map(
                            (e) => ChoiceChip(
                              label: Text(e.value),
                              selected: _kind == e.key,
                              onSelected: (_) => setState(() {
                                _kind = e.key;
                                _query = '';
                                _search.clear();
                                _page = 0;
                              }),
                            ),
                          ),
                          if (_kind == 'rooms') searchControls,
                          if (_kind != 'buildings')
                            _select(
                              'อาคาร/ตึก',
                              _building,
                              _rows('buildings'),
                              (v) => setState(() {
                                _building = v;
                                _floor = null;
                                _page = 0;
                              }),
                              width: 220,
                            ),
                          if (_kind == 'rooms')
                            _select(
                              'ชั้น',
                              _floor,
                              _rows('floors')
                                  .where((r) => r['parentId'] == _building)
                                  .toList(),
                              (v) => setState(() {
                                _floor = v;
                                _page = 0;
                              }),
                              width: 150,
                            ),
                          if (_kind != 'rooms') searchControls,
                        ],
                      ),
                    ),
                  const SizedBox(height: LaooLayout.cardSpacing),
                  Expanded(
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : _editing
                        ? SingleChildScrollView(
                            child: _card(
                              Form(
                                key: _form,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Text('สถานะ'),
                                        Switch(
                                          value: _active,
                                          onChanged: _saving
                                              ? null
                                              : (v) =>
                                                    setState(() => _active = v),
                                        ),
                                      ],
                                    ),
                                    TextFormField(
                                      controller: _code,
                                      maxLength: 20,
                                      style: const TextStyle(
                                        fontSize: LaooTypography.inputText,
                                      ),
                                      decoration: _controlDecoration(
                                        labelText: 'รหัส *',
                                      ),
                                      validator: (v) =>
                                          v == null || v.trim().isEmpty
                                          ? 'กรุณาระบุรหัส'
                                          : null,
                                    ),
                                    const SizedBox(height: 12),
                                    TextFormField(
                                      controller: _name,
                                      maxLength: 200,
                                      style: const TextStyle(
                                        fontSize: LaooTypography.inputText,
                                      ),
                                      decoration: _controlDecoration(
                                        labelText: 'ชื่อ *',
                                      ),
                                      validator: (v) =>
                                          v == null || v.trim().isEmpty
                                          ? 'กรุณาระบุชื่อ'
                                          : null,
                                    ),
                                    if (_kind == 'rooms') ...[
                                      const SizedBox(height: 12),
                                      DropdownButtonFormField<String>(
                                        initialValue: _type,
                                        style: const TextStyle(
                                          fontSize: LaooTypography.comboBox,
                                        ),
                                        decoration: _controlDecoration(
                                          labelText: 'ประเภทห้อง *',
                                        ),
                                        items: _types.entries
                                            .map(
                                              (e) => DropdownMenuItem(
                                                value: e.key,
                                                child: Text(
                                                  e.value,
                                                  style: const TextStyle(
                                                    fontSize:
                                                        LaooTypography.comboBox,
                                                  ),
                                                ),
                                              ),
                                            )
                                            .toList(),
                                        onChanged: (v) =>
                                            setState(() => _type = v!),
                                      ),
                                      const SizedBox(height: 12),
                                      TextFormField(
                                        initialValue: _description,
                                        maxLength: 1000,
                                        maxLines: 3,
                                        style: const TextStyle(
                                          fontSize: LaooTypography.inputText,
                                        ),
                                        decoration: _controlDecoration(
                                          labelText: 'รายละเอียด',
                                        ),
                                        onChanged: (v) => _description = v,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          )
                        : visible.isEmpty
                        ? _card(
                            Center(
                              child: Text(
                                _kind != 'buildings' &&
                                        (_kind == 'floors'
                                                ? _building
                                                : _floor) ==
                                            null
                                    ? 'กรุณาเลือกอาคารและชั้น'
                                    : 'ไม่พบข้อมูล',
                              ),
                            ),
                          )
                        : compact || _cards
                        ? ListView.separated(
                            itemCount: visible.length,
                            separatorBuilder: (_, i) =>
                                const SizedBox(height: 6),
                            itemBuilder: (_, i) {
                              final r = visible[i];
                              return _card(
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text('${r['code']} | ${r['name']}'),
                                  subtitle: Text(
                                    r['active'] == true
                                        ? 'ใช้งาน'
                                        : 'ไม่ใช้งาน',
                                  ),
                                  trailing: editButton(r),
                                ),
                              );
                            },
                          )
                        : _card(
                            SingleChildScrollView(
                              child: SizedBox(
                                width: double.infinity,
                                child: DataTable(
                                  headingRowColor: WidgetStatePropertyAll(
                                    primary.withValues(alpha: .1),
                                  ),
                                  columns: const [
                                    DataColumn(label: Text('ID')),
                                    DataColumn(label: Text('Action')),
                                    DataColumn(label: Text('รหัส')),
                                    DataColumn(label: Text('ชื่อ')),
                                    DataColumn(label: Text('สถานะ')),
                                  ],
                                  rows: visible.asMap().entries.map((e) {
                                    final r = e.value;
                                    return DataRow(
                                      cells: [
                                        DataCell(
                                          Text('${current * 20 + e.key + 1}'),
                                        ),
                                        DataCell(editButton(r)),
                                        DataCell(Text('${r['code']}')),
                                        DataCell(Text('${r['name']}')),
                                        DataCell(
                                          Text(
                                            r['active'] == true
                                                ? 'ใช้งาน'
                                                : 'ไม่ใช้งาน',
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ),
                  ),
                  if (!_editing) ...[
                    const SizedBox(height: LaooLayout.cardSpacing),
                    const Divider(height: 1, color: LaooColors.border),
                    SizedBox(
                      height: LaooLayout.paginationCardHeight,
                      child: _card(
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _paginationButton(
                              icon: Icons.chevron_left,
                              primary: primary,
                              enabled: current > 0,
                              onPressed: () =>
                                  setState(() => _page = current - 1),
                            ),
                            _paginationButton(
                              label: '${pages == 0 ? 0 : current + 1}',
                              primary: primary,
                              current: true,
                              enabled: pages > 0,
                              onPressed: () {},
                            ),
                            _paginationButton(
                              icon: Icons.chevron_right,
                              primary: primary,
                              enabled: current + 1 < pages,
                              onPressed: () =>
                                  setState(() => _page = current + 1),
                            ),
                            Text(
                              '${records.isEmpty ? 0 : current * 20 + 1}-${current * 20 + visible.length} จาก ${records.length}',
                              style: const TextStyle(
                                fontSize: LaooTypography.tableBody,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (_message != null)
              Positioned(
                top: 10,
                right: 10,
                left: 10,
                child: AutoDismissMessage(
                  message: _message!,
                  error: _error,
                  onClose: () {
                    if (mounted) setState(() => _message = null);
                  },
                ),
              ),
          ],
        );
      },
    ),
  );

  Widget _paginationButton({
    IconData? icon,
    String? label,
    required Color primary,
    required bool enabled,
    required VoidCallback onPressed,
    bool current = false,
  }) => SizedBox(
    width: 36,
    height: 36,
    child: OutlinedButton(
      onPressed: enabled ? onPressed : null,
      style: ButtonStyle(
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        minimumSize: const WidgetStatePropertyAll(Size(36, 36)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(LaooRadius.xs),
          ),
        ),
        side: WidgetStateProperty.resolveWith(
          (states) => BorderSide(
            color: states.contains(WidgetState.disabled)
                ? LaooColors.border
                : primary,
          ),
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? LaooColors.textSecondary
              : current
              ? Colors.white
              : primary,
        ),
        backgroundColor: WidgetStatePropertyAll(
          current && enabled ? primary : Colors.white,
        ),
      ),
      child: icon == null
          ? Text(
              label ?? '',
              style: const TextStyle(fontWeight: FontWeight.w700),
            )
          : Icon(icon, size: 20),
    ),
  );
}
