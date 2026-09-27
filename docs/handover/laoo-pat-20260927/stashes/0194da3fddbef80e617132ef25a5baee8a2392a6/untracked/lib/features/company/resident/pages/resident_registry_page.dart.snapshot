import 'package:flutter/material.dart';

import '../../../../app/theme/laoo_design_tokens.dart';
import '../../../../app/theme/laoo_typography.dart';
import '../../../../app/theme/workspace_theme_presets.dart';
import '../../../../core/api/api_exception.dart';
import '../../../../core/company_setup/company_date_formatter.dart';
import '../../../../core/company_setup/company_setup_controller.dart';
import '../../../../core/navigation/navigation_menu_repository.dart';
import '../../../../core/widgets/pinned_data_table.dart';
import '../../../../core/widgets/timed_snack_bar.dart';
import '../../../support/presentation/widgets/support_workspace_shell.dart';
import '../../shared/registry_ui.dart';
import '../data/resident_registry_api.dart';

class ResidentRegistryPage extends StatefulWidget {
  const ResidentRegistryPage({super.key});

  @override
  State<ResidentRegistryPage> createState() => _ResidentRegistryPageState();
}

class _ResidentRegistryPageState extends State<ResidentRegistryPage> {
  String _caption = '';

  @override
  void initState() {
    super.initState();
    NavigationMenuRepository()
        .resolveMenuName(menuCode: '14004', routeName: 'assetResidents')
        .then((value) {
          if (mounted) setState(() => _caption = value);
        });
  }

  @override
  Widget build(BuildContext context) => SupportWorkspaceShell(
    pageTitle: _caption,
    activeMenu: 'assetResidents',
    menuScope: WorkspaceMenuScope.company,
    child: ResidentRegistryWorkspace(caption: _caption),
  );
}

class ResidentRegistryWorkspace extends StatefulWidget {
  const ResidentRegistryWorkspace({super.key, required this.caption, this.api});

  final String caption;
  final ResidentRegistryApi? api;

  @override
  State<ResidentRegistryWorkspace> createState() =>
      _ResidentRegistryWorkspaceState();
}

class _ResidentRegistryWorkspaceState extends State<ResidentRegistryWorkspace> {
  late final ResidentRegistryApi _api = widget.api ?? ResidentRegistryApi();
  final _search = TextEditingController();
  List<Map<String, dynamic>> _rows = [];
  List<Map<String, dynamic>> _buildings = [];
  List<Map<String, dynamic>> _rooms = [];
  Map<String, bool> _actions = {};
  String _query = '';
  bool? _active;
  int? _building;
  int? _room;
  bool _loading = true;
  bool _cards = false;
  bool _opening = false;
  int _page = 1;
  int _total = 0;
  int _request = 0;

  int get _pageSize => companySetupController.pageSize.clamp(1, 200);
  Color get _primary => workspaceThemeController.value.primary;

  @override
  void initState() {
    super.initState();
    _load(initial: true);
  }

  @override
  void dispose() {
    _search.dispose();
    if (widget.api == null) _api.dispose();
    super.dispose();
  }

  String _error(Object error) => error is ApiException
      ? '${error.message}\nรายละเอียดเพิ่มเติม: ${error.description ?? 'กรุณาตรวจสอบข้อมูลแล้วลองใหม่'}'
      : 'ดำเนินการทะเบียนผู้พักอาศัยไม่สำเร็จ\nรายละเอียดเพิ่มเติม: กรุณาตรวจสอบการเชื่อมต่อแล้วลองใหม่';

  Future<void> _load({bool initial = false}) async {
    final request = ++_request;
    setState(() => _loading = true);
    try {
      final values = await Future.wait([
        _api.actions(),
        _api.list(
          search: _query,
          isActive: _active,
          buildingId: _building,
          roomId: _room,
          page: _page,
          pageSize: _pageSize,
        ),
        if (initial) _api.lookup() else Future.value(<String, dynamic>{}),
      ]);
      if (!mounted || request != _request) return;
      final data = values[1];
      final lookup = values[2];
      final total = (data['total'] as num).toInt();
      final lastPage = total == 0 ? 1 : (total / _pageSize).ceil();
      if (_page > lastPage) {
        _page = lastPage;
        await _load();
        return;
      }
      setState(() {
        _actions = values[0] as Map<String, bool>;
        _rows = List<Map<String, dynamic>>.from(data['items'] as List);
        _total = total;
        if (initial) {
          _buildings = List<Map<String, dynamic>>.from(
            lookup['buildings'] as List? ?? [],
          );
          _rooms = List<Map<String, dynamic>>.from(
            lookup['rooms'] as List? ?? [],
          );
        }
        _loading = false;
      });
    } catch (error) {
      if (!mounted || request != _request) return;
      setState(() {
        _loading = false;
        _rows = [];
      });
      showTimedSnackBar(context, message: _error(error), error: true);
    }
  }

