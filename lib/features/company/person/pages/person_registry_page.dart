import 'package:flutter/material.dart';

import '../../../../app/theme/laoo_design_tokens.dart';
import '../../../../app/theme/laoo_typography.dart';
import '../../../../app/theme/workspace_theme_presets.dart';
import '../../../../core/api/api_exception.dart';
import '../../../../core/company_setup/company_setup_controller.dart';
import '../../../../core/navigation/navigation_menu_repository.dart';
import '../../../../core/widgets/pinned_data_table.dart';
import '../../../../core/widgets/timed_snack_bar.dart';
import '../../../support/presentation/widgets/support_workspace_shell.dart';
import '../../shared/registry_ui.dart';
import '../data/person_registry_api.dart';

class PersonRegistryPage extends StatefulWidget {
  const PersonRegistryPage({super.key});
  @override
  State<PersonRegistryPage> createState() => _PersonRegistryPageState();
}

class _PersonRegistryPageState extends State<PersonRegistryPage> {
  String _caption = '';
  @override
  void initState() {
    super.initState();
    NavigationMenuRepository()
        .resolveMenuName(menuCode: '13002', routeName: 'companyPersons')
        .then((value) {
          if (mounted) setState(() => _caption = value);
        });
  }

  @override
  Widget build(BuildContext context) => SupportWorkspaceShell(
    pageTitle: _caption,
    activeMenu: 'companyPersons',
    menuScope: WorkspaceMenuScope.company,
    child: PersonRegistryWorkspace(caption: _caption),
  );
}

class PersonRegistryWorkspace extends StatefulWidget {
  const PersonRegistryWorkspace({super.key, required this.caption, this.api});
  final String caption;
  final PersonRegistryApi? api;
  @override
  State<PersonRegistryWorkspace> createState() =>
      _PersonRegistryWorkspaceState();
}

class _PersonRegistryWorkspaceState extends State<PersonRegistryWorkspace> {
  late final PersonRegistryApi _api = widget.api ?? PersonRegistryApi();
  final _search = TextEditingController();
  List<Map<String, dynamic>> _rows = [];
  Map<String, bool> _actions = {};
  String _query = '';
  bool? _active;
  bool _loading = true, _cards = false, _opening = false;
  int _page = 1, _total = 0, _request = 0;
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

  String _error(Object error) => error is ApiException
      ? '${error.message}\nรายละเอียดเพิ่มเติม: ${error.description ?? 'กรุณาตรวจสอบข้อมูลแล้วลองใหม่'}'
      : 'ดำเนินการทะเบียนบุคคลไม่สำเร็จ\nรายละเอียดเพิ่มเติม: กรุณาตรวจสอบการเชื่อมต่อแล้วลองใหม่';

