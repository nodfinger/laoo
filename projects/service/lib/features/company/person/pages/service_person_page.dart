import 'package:flutter/material.dart';

import '../../../../app/theme/laoo_design_tokens.dart';
import '../../../../app/theme/laoo_typography.dart';
import '../../../../app/theme/workspace_theme_presets.dart';
import '../../../../core/api/api_exception.dart';
import '../../../../core/company_setup/company_setup_controller.dart';
import '../../../../core/navigation/navigation_menu_repository.dart';
import '../../../../core/widgets/pinned_data_table.dart';
import '../../../../core/widgets/timed_snack_bar.dart';
import '../../../../features/support/presentation/widgets/support_workspace_shell.dart';
import '../data/service_person_api.dart';

enum ServicePersonRole { customer, resident }

class ServicePersonPage extends StatefulWidget {
  const ServicePersonPage({super.key, required this.role});
  final ServicePersonRole role;
  @override
  State<ServicePersonPage> createState() => _ServicePersonPageState();
}

class _ServicePersonPageState extends State<ServicePersonPage> {
  String _caption = '';
  @override
  void initState() {
    super.initState();
    NavigationMenuRepository()
        .resolveMenuName(
          menuCode: widget.role == ServicePersonRole.customer
              ? '14005'
              : '14006',
          routeName: widget.role == ServicePersonRole.customer
              ? 'serviceCustomers'
              : 'serviceResidents',
        )
        .then((value) {
          if (mounted) setState(() => _caption = value);
        });
  }

  @override
  Widget build(BuildContext context) => SupportWorkspaceShell(
    pageTitle: _caption,
    activeMenu: widget.role == ServicePersonRole.customer
        ? 'serviceCustomers'
        : 'serviceResidents',
    menuScope: WorkspaceMenuScope.company,
    child: ServicePersonWorkspace(caption: _caption, role: widget.role),
  );
}

class ServicePersonWorkspace extends StatefulWidget {
  const ServicePersonWorkspace({
    super.key,
    required this.caption,
    required this.role,
    this.api,
  });
  final String caption;
  final ServicePersonRole role;
  final ServicePersonApi? api;
  @override
  State<ServicePersonWorkspace> createState() => _ServicePersonWorkspaceState();
}