  List<Map<String, dynamic>> get _filterRooms => _rooms
      .where(
        (row) =>
            _building == null ||
            (row['buildingId'] as num).toInt() == _building,
      )
      .toList();

  Future<void> _open([Map<String, dynamic>? row]) async {
    if (_opening ||
        (row == null ? _actions['create'] : _actions['edit']) != true) {
      return;
    }
    setState(() => _opening = true);
    try {
      final lookup = await _api.lookup(
        includePersonId: (row?['personID'] as num?)?.toInt(),
        includeRoomId: (row?['roomID'] as num?)?.toInt(),
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => ResidentRegistryForm(
          api: _api,
          caption: widget.caption,
          initial: row,
          lookup: lookup,
          onSaved: () {
            showTimedSnackBar(
              context,
              message: 'บันทึกทะเบียนผู้พักอาศัยสำเร็จ',
            );
            _load();
          },
        ),
      );
    } catch (error) {
      if (mounted) {
        showTimedSnackBar(context, message: _error(error), error: true);
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    final confirmed = await confirmRegistryDelete(
      context,
      value: '${row['fullName']} | ${row['roomCode']}',
    );
    if (!confirmed) return;
    try {
      await _api.delete(
        (row['residentID'] as num).toInt(),
        '${row['rowVersion']}',
      );
      if (!mounted) return;
      showTimedSnackBar(context, message: 'ลบผู้พักอาศัยแล้ว');
      await _load();
    } catch (error) {
      if (mounted) {
        showTimedSnackBar(context, message: _error(error), error: true);
      }
    }
  }

  Widget _actionsFor(Map<String, dynamic> row) => Row(
    mainAxisSize: MainAxisSize.min,
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      if (_actions['edit'] == true)
        IconButton(
          tooltip: 'แก้ไข',
          color: _primary,
          onPressed: () => _open(row),
          icon: const Icon(Icons.edit_outlined),
        ),
      if (_actions['delete'] == true)
        IconButton(
          tooltip: 'ลบ',
          color: LaooColors.error,
          onPressed: () => _delete(row),
          icon: const Icon(Icons.delete_outline),
        ),
    ],
  );

  String _date(Object? value) {
    if (value == null) return '-';
    final parsed = DateTime.tryParse('$value');
    if (parsed == null) return '-';
    final setup = companySetupController.current;
    return setup == null
        ? CompanyDateFormatter.formatDateByYearFormat(parsed, 'AD')
        : CompanyDateFormatter.formatDate(parsed, setup);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 900;
      return ColoredBox(
        color: LaooColors.background,
        child: Padding(
          padding: const EdgeInsets.all(LaooLayout.cardMargin),
          child: Column(
            children: [
              registrySurface(
                Row(
                  children: [
                    Expanded(
                      child: WorkspacePageTitle(
                        title: widget.caption,
                        favoriteKey: '14004',
                      ),
                    ),
                    if (!compact)
                      IconButton(
                        tooltip: 'สลับ Card/List',
                        color: _primary,
                        onPressed: () => setState(() => _cards = !_cards),
                        icon: Icon(_cards ? Icons.view_list : Icons.grid_view),
                      ),
                    if (_actions['create'] == true)
                      FilledButton.icon(
                        style: registryButton(_primary, filled: true),
                        onPressed: _opening ? null : () => _open(),
                        icon: const Icon(Icons.add),
                        label: const Text('เพิ่ม'),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              registrySurface(_filters(compact, constraints.maxWidth)),
              const SizedBox(height: LaooLayout.cardSpacing),
              Expanded(child: _content(compact || _cards)),
              const SizedBox(height: LaooLayout.cardSpacing),
              RegistryPagination(
                page: _page,
                pageSize: _pageSize,
                total: _total,
                primary: _primary,
                onPage: (value) {
                  _page = value;
                  _load();
                },
              ),
            ],
          ),
        ),
      );
    },
  );

  Widget _filters(bool compact, double width) => Wrap(
    spacing: 8,
    runSpacing: 8,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      SizedBox(
        width: compact ? width - 40 : 300,
        child: TextField(
          key: const ValueKey('resident-search'),
          controller: _search,
          decoration: registryInput(
            context,
            hint: 'ค้นหาชื่อ โทรศัพท์ หรือห้อง',
            icon: Icons.search,
          ),
          onSubmitted: (_) {
            _query = _search.text.trim();
            _page = 1;
            _load();
          },
        ),
      ),
      SizedBox(
        width: compact ? width - 40 : 190,
        child: DropdownButtonFormField<int?>(
          initialValue: _building,
          isExpanded: true,
          decoration: registryInput(context, label: 'อาคาร'),
          items: [
            const DropdownMenuItem(value: null, child: Text('ทั้งหมด')),
            for (final row in _buildings)
              DropdownMenuItem(
                value: (row['id'] as num).toInt(),
                child: Text(
                  '${row['code']} | ${row['name']}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (value) => setState(() {
            _building = value;
            _room = null;
          }),
        ),
      ),
      SizedBox(
        width: compact ? width - 40 : 190,
        child: DropdownButtonFormField<int?>(
          key: ValueKey((_building, _room)),
          initialValue: _room,
          isExpanded: true,
          decoration: registryInput(context, label: 'ห้อง'),
          items: [
            const DropdownMenuItem(value: null, child: Text('ทั้งหมด')),
            for (final row in _filterRooms)
              DropdownMenuItem(
                value: (row['id'] as num).toInt(),
                child: Text(
                  '${row['code']} | ${row['name']}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: (value) => setState(() => _room = value),
        ),
      ),
      SizedBox(
        width: compact ? width - 40 : 170,
        child: DropdownButtonFormField<bool?>(
          initialValue: _active,
          decoration: registryInput(context, label: 'สถานะ'),
          items: const [
            DropdownMenuItem(value: null, child: Text('ทั้งหมด')),
            DropdownMenuItem(value: true, child: Text('ใช้งาน')),
            DropdownMenuItem(value: false, child: Text('ไม่ใช้งาน')),
          ],
          onChanged: (value) => setState(() => _active = value),
        ),
      ),
      FilledButton(
        style: registryButton(_primary, filled: true),
        onPressed: _loading
            ? null
            : () {
                _query = _search.text.trim();
                _page = 1;
                _load();
              },
        child: const Text('ค้นหา'),
      ),
      OutlinedButton(
        style: registryButton(_primary),
        onPressed: _loading
            ? null
            : () {
                _search.clear();
                _query = '';
                _active = null;
                _building = null;
                _room = null;
                _page = 1;
                _load();
              },
        child: const Text('ล้าง Filter'),
      ),
    ],
  );

  Widget _content(bool cards) {
    if (_loading) {
      return registrySurface(const Center(child: CircularProgressIndicator()));
    }
    if (_actions['view'] != true) {
      return registrySurface(
        const Center(child: Text('ไม่มีสิทธิ์แสดงทะเบียนผู้พักอาศัย')),
      );
    }
    if (_rows.isEmpty) {
      return registrySurface(
        const Center(child: Text('ไม่พบข้อมูลผู้พักอาศัย')),
      );
    }
    if (cards) {
      return ListView.separated(
        itemCount: _rows.length,
        separatorBuilder: (_, _) => const SizedBox(height: 6),
        itemBuilder: (_, index) {
          final row = _rows[index];
          return registrySurface(
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
                      Text(
                        '${row['buildingCode']} / ${row['floorCode']} / ${row['roomCode']}',
                      ),
                      Text(
                        '${_date(row['startDate'])} - ${_date(row['endDate'])} • ${row['isActive'] == true ? 'ใช้งาน' : 'ไม่ใช้งาน'}',
                      ),
                    ],
                  ),
                ),
                _actionsFor(row),
              ],
            ),
          );
        },
      );
    }
    return registrySurface(
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
        columns: const [
          LaooTableColumns.id,
          DataColumn(
            label: Center(child: Text('Action')),
            columnWidth: FixedColumnWidth(112),
            headingRowAlignment: MainAxisAlignment.center,
          ),
          DataColumn(
            label: Text('ผู้พักอาศัย'),
            columnWidth: FlexColumnWidth(),
          ),
          DataColumn(label: Text('โทรศัพท์')),
          DataColumn(label: Text('อาคาร')),
          DataColumn(label: Text('ชั้น')),
          DataColumn(label: Text('ห้อง')),
          DataColumn(label: Text('วันที่เข้า')),
          DataColumn(label: Text('วันที่ออก')),
          DataColumn(label: Text('สถานะ')),
        ],
        rows: [
          for (var index = 0; index < _rows.length; index++)
            DataRow(
              cells: [
                DataCell(Text('${(_page - 1) * _pageSize + index + 1}')),
                DataCell(Center(child: _actionsFor(_rows[index]))),
                DataCell(Text('${_rows[index]['fullName']}')),
                DataCell(Text('${_rows[index]['mobile'] ?? '-'}')),
                DataCell(Text('${_rows[index]['buildingCode']}')),
                DataCell(Text('${_rows[index]['floorCode']}')),
                DataCell(Text('${_rows[index]['roomCode']}')),
                DataCell(Text(_date(_rows[index]['startDate']))),
                DataCell(Text(_date(_rows[index]['endDate']))),
                DataCell(
                  Text(
                    _rows[index]['isActive'] == true ? 'ใช้งาน' : 'ไม่ใช้งาน',
                  ),
                ),
              ],
            ),
        ],
      ),
      padding: EdgeInsets.zero,
    );
  }
}

class ResidentRegistryForm extends StatefulWidget {
  const ResidentRegistryForm({
    super.key,
    required this.api,
    required this.caption,
    required this.lookup,
    required this.onSaved,
    this.initial,
  });