  Future<void> _load() async {
    final request = ++_request;
    setState(() => _loading = true);
    try {
      final actions = await _api.actions();
      final data = actions['view'] == true
          ? await _api.list(
              search: _query,
              isActive: _active,
              page: _page,
              pageSize: _pageSize,
            )
          : <String, dynamic>{'items': [], 'total': 0};
      if (!mounted || request != _request) return;
      final total = (data['total'] as num).toInt();
      final last = total == 0 ? 1 : (total / _pageSize).ceil();
      if (_page > last) {
        _page = last;
        await _load();
        return;
      }
      setState(() {
        _actions = actions;
        _rows = List<Map<String, dynamic>>.from(data['items'] as List);
        _total = total;
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

  Future<void> _open([Map<String, dynamic>? row]) async {
    if (_opening ||
        (row == null ? _actions['create'] : _actions['edit']) != true) {
      return;
    }
    setState(() => _opening = true);
    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => PersonRegistryForm(
          api: _api,
          caption: widget.caption,
          initial: row,
          onSaved: () {
            showTimedSnackBar(context, message: 'บันทึกทะเบียนบุคคลสำเร็จ');
            _load();
          },
        ),
      );
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    if (!await confirmRegistryDelete(context, value: '${row['fullName']}')) {
      return;
    }
    try {
      await _api.delete(
        (row['personID'] as num).toInt(),
        '${row['rowVersion']}',
      );
      if (!mounted) return;
      showTimedSnackBar(context, message: 'ลบบุคคลแล้ว');
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
              registrySurface(
                Row(
                  children: [
                    Expanded(
                      child: WorkspacePageTitle(
                        title: widget.caption,
                        favoriteKey: '13002',
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
              registrySurface(
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: compact ? box.maxWidth - 40 : 360,
                      child: TextField(
                        key: const ValueKey('person-search'),
                        controller: _search,
                        decoration: registryInput(
                          context,
                          hint: 'ค้นหาชื่อ ชื่อเล่น โทรศัพท์ หรืออีเมล',
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
                      width: compact ? box.maxWidth - 40 : 180,
                      child: DropdownButtonFormField<bool?>(
                        initialValue: _active,
                        decoration: registryInput(context, label: 'สถานะ'),
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

  Widget _content(bool cards) {
    if (_loading) {
      return registrySurface(const Center(child: CircularProgressIndicator()));
    }
    if (_actions['view'] != true) {
      return registrySurface(
        const Center(child: Text('ไม่มีสิทธิ์แสดงทะเบียนบุคคล')),
      );
    }
    if (_rows.isEmpty) {
      return registrySurface(const Center(child: Text('ไม่พบข้อมูลบุคคล')));
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
                        '${row['nickName'] ?? '-'} • ${row['mobile'] ?? '-'}',
                      ),
                      Text(row['isActive'] == true ? 'ใช้งาน' : 'ไม่ใช้งาน'),
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
          DataColumn(label: Text('ชื่อบุคคล'), columnWidth: FlexColumnWidth()),
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
                DataCell(Center(child: _actionsFor(_rows[i]))),
                DataCell(Text('${_rows[i]['fullName']}')),
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
}

class PersonRegistryForm extends StatefulWidget {
  const PersonRegistryForm({
    super.key,
    required this.api,
    required this.caption,
    required this.onSaved,
    this.initial,
  });
  final PersonRegistryApi api;
  final String caption;
  final VoidCallback onSaved;
  final Map<String, dynamic>? initial;
  @override
  State<PersonRegistryForm> createState() => _PersonRegistryFormState();
}

class _PersonRegistryFormState extends State<PersonRegistryForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(
    text: '${widget.initial?['fullName'] ?? ''}',
  );
  late final _nick = TextEditingController(
    text: '${widget.initial?['nickName'] ?? ''}',
  );
  late final _mobile = TextEditingController(
    text: '${widget.initial?['mobile'] ?? ''}',
  );
  late final _email = TextEditingController(
    text: '${widget.initial?['email'] ?? ''}',
  );
  late bool _active = widget.initial?['isActive'] as bool? ?? true;
  bool _saving = false;
  bool get _adding => widget.initial == null;
  @override
  void dispose() {
    _name.dispose();
    _nick.dispose();
    _mobile.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate() || _saving) return;
    setState(() => _saving = true);
    try {
      await widget.api.save({
        'fullName': _name.text.trim(),
        'nickName': _nick.text.trim(),
        'mobile': _mobile.text.trim(),
        'email': _email.text.trim(),
        'isActive': _active,
        'rowVersion': widget.initial?['rowVersion'],
      }, id: (widget.initial?['personID'] as num?)?.toInt());
      widget.onSaved();
      if (!mounted) return;
      if (_adding) {
        _name.clear();
        _nick.clear();
        _mobile.clear();
        _email.clear();
        setState(() => _active = true);
      } else {
        Navigator.pop(context);
      }
    } catch (error) {
      if (mounted) {
        showTimedSnackBar(
          context,
          message: error is ApiException
              ? '${error.message}\nรายละเอียดเพิ่มเติม: ${error.description ?? 'กรุณาตรวจสอบข้อมูล'}'
              : 'บันทึกบุคคลไม่สำเร็จ\nรายละเอียดเพิ่มเติม: กรุณาลองใหม่',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

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
          Icon(Icons.person_outline, color: primary),
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
        width: 560,
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
                          : (v) => setState(() => _active = v),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _name,
                  maxLength: 200,
                  decoration: registryInput(context, label: 'ชื่อ-นามสกุล *'),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'กรุณาระบุชื่อ-นามสกุล'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nick,
                  maxLength: 100,
                  decoration: registryInput(context, label: 'ชื่อเล่น'),
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (_, box) {
                    final compact = box.maxWidth < 500;
                    final phone = TextFormField(
                      controller: _mobile,
                      maxLength: 50,
                      decoration: registryInput(context, label: 'โทรศัพท์'),
                    );
                    final email = TextFormField(
                      controller: _email,
                      maxLength: 320,
                      keyboardType: TextInputType.emailAddress,
                      decoration: registryInput(context, label: 'อีเมล'),
                    );
                    return compact
                        ? Column(
                            children: [
                              phone,
                              const SizedBox(height: 12),
                              email,
                            ],
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: phone),
                              const SizedBox(width: 12),
                              Expanded(child: email),
                            ],
                          );
                  },
                ),
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
}