class _ServicePersonWorkspaceState extends State<ServicePersonWorkspace> {
  late final ServicePersonApi _api =
      widget.api ??
      ServicePersonApi(
        path: widget.role == ServicePersonRole.customer
            ? '/api/service/customers'
            : '/api/service/residents',
      );
  final _search = TextEditingController();
  List<Map<String, dynamic>> _rows = const [];
  Map<String, bool> _actions = const {};
  String _query = '';
  bool? _active;
  bool _loading = true;
  bool _cards = false;
  int _page = 1;
  int _total = 0;
  int _request = 0;
  int get _pageSize => companySetupController.pageSize.clamp(1, 200);
  Color get _primary => workspaceThemeController.value.primary;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    if (widget.api == null) _api.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() => _loading = true);
    try {
      final actions = await _api.actions();
      final result = actions['view'] == true
          ? await _api.list(
              search: _query,
              isActive: _active,
              page: _page,
              pageSize: _pageSize,
            )
          : <String, dynamic>{'items': const [], 'total': 0};
      if (!mounted || request != _request) return;
      final total = (result['total'] as num?)?.toInt() ?? 0;
      final last = total == 0 ? 1 : (total / _pageSize).ceil();
      if (_page > last) {
        _page = last;
        await _load();
        return;
      }
      setState(() {
        _actions = actions;
        _rows = List<Map<String, dynamic>>.from(
          result['items'] as List? ?? const [],
        );
        _total = total;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || request != _request) return;
      setState(() {
        _rows = const [];
        _loading = false;
      });
      _notify(error);
    }
  }

  void _notify(Object error, {bool success = false}) {
    final message = error is ApiException
        ? '${error.message}\nรายละเอียดเพิ่มเติม:: ${error.description ?? 'กรุณาตรวจสอบข้อมูลแล้วลองใหม่'}'
        : success
        ? '$error'
        : 'ดำเนินการทะเบียนบุคคลไม่สำเร็จ\nรายละเอียดเพิ่มเติม:: กรุณาตรวจสอบการเชื่อมต่อแล้วลองใหม่';
    showTimedSnackBar(context, message: message, error: !success);
  }

  Future<void> _open([Map<String, dynamic>? row]) async {
    if ((row == null ? _actions['create'] : _actions['edit']) != true) return;
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ServicePersonDialog(
        api: _api,
        caption: widget.caption,
        initial: row,
        role: widget.role,
        canEditPerson: _actions['personEdit'] == true,
      ),
    );
    if (saved == true && mounted) {
      _notify('บันทึกทะเบียนบุคคลสำเร็จ', success: true);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final compact = box.maxWidth < 900;
      return ColoredBox(
        color: LaooColors.background,
        child: Padding(
          padding: const EdgeInsets.all(LaooLayout.cardMargin),
          child: Column(
            children: [
              _surface(
                Row(
                  children: [
                    Expanded(
                      child: WorkspacePageTitle(
                        title: widget.caption,
                        favoriteKey: widget.role == ServicePersonRole.customer
                            ? '14005'
                            : '14006',
                      ),
                    ),
                    if (!compact)
                      IconButton(
                        tooltip: 'สลับ Card/List',
                        color: _primary,
                        onPressed: () => setState(() => _cards = !_cards),
                        icon: Icon(
                          _cards
                              ? Icons.view_list_outlined
                              : Icons.grid_view_outlined,
                        ),
                      ),
                    if (_actions['create'] == true)
                      FilledButton.icon(
                        style: _button(true),
                        onPressed: () => _open(),
                        icon: const Icon(Icons.add),
                        label: const Text('เพิ่ม'),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              _surface(
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: compact ? box.maxWidth - 40 : 360,
                      child: TextField(
                        controller: _search,
                        decoration: _input(
                          hint: 'ค้นหาชื่อ ชื่อเล่น โทรศัพท์ หรืออีเมล',
                          icon: Icons.search,
                        ),
                        onSubmitted: (_) => _searchNow(),
                      ),
                    ),
                    SizedBox(
                      width: compact ? box.maxWidth - 40 : 180,
                      child: DropdownButtonFormField<bool?>(
                        isExpanded: true,
                        initialValue: _active,
                        decoration: _input(label: 'สถานะ'),
                        items: const [
                          DropdownMenuItem(value: null, child: Text('ทั้งหมด')),
                          DropdownMenuItem(value: true, child: Text('ใช้งาน')),
                          DropdownMenuItem(
                            value: false,
                            child: Text('ไม่ใช้งาน'),
                          ),
                        ],
                        onChanged: (value) => setState(() => _active = value),
                      ),
                    ),
                    FilledButton(
                      style: _button(true),
                      onPressed: _loading ? null : _searchNow,
                      child: const Text('ค้นหา'),
                    ),
                    OutlinedButton(
                      style: _button(false),
                      onPressed: _loading
                          ? null
                          : () {
                              _search.clear();
                              _query = '';
                              _active = null;
                              _page = 1;
                              _load();
                            },
                      child: const Text('ล้าง Filter'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: LaooLayout.cardSpacing),
              Expanded(child: _content(compact || _cards)),
              const SizedBox(height: LaooLayout.cardSpacing),
              _pagination(),
            ],
          ),
        ),
      );
    },
  );

  void _searchNow() {
    _query = _search.text.trim();
    _page = 1;
    _load();
  }

  Widget _content(bool cards) {
    if (_loading) {
      return _surface(const Center(child: CircularProgressIndicator()));
    }
    if (_actions['view'] != true) {
      return _surface(const Center(child: Text('ไม่มีสิทธิ์แสดงทะเบียนบุคคล')));
    }
    if (_rows.isEmpty) {
      return _surface(
        const Center(child: Text('ไม่พบข้อมูลบุคคลที่มีบทบาทในระบบ Service')),
      );
    }
    if (cards) {
      return ListView.separated(
        itemCount: _rows.length,
        separatorBuilder: (_, _) => const SizedBox(height: 6),
        itemBuilder: (_, index) {
          final row = _rows[index];
          return _surface(
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${(_page - 1) * _pageSize + index + 1}. ${row['fullName']}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _roleChips(row),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${row['nickName'] ?? '-'} • ${row['mobile'] ?? '-'} • ${row['email'] ?? '-'}',
                      ),
                      Text(row['isActive'] == true ? 'ใช้งาน' : 'ไม่ใช้งาน'),
                    ],
                  ),
                ),
                if (_actions['edit'] == true)
                  IconButton(
                    tooltip: 'แก้ไข',
                    color: _primary,
                    onPressed: () => _open(row),
                    icon: const Icon(Icons.edit_outlined),
                  ),
              ],
            ),
          );
        },
      );
    }
    return _surface(
      PinnedDataTable(
        maxBodyHeight: double.infinity,
        headingRowColor: WidgetStatePropertyAll(_primary.withValues(alpha: .1)),
        headingTextStyle: TextStyle(
          color: _primary,
          fontSize: LaooTypography.tableHeader,
          fontWeight: FontWeight.w700,
        ),
        dataTextStyle: const TextStyle(
          fontSize: LaooTypography.tableBody,
          color: LaooColors.textPrimary,
        ),
        dividerThickness: 1,
        columns: const [
          LaooTableColumns.id,
          DataColumn(
            label: Center(child: Text('Action')),
            columnWidth: FixedColumnWidth(112),
          ),
          DataColumn(
            label: Text('ชื่อบุคคล'),
            columnWidth: FixedColumnWidth(180),
          ),
          DataColumn(label: Text('บทบาท'), columnWidth: FixedColumnWidth(240)),
          DataColumn(label: Text('ชื่อเล่น')),
          DataColumn(label: Text('โทรศัพท์')),
          DataColumn(label: Text('อีเมล')),
          DataColumn(label: Text('สถานะ')),
        ],
        rows: [
          for (var i = 0; i < _rows.length; i++)
            DataRow(
              cells: [
                DataCell(Text('${(_page - 1) * _pageSize + i + 1}')),
                DataCell(
                  Center(
                    child: _actions['edit'] == true
                        ? IconButton(
                            tooltip: 'แก้ไข',
                            color: _primary,
                            onPressed: () => _open(_rows[i]),
                            icon: const Icon(Icons.edit_outlined),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
                DataCell(Text('${_rows[i]['fullName']}')),
                DataCell(
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: _roleChips(_rows[i]),
                  ),
                ),
                DataCell(Text('${_rows[i]['nickName'] ?? '-'}')),
                DataCell(Text('${_rows[i]['mobile'] ?? '-'}')),
                DataCell(Text('${_rows[i]['email'] ?? '-'}')),
                DataCell(
                  Text(_rows[i]['isActive'] == true ? 'ใช้งาน' : 'ไม่ใช้งาน'),
                ),
              ],
            ),
        ],
      ),
      padding: EdgeInsets.zero,
    );
  }

  List<Widget> _roleChips(Map<String, dynamic> row) => [
    for (final role in List<String>.from(
      row['serviceRoles'] as List? ?? const [],
    ))
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _primary.withValues(alpha: .1),
          borderRadius: BorderRadius.circular(LaooRadius.xs),
        ),
        child: Text(
          role == 'RESIDENT'
              ? 'ผู้พักอาศัย'
              : role == 'REQUESTER'
              ? 'ผู้แจ้งซ่อม'
              : 'ผู้ใช้บริการ',
          style: TextStyle(
            color: _primary,
            fontSize: LaooTypography.bodySmall,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
  ];

  Widget _pagination() {
    final pages = _total == 0 ? 1 : (_total / _pageSize).ceil();
    ButtonStyle style(bool active) => OutlinedButton.styleFrom(
      minimumSize: const Size(48, 48),
      maximumSize: const Size(48, 48),
      padding: EdgeInsets.zero,
      foregroundColor: active ? Colors.white : _primary,
      backgroundColor: active ? _primary : Colors.white,
      side: BorderSide(color: _primary),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(LaooRadius.xs),
      ),
    );
    return _surface(
      SizedBox(
        height: LaooLayout.paginationCardHeight - 20,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton(
                style: style(false),
                onPressed: _page > 1
                    ? () {
                        _page--;
                        _load();
                      }
                    : null,
                child: const Text('<'),
              ),
              OutlinedButton(
                style: style(true),
                onPressed: null,
                child: Text('$_page'),
              ),
              OutlinedButton(
                style: style(false),
                onPressed: _page < pages
                    ? () {
                        _page++;
                        _load();
                      }
                    : null,
                child: const Text('>'),
              ),
              const SizedBox(width: 6),
              Text(
                _total == 0
                    ? '0 รายการ'
                    : '${(_page - 1) * _pageSize + 1}-${(_page * _pageSize).clamp(0, _total)} จาก $_total',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _surface(
    Widget child, {
    EdgeInsetsGeometry padding = const EdgeInsets.all(LaooLayout.cardPadding),
  }) => Container(
    width: double.infinity,
    color: Colors.white,
    padding: padding,
    child: child,
  );
  ButtonStyle _button(bool filled) =>
      (filled ? FilledButton.styleFrom() : OutlinedButton.styleFrom()).copyWith(
        minimumSize: const WidgetStatePropertyAll(
          Size(0, LaooTypography.buttonHeight),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(LaooRadius.xs),
          ),
        ),
      );
  InputDecoration _input({String? label, String? hint, IconData? icon}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon == null ? null : Icon(icon),
        counterText: '',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(LaooRadius.xs),
        ),
      );
}

class _ServicePersonDialog extends StatefulWidget {
  const _ServicePersonDialog({
    required this.api,
    required this.caption,
    required this.role,
    required this.canEditPerson,
    this.initial,
  });
  final ServicePersonApi api;
  final String caption;
  final ServicePersonRole role;
  final bool canEditPerson;
  final Map<String, dynamic>? initial;
  @override
  State<_ServicePersonDialog> createState() => _ServicePersonDialogState();
}

class _ServicePersonDialogState extends State<_ServicePersonDialog> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _nick = TextEditingController();
  final _mobile = TextEditingController();
  final _email = TextEditingController();
  Map<String, dynamic> _lookup = const {};
  int? _personId;
  int? _roomId;
  bool _active = true;
  bool _customer = true;
  bool _resident = false;
  bool _newPerson = true;
  bool _loading = true;
  bool _saving = false;
  bool _saved = false;
  DateTime _start = DateTime.now();
  DateTime? _end;
  bool get _editing => widget.initial != null;
  bool get _dormitory => _lookup['businessTypeCode'] == 'DORMITORY';
  Color get _primary => Theme.of(context).colorScheme.primary;

  @override
  void initState() {
    super.initState();
    final row = widget.initial;
    if (row != null) {
      _newPerson = false;
      _personId = (row['personID'] as num).toInt();
      _name.text = '${row['fullName'] ?? ''}';
      _nick.text = '${row['nickName'] ?? ''}';
      _mobile.text = '${row['mobile'] ?? ''}';
      _email.text = '${row['email'] ?? ''}';
      _active = row['isActive'] == true;
      _customer = widget.role == ServicePersonRole.customer;
      _resident = widget.role == ServicePersonRole.resident;
      _roomId = (row['roomID'] as num?)?.toInt();
      _start = DateTime.tryParse('${row['startDate'] ?? ''}') ?? DateTime.now();
      _end = DateTime.tryParse('${row['endDate'] ?? ''}');
    }
    _loadLookup();
  }

  Future<void> _loadLookup() async {
    try {
      final value = await widget.api.lookup(
        personId: _personId,
        roomId: _roomId,
      );
      if (!mounted) return;
      setState(() {
        _lookup = value;
        _customer = widget.role == ServicePersonRole.customer;
        _resident = widget.role == ServicePersonRole.resident;
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() => _loading = false);
        _error(error);
      }
    }
  }

  void _selectPerson(int? value) {
    setState(() {
      _personId = value;
      final people = List<Map<String, dynamic>>.from(
        _lookup['persons'] as List? ?? const [],
      );
      final match = people
          .where((person) => (person['id'] as num).toInt() == value)
          .firstOrNull;
      _name.text = '${match?['name'] ?? ''}';
      _nick.text = '${match?['nickName'] ?? ''}';
      _mobile.text = '${match?['mobile'] ?? ''}';
      _email.text = '${match?['email'] ?? ''}';
      _active = match?['active'] != false;
    });
  }

  Future<void> _pickDate(bool start) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: start ? _start : (_end ?? _start),
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (start) {
          _start = picked;
        } else {
          _end = picked;
        }
      });
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate() || _saving) return;
    if (!_newPerson && _personId == null) {
      _errorText('กรุณาเลือกบุคคลเดิม');
      return;
    }
    if (_dormitory && !_customer && !_resident) {
      _errorText('กรุณาเลือกอย่างน้อยหนึ่งบทบาท');
      return;
    }
    if (_resident && _roomId == null) {
      _errorText('กรุณาเลือกห้องพัก');
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.api.save({
        'personId': _personId,
        'fullName': _name.text.trim(),
        'nickName': _nick.text.trim(),
        'mobile': _mobile.text.trim(),
        'email': _email.text.trim(),
        'isActive': _active,
        'isServiceCustomer': _customer,
        'isResident': _resident,
        'roomId': _resident ? _roomId : null,
        'startDate': _resident ? _date(_start) : null,
        'endDate': _resident && _end != null ? _date(_end!) : null,
        'updatePerson': _editing && widget.canEditPerson,
        'personRowVersion': widget.initial?['personRowVersion'],
        'serviceCustomerRowVersion':
            widget.initial?['serviceCustomerRowVersion'],
        'residentRowVersion': widget.initial?['residentRowVersion'],
      }, personId: _editing ? _personId : null);
      if (!mounted) return;
      if (_editing) {
        Navigator.pop(context, true);
      } else {
        _saved = true;
        showTimedSnackBar(
          context,
          message:
              '\u0e1a\u0e31\u0e19\u0e17\u0e36\u0e01\u0e17\u0e30\u0e40\u0e1a\u0e35\u0e22\u0e19\u0e1a\u0e38\u0e04\u0e04\u0e25\u0e2a\u0e33\u0e40\u0e23\u0e47\u0e08',
        );
        _form.currentState!.reset();
        _name.clear();
        _nick.clear();
        _mobile.clear();
        _email.clear();
        setState(() {
          _personId = null;
          _roomId = null;
          _active = true;
          _customer = widget.role == ServicePersonRole.customer;
          _resident = widget.role == ServicePersonRole.resident;
          _newPerson = true;
          _start = DateTime.now();
          _end = null;
        });
      }
    } catch (error) {
      if (mounted) _error(error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _error(Object error) => showTimedSnackBar(
    context,
    message: error is ApiException
        ? '${error.message}\nรายละเอียดเพิ่มเติม:: ${error.description ?? 'กรุณาตรวจสอบข้อมูล'}'
        : 'บันทึกไม่สำเร็จ\nรายละเอียดเพิ่มเติม:: กรุณาลองใหม่',
    error: true,
  );
  void _errorText(String text) => showTimedSnackBar(
    context,
    message: '$text\nรายละเอียดเพิ่มเติม:: กรุณาตรวจสอบข้อมูลในแบบฟอร์ม',
    error: true,
  );
  String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: Colors.white,
    surfaceTintColor: Colors.transparent,
    insetPadding: const EdgeInsets.all(20),
    contentPadding: EdgeInsets.zero,
    titlePadding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(LaooRadius.xs),
    ),
    title: Row(
      children: [
        Icon(Icons.person_outline, color: _primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            '${widget.caption} > ${_editing ? 'แก้ไข' : 'เพิ่ม'}',
            style: const TextStyle(
              color: Colors.black,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
    content: SizedBox(
      width: 480,
      child: _loading
          ? const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            )
          : Form(
              key: _form,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Divider(height: 1, color: LaooColors.border),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text('สถานะ', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Switch(
                          value: _active,
                          onChanged: _saving
                              ? null
                              : (value) => setState(() => _active = value),
                        ),
                      ],
                    ),
                    if (!_editing) ...[
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(
                            value: true,
                            label: Text('สร้างบุคคลใหม่'),
                          ),
                          ButtonSegment(
                            value: false,
                            label: Text('เลือกบุคคลเดิม'),
                          ),
                        ],
                        selected: {_newPerson},
                        onSelectionChanged: (value) => setState(() {
                          _newPerson = value.first;
                          if (_newPerson) _selectPerson(null);
                        }),
                      ),
                      const SizedBox(height: 12),
                      if (!_newPerson)
                        DropdownButtonFormField<int>(
                          initialValue: _personId,
                          isExpanded: true,
                          decoration: _input('บุคคล *'),
                          items: [
                            for (final person
                                in List<Map<String, dynamic>>.from(
                                  _lookup['persons'] as List? ?? const [],
                                ))
                              DropdownMenuItem(
                                value: (person['id'] as num).toInt(),
                                child: Text('${person['name']}'),
                              ),
                          ],
                          onChanged: _selectPerson,
                        ),
                      if (!_newPerson) const SizedBox(height: 12),
                    ],
                    if (_editing && widget.canEditPerson)
                      Container(
                        padding: const EdgeInsets.all(10),
                        color: _primary.withValues(alpha: .08),
                        child: const Text(
                          'การแก้ชื่อ โทรศัพท์ หรืออีเมล จะมีผลกับข้อมูลบุคคลกลางและระบบอื่นที่อ้าง PersonID เดียวกัน',
                        ),
                      ),
                    if (_editing && widget.canEditPerson)
                      const SizedBox(height: 12),
                    TextFormField(
                      controller: _name,
                      enabled: _newPerson || widget.canEditPerson,
                      maxLength: 200,
                      decoration: _input('ชื่อ-นามสกุล *'),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'กรุณาระบุชื่อ-นามสกุล'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _nick,
                      enabled: _newPerson || widget.canEditPerson,
                      maxLength: 100,
                      decoration: _input('ชื่อเล่น'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _mobile,
                      enabled: _newPerson || widget.canEditPerson,
                      maxLength: 50,
                      decoration: _input('โทรศัพท์'),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _email,
                      enabled: _newPerson || widget.canEditPerson,
                      maxLength: 320,
                      keyboardType: TextInputType.emailAddress,
                      decoration: _input('อีเมล'),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'บทบาทในระบบ Service',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(10),
                      color: _primary.withValues(alpha: .08),
                      child: Text(
                        widget.role == ServicePersonRole.customer
                            ? 'ผู้ใช้บริการ'
                            : 'ผู้พักอาศัย',
                        style: TextStyle(
                          color: _primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (_resident) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        initialValue: _roomId,
                        isExpanded: true,
                        decoration: _input('ห้องพัก *'),
                        items: [
                          for (final room in List<Map<String, dynamic>>.from(
                            _lookup['rooms'] as List? ?? const [],
                          ))
                            DropdownMenuItem(
                              value: (room['id'] as num).toInt(),
                              child: Text(
                                '${room['code']} ${room['name'] ?? ''}',
                              ),
                            ),
                        ],
                        onChanged: (value) => setState(() => _roomId = value),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => _pickDate(true),
                              child: InputDecorator(
                                decoration: _input('วันเริ่มพัก *'),
                                child: Text(_date(_start)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InkWell(
                              onTap: () => _pickDate(false),
                              child: InputDecorator(
                                decoration: _input('วันสิ้นสุด'),
                                child: Text(_end == null ? '-' : _date(_end!)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 14),
                    const Divider(height: 1, color: LaooColors.border),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          style: _dialogButton(false),
                          onPressed: _saving
                              ? null
                              : () => Navigator.pop(context, _saved),
                          child: const Text('ยกเลิก'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          style: _dialogButton(true),
                          onPressed: _saving ? null : _save,
                          icon: const Icon(Icons.save_outlined),
                          label: const Text('บันทึก'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
    ),
  );

  InputDecoration _input(String label) => InputDecoration(
    labelText: label,
    counterText: '',
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(LaooRadius.xs),
    ),
  );
  ButtonStyle _dialogButton(bool filled) =>
      (filled ? FilledButton.styleFrom() : TextButton.styleFrom()).copyWith(
        minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(LaooRadius.xs),
          ),
        ),
      );
}