  final ResidentRegistryApi api;
  final String caption;
  final Map<String, dynamic> lookup;
  final Map<String, dynamic>? initial;
  final VoidCallback onSaved;

  @override
  State<ResidentRegistryForm> createState() => _ResidentRegistryFormState();
}

class _ResidentRegistryFormState extends State<ResidentRegistryForm> {
  final _form = GlobalKey<FormState>();
  late final List<Map<String, dynamic>> _persons =
      List<Map<String, dynamic>>.from(widget.lookup['persons'] as List? ?? []);
  late final List<Map<String, dynamic>> _buildings =
      List<Map<String, dynamic>>.from(
        widget.lookup['buildings'] as List? ?? [],
      );
  late final List<Map<String, dynamic>> _floors =
      List<Map<String, dynamic>>.from(widget.lookup['floors'] as List? ?? []);
  late final List<Map<String, dynamic>> _rooms =
      List<Map<String, dynamic>>.from(widget.lookup['rooms'] as List? ?? []);
  late int? _person = (widget.initial?['personID'] as num?)?.toInt();
  late int? _building = (widget.initial?['buildingID'] as num?)?.toInt();
  late int? _floor = (widget.initial?['floorID'] as num?)?.toInt();
  late int? _room = (widget.initial?['roomID'] as num?)?.toInt();
  late DateTime _start =
      DateTime.tryParse('${widget.initial?['startDate'] ?? ''}') ??
      DateTime.now();
  late DateTime? _end = widget.initial?['endDate'] == null
      ? null
      : DateTime.tryParse('${widget.initial?['endDate']}');
  late bool _active = widget.initial?['isActive'] as bool? ?? true;
  bool _saving = false;

  bool get _adding => widget.initial == null;
  List<Map<String, dynamic>> get _availableFloors => _floors
      .where((row) => (row['parentId'] as num).toInt() == _building)
      .toList();
  List<Map<String, dynamic>> get _availableRooms => _rooms
      .where(
        (row) =>
            (row['buildingId'] as num).toInt() == _building &&
            (row['parentId'] as num).toInt() == _floor,
      )
      .toList();

  String _date(DateTime? value) => value == null
      ? 'ไม่ระบุ'
      : CompanyDateFormatter.formatDateByYearFormat(
          value,
          companySetupController.current?.yearFormat ?? 'AD',
        );

  String _iso(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  Future<void> _pick(bool start) async {
    final value = await showDatePicker(
      context: context,
      initialDate: start ? _start : (_end ?? _start),
      firstDate: DateTime(1900),
      lastDate: DateTime(2200),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          dialogTheme: DialogThemeData(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(LaooRadius.xs),
            ),
          ),
          datePickerTheme: DatePickerThemeData(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(LaooRadius.xs),
            ),
          ),
        ),
        child: child!,
      ),
    );
    if (value == null) return;
    setState(() {
      if (start) {
        _start = value;
        if (_end?.isBefore(value) == true) _end = null;
      } else {
        _end = value;
      }
    });
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate() || _saving) return;
    setState(() => _saving = true);
    try {
      await widget.api.save({
        'personId': _person,
        'roomId': _room,
        'startDate': _iso(_start),
        'endDate': _end == null ? null : _iso(_end!),
        'isActive': _active,
        'rowVersion': widget.initial?['rowVersion'],
      }, id: (widget.initial?['residentID'] as num?)?.toInt());
      widget.onSaved();
      if (!mounted) return;
      if (_adding) {
        setState(() {
          _person = null;
          _building = null;
          _floor = null;
          _room = null;
          _start = DateTime.now();
          _end = null;
          _active = true;
        });
        _form.currentState!.reset();
      } else {
        Navigator.pop(context);
      }
    } catch (error) {
      if (mounted) {
        showTimedSnackBar(
          context,
          message: error is ApiException
              ? '${error.message}\nรายละเอียดเพิ่มเติม: ${error.description ?? 'กรุณาตรวจสอบข้อมูล'}'
              : 'บันทึกผู้พักอาศัยไม่สำเร็จ\nรายละเอียดเพิ่มเติม: กรุณาลองใหม่',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _combo(
    String label,
    int? value,
    List<Map<String, dynamic>> rows,
    ValueChanged<int?> onChanged, {
    bool nameOnly = false,
  }) => DropdownButtonFormField<int>(
    key: ValueKey((label, value, rows.length)),
    initialValue: value,
    isExpanded: true,
    decoration: registryInput(context, label: '$label *'),
    items: rows
        .map(
          (row) => DropdownMenuItem(
            value: (row['id'] as num).toInt(),
            child: Text(
              nameOnly ? '${row['name']}' : '${row['code']} | ${row['name']}',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        )
        .toList(),
    onChanged: _saving ? null : onChanged,
    validator: (selected) => selected == null ? 'กรุณาเลือก$label' : null,
  );

  Widget _dateField(String label, DateTime? value, VoidCallback onTap) =>
      InkWell(
        onTap: _saving ? null : onTap,
        child: InputDecorator(
          decoration: registryInput(context, label: label),
          child: Row(
            children: [
              Expanded(child: Text(_date(value))),
              const Icon(Icons.calendar_today_outlined, size: 18),
              if (value != null && label == 'วันที่ออก')
                IconButton(
                  tooltip: 'ล้างวันที่ออก',
                  onPressed: () => setState(() => _end = null),
                  icon: const Icon(Icons.close, size: 18),
                ),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
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
          Icon(Icons.badge_outlined, color: primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${widget.caption} > ${_adding ? 'เพิ่ม' : 'แก้ไข'}',
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
        width: 700,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                          : (value) => setState(() => _active = value),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _combo(
                  'บุคคล',
                  _person,
                  _persons,
                  (value) => setState(() => _person = value),
                  nameOnly: true,
                ),
                const SizedBox(height: 12),
                _locationFields(),
                const SizedBox(height: 12),
                _dateFields(),
                const SizedBox(height: 12),
                const Divider(height: 1, color: LaooColors.border),
              ],
            ),
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      actions: [
        OutlinedButton(
          style: registryButton(primary),
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('ยกเลิก'),
        ),
        FilledButton(
          style: registryButton(primary, filled: true),
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'กำลังบันทึก…' : 'บันทึก'),
        ),
      ],
    );
  }

  Widget _locationFields() => LayoutBuilder(
    builder: (_, constraints) {
      final fields = [
        _combo('อาคาร', _building, _buildings, (value) {
          setState(() {
            _building = value;
            _floor = null;
            _room = null;
          });
        }),
        _combo('ชั้น', _floor, _availableFloors, (value) {
          setState(() {
            _floor = value;
            _room = null;
          });
        }),
        _combo(
          'ห้อง',
          _room,
          _availableRooms,
          (value) => setState(() => _room = value),
        ),
      ];
      if (constraints.maxWidth < 620) {
        return Column(
          children: [
            for (var index = 0; index < fields.length; index++) ...[
              fields[index],
              if (index < fields.length - 1) const SizedBox(height: 12),
            ],
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var index = 0; index < fields.length; index++) ...[
            Expanded(child: fields[index]),
            if (index < fields.length - 1) const SizedBox(width: 12),
          ],
        ],
      );
    },
  );

  Widget _dateFields() => LayoutBuilder(
    builder: (_, constraints) {
      final fields = [
        _dateField('วันที่เข้า *', _start, () => _pick(true)),
        _dateField('วันที่ออก', _end, () => _pick(false)),
      ];
      if (constraints.maxWidth < 520) {
        return Column(
          children: [fields[0], const SizedBox(height: 12), fields[1]],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: fields[0]),
          const SizedBox(width: 12),
          Expanded(child: fields[1]),
        ],
      );
    },
  );
}
