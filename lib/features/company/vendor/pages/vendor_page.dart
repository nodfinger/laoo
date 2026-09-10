import 'package:flutter/material.dart';
import '../../../../app/theme/laoo_design_tokens.dart';
import '../../../../app/theme/laoo_typography.dart';
import '../../../../app/theme/workspace_theme_presets.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/api/api_exception.dart';
import '../../../../core/company_setup/company_setup_controller.dart';
import '../../../../core/navigation/navigation_menu_repository.dart';
import '../../../../core/widgets/pinned_data_table.dart';
import '../../../../core/widgets/timed_snack_bar.dart';
import '../../../support/presentation/widgets/support_workspace_shell.dart';
import '../data/vendor_api.dart';

String vendorError(Object e) => e is ApiException
    ? '${e.message}\nรายละเอียดเพิ่มเติม: ${e.description ?? 'กรุณาตรวจข้อมูลแล้วลองใหม่'}'
    : 'ดำเนินการผู้ขายไม่สำเร็จ\nรายละเอียดเพิ่มเติม: กรุณาตรวจการเชื่อมต่อแล้วลองใหม่';

InputDecoration vendorInput(String label, Color primary) {
  OutlineInputBorder border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(LaooRadius.xs),
    borderSide: BorderSide(color: color),
  );
  return InputDecoration(
    labelText: label,
    isDense: true,
    filled: true,
    fillColor: Colors.white,
    border: border(LaooColors.border),
    enabledBorder: border(LaooColors.border),
    disabledBorder: border(LaooColors.border),
    focusedBorder: border(primary),
    errorBorder: border(LaooColors.error),
    focusedErrorBorder: border(LaooColors.error),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  );
}

ButtonStyle vendorButton(
  Color primary, {
  bool filled = false,
  double height = LaooTypography.buttonHeight,
}) => (filled ? FilledButton.styleFrom : OutlinedButton.styleFrom)(
  foregroundColor: filled ? Colors.white : primary,
  backgroundColor: filled ? primary : Colors.white,
  minimumSize: Size(0, height),
  textStyle: const TextStyle(
    fontSize: LaooTypography.button,
    fontWeight: FontWeight.w600,
  ),
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(LaooRadius.xs),
  ),
);

class VendorPage extends StatefulWidget {
  const VendorPage({super.key});
  @override
  State<VendorPage> createState() => _VendorPageState();
}

class _VendorPageState extends State<VendorPage> {
  final _client = ApiClient();
  String _caption = '';
  @override
  void initState() {
    super.initState();
    _captionLoad();
  }

  Future<void> _captionLoad() async {
    try {
      final title = await NavigationMenuRepository(
        apiClient: _client,
      ).resolveMenuName(menuCode: '08007');
      if (mounted) setState(() => _caption = title);
    } catch (e) {
      if (mounted) {
        showTimedSnackBar(context, message: vendorError(e), error: true);
      }
    }
  }

  @override
  void dispose() {
    _client.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SupportWorkspaceShell(
    pageTitle: _caption,
    activeMenu: 'companyVendors',
    menuScope: WorkspaceMenuScope.company,
    child: VendorWorkspace(caption: _caption),
  );
}

class VendorWorkspace extends StatefulWidget {
  const VendorWorkspace({super.key, required this.caption, this.api});
  final String caption;
  final VendorApi? api;
  @override
  State<VendorWorkspace> createState() => _VendorWorkspaceState();
}

class _VendorWorkspaceState extends State<VendorWorkspace> {
  late final VendorApi _api = widget.api ?? VendorApi();
  final _search = TextEditingController();
  List<Map<String, dynamic>> _rows = [];
  Map<String, bool> _actions = {};
  String _query = '';
  bool? _active;
  String? _type;
  bool _loading = true, _card = false, _opening = false;
  String? _error;
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

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final actions = await _api.actions();
      final data = actions['view'] == true
          ? await _api.list(
              search: _query,
              isActive: _active,
              entityTypeCode: _type,
              page: _page,
              pageSize: _pageSize,
            )
          : <String, dynamic>{'items': <Map<String, dynamic>>[], 'total': 0};
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
        if (actions['view'] != true) {
          _error =
              'ไม่มีสิทธิ์แสดงผู้ขาย\nกรุณาติดต่อผู้ดูแลเพื่อกำหนดสิทธิ์เมนู 08007';
        }
      });
    } catch (e) {
      if (mounted && request == _request) {
        setState(() {
          _loading = false;
          _rows = [];
          _error = vendorError(e);
        });
      }
    }
  }

  void _find() {
    _query = _search.text.trim();
    _page = 1;
    _load();
  }

  Future<void> _open([Map<String, dynamic>? row]) async {
    if (_opening || (row == null && _actions['create'] != true)) return;
    _opening = true;
    try {
      final detail = row == null
          ? null
          : await _api.get((row['vendorID'] as num).toInt());
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => VendorForm(
          api: _api,
          caption: widget.caption,
          initial: detail,
          canEdit: _actions['edit'] == true,
          onSaved: _load,
        ),
      );
    } catch (e) {
      if (mounted) {
        showTimedSnackBar(context, message: vendorError(e), error: true);
      }
    } finally {
      _opening = false;
    }
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    if (_actions['delete'] != true) return;
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LaooRadius.xs),
          side: const BorderSide(color: LaooColors.error),
        ),
        title: Row(
          children: [
            const Icon(Icons.delete_outline, color: LaooColors.error),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'ยืนยันการลบข้อมูล',
                style: LaooTypography.popupTitleStyle.copyWith(
                  color: LaooColors.error,
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
              padding: const EdgeInsets.all(10),
              color: LaooColors.error.withValues(alpha: .1),
              child: Text(
                '${row['vendorCode']} | ${row['vendorName']}',
                style: const TextStyle(color: LaooColors.error),
              ),
            ),
            const SizedBox(height: 12),
            const Text('ข้อมูลที่ลบแล้วไม่สามารถเรียกคืนได้'),
            const Divider(color: LaooColors.border),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton.icon(
            style: vendorButton(LaooColors.error, filled: true),
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    try {
      await _api.delete(
        (row['vendorID'] as num).toInt(),
        row['rowVersion'] as String,
      );
      if (!mounted) return;
      showTimedSnackBar(context, message: 'ลบผู้ขายแล้ว');
      await _load();
    } catch (e) {
      if (mounted) {
        showTimedSnackBar(context, message: vendorError(e), error: true);
      }
    }
  }

  Widget _actionsFor(Map<String, dynamic> row) => Row(
    mainAxisSize: MainAxisSize.min,
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      IconButton(
        tooltip: _actions['edit'] == true ? 'แก้ไข' : 'แสดง',
        onPressed: () => _open(row),
        icon: Icon(
          _actions['edit'] == true
              ? Icons.edit_outlined
              : Icons.visibility_outlined,
          color: _primary,
        ),
      ),
      if (_actions['delete'] == true)
        IconButton(
          tooltip: 'ลบ',
          onPressed: () => _delete(row),
          icon: const Icon(Icons.delete_outline, color: LaooColors.error),
        ),
    ],
  );
  Widget _box(
    Widget child, {
    EdgeInsets padding = const EdgeInsets.all(LaooLayout.cardPadding),
  }) => WorkspaceSectionCard(padding: padding, child: child);
  @override
  Widget build(
    BuildContext context,
  ) => ValueListenableBuilder<WorkspaceThemePreset>(
    valueListenable: workspaceThemeController,
    builder: (context, theme, _) => ColoredBox(
      color: LaooColors.background,
      child: Padding(
        padding: const EdgeInsets.all(LaooLayout.cardMargin),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 900;
            return Column(
              children: [
                _box(
                  Row(
                    children: [
                      Expanded(
                        child: WorkspacePageTitle(
                          title: widget.caption,
                          favoriteKey: '08007',
                        ),
                      ),
                      if (!narrow)
                        IconButton(
                          tooltip: _card ? 'แสดงรายการ' : 'แสดงการ์ด',
                          onPressed: () => setState(() => _card = !_card),
                          icon: Icon(
                            _card ? Icons.view_list : Icons.grid_view,
                            color: _primary,
                          ),
                        ),
                      if (_actions['create'] == true)
                        FilledButton.icon(
                          style: vendorButton(_primary, filled: true),
                          onPressed: _loading ? null : () => _open(),
                          icon: const Icon(Icons.add),
                          label: const Text('เพิ่ม'),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                _box(
                  LayoutBuilder(
                    builder: (context, c) {
                      final compact = c.maxWidth < 560;
                      return Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          SizedBox(
                            width: compact ? c.maxWidth : 490,
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _search,
                                    style: const TextStyle(
                                      fontSize: LaooTypography.inputText,
                                    ),
                                    decoration:
                                        vendorInput(
                                          'ค้นหารหัส ชื่อ เลขภาษี หรือโทรศัพท์',
                                          _primary,
                                        ).copyWith(
                                          prefixIcon: const Icon(Icons.search),
                                        ),
                                    onSubmitted: (_) => _find(),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (compact) ...[
                                  IconButton.filled(
                                    tooltip: 'ค้นหา',
                                    style: vendorButton(
                                      _primary,
                                      filled: true,
                                      height: 40,
                                    ),
                                    onPressed: _loading ? null : _find,
                                    icon: const Icon(Icons.search),
                                  ),
                                  IconButton.outlined(
                                    tooltip: 'ล้าง Filter',
                                    style: vendorButton(_primary, height: 40),
                                    onPressed: _loading ? null : _clear,
                                    icon: const Icon(
                                      Icons.filter_alt_off_outlined,
                                    ),
                                  ),
                                ] else ...[
                                  FilledButton(
                                    style: vendorButton(
                                      _primary,
                                      filled: true,
                                      height: 40,
                                    ),
                                    onPressed: _loading ? null : _find,
                                    child: const Text('ค้นหา'),
                                  ),
                                  const SizedBox(width: 8),
                                  OutlinedButton(
                                    style: vendorButton(_primary, height: 40),
                                    onPressed: _loading ? null : _clear,
                                    child: const Text('ล้าง Filter'),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          SizedBox(
                            width: compact ? c.maxWidth : 160,
                            child: DropdownButtonFormField<bool>(
                              initialValue: _active,
                              key: ValueKey('status-$_active'),
                              isExpanded: true,
                              style: TextStyle(
                                fontSize: LaooTypography.comboBox,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              decoration: vendorInput('สถานะ', _primary),
                              items: const [
                                DropdownMenuItem(
                                  value: null,
                                  child: Text('ทั้งหมด'),
                                ),
                                DropdownMenuItem(
                                  value: true,
                                  child: Text('ใช้งาน'),
                                ),
                                DropdownMenuItem(
                                  value: false,
                                  child: Text('ไม่ใช้งาน'),
                                ),
                              ],
                              onChanged: (v) => setState(() => _active = v),
                            ),
                          ),
                          SizedBox(
                            width: compact ? c.maxWidth : 180,
                            child: DropdownButtonFormField<String>(
                              initialValue: _type,
                              key: ValueKey('type-$_type'),
                              isExpanded: true,
                              style: TextStyle(
                                fontSize: LaooTypography.comboBox,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              decoration: vendorInput('ประเภทผู้ขาย', _primary),
                              items: const [
                                DropdownMenuItem(
                                  value: null,
                                  child: Text('ทั้งหมด'),
                                ),
                                DropdownMenuItem(
                                  value: 'PERSON',
                                  child: Text('บุคคล'),
                                ),
                                DropdownMenuItem(
                                  value: 'ORGANIZATION',
                                  child: Text('นิติบุคคล'),
                                ),
                              ],
                              onChanged: (v) => setState(() => _type = v),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: LaooLayout.cardSpacing),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _error != null
                      ? _box(
                          Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(_error!, textAlign: TextAlign.center),
                                TextButton(
                                  onPressed: _load,
                                  child: const Text('ลองใหม่'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _rows.isEmpty
                      ? _box(const Center(child: Text('ไม่พบข้อมูลผู้ขาย')))
                      : narrow || _card
                      ? ListView.separated(
                          itemCount: _rows.length,
                          separatorBuilder: (_, index) =>
                              const SizedBox(height: 6),
                          itemBuilder: (context, index) {
                            final row = _rows[index];
                            return _box(
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '${(_page - 1) * _pageSize + index + 1}. ${row['vendorCode']}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      _actionsFor(row),
                                    ],
                                  ),
                                  Text('${row['vendorName']}'),
                                  Text(
                                    '${row['entityTypeCode'] == 'PERSON' ? 'บุคคล' : 'นิติบุคคล'} • ${row['isActive'] == true ? 'ใช้งาน' : 'ไม่ใช้งาน'}',
                                  ),
                                  if (row['telephone'] != null)
                                    Text('โทรศัพท์ ${row['telephone']}'),
                                ],
                              ),
                            );
                          },
                        )
                      : _box(
                          LayoutBuilder(
                            builder: (context, c) => PinnedDataTable(
                              maxBodyHeight: (c.maxHeight - 56).clamp(
                                0,
                                double.infinity,
                              ),
                              headingRowColor: WidgetStatePropertyAll(
                                _primary.withValues(alpha: .1),
                              ),
                              headingTextStyle: TextStyle(
                                fontSize: LaooTypography.tableHeader,
                                color: _primary,
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
                                  columnWidth: FixedColumnWidth(128),
                                ),
                                DataColumn(label: Text('รหัสผู้ขาย')),
                                DataColumn(
                                  label: Text('ชื่อผู้ขาย'),
                                  columnWidth: FlexColumnWidth(),
                                ),
                                DataColumn(label: Text('ประเภท')),
                                DataColumn(label: Text('โทรศัพท์')),
                                DataColumn(label: Text('สถานะ')),
                              ],
                              rows: [
                                for (var i = 0; i < _rows.length; i++)
                                  DataRow(
                                    cells: [
                                      DataCell(
                                        Text(
                                          '${(_page - 1) * _pageSize + i + 1}',
                                        ),
                                      ),
                                      DataCell(
                                        Center(child: _actionsFor(_rows[i])),
                                      ),
                                      DataCell(
                                        Text('${_rows[i]['vendorCode']}'),
                                      ),
                                      DataCell(
                                        Text(
                                          '${_rows[i]['vendorName']}',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          _rows[i]['entityTypeCode'] == 'PERSON'
                                              ? 'บุคคล'
                                              : 'นิติบุคคล',
                                        ),
                                      ),
                                      DataCell(
                                        Text('${_rows[i]['telephone'] ?? '-'}'),
                                      ),
                                      DataCell(
                                        Text(
                                          _rows[i]['isActive'] == true
                                              ? 'ใช้งาน'
                                              : 'ไม่ใช้งาน',
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                          padding: EdgeInsets.zero,
                        ),
                ),
                const SizedBox(height: LaooLayout.cardSpacing),
                SizedBox(
                  height: LaooLayout.paginationCardHeight,
                  width: double.infinity,
                  child: _box(
                    Row(
                      children: [
                        _pageButton(
                          Icons.chevron_left,
                          _page > 1 && !_loading
                              ? () {
                                  _page--;
                                  _load();
                                }
                              : null,
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 34,
                          height: 34,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: _primary,
                            border: Border.all(color: _primary),
                            borderRadius: BorderRadius.circular(LaooRadius.xs),
                          ),
                          child: Text(
                            '$_page',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 6),
                        _pageButton(
                          Icons.chevron_right,
                          _page * _pageSize < _total && !_loading
                              ? () {
                                  _page++;
                                  _load();
                                }
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '${_total == 0 ? 0 : (_page - 1) * _pageSize + 1}-${(_page * _pageSize).clamp(0, _total)} จาก $_total',
                            style: const TextStyle(
                              fontSize: LaooTypography.bodySmall,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
  Widget _pageButton(IconData icon, VoidCallback? callback) => SizedBox(
    width: 34,
    height: 34,
    child: OutlinedButton(
      style: OutlinedButton.styleFrom(
        padding: EdgeInsets.zero,
        foregroundColor: _primary,
        side: BorderSide(color: callback == null ? LaooColors.gray : _primary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LaooRadius.xs),
        ),
      ),
      onPressed: callback,
      child: Icon(icon, size: 20),
    ),
  );
  void _clear() {
    _search.clear();
    setState(() {
      _active = null;
      _type = null;
    });
    _find();
  }
}

class VendorForm extends StatefulWidget {
  const VendorForm({
    super.key,
    required this.api,
    required this.caption,
    required this.canEdit,
    required this.onSaved,
    this.onResult,
    this.initial,
  });
  final VendorApi api;
  final String caption;
  final bool canEdit;
  final VoidCallback onSaved;
  final ValueChanged<Map<String, dynamic>>? onResult;
  final Map<String, dynamic>? initial;
  @override
  State<VendorForm> createState() => _VendorFormState();
}

class _VendorFormState extends State<VendorForm> {
  final _form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _fields = {
    for (final key in [
      'vendorCode',
      'vendorName',
      'taxID',
      'address',
      'telephone',
      'email',
      'contactName',
      'contactTelephone',
      'contactEmail',
      'creditDays',
      'remark',
    ])
      key: TextEditingController(
        text: '${widget.initial?[key] ?? (key == 'creditDays' ? '0' : '')}',
      ),
  };
  late int? _id = (widget.initial?['vendorID'] as num?)?.toInt();
  late String? _version = widget.initial?['rowVersion'] as String?;
  late String _type =
      widget.initial?['entityTypeCode'] as String? ?? 'ORGANIZATION';
  late bool _active = widget.initial?['isActive'] as bool? ?? true;
  bool _saving = false;
  bool _showValidation = false;
  bool get _editable => _id == null || widget.canEdit;
  Color get _primary => workspaceThemeController.value.primary;
  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_editable) return;
    if (!_form.currentState!.validate()) {
      setState(() => _showValidation = true);
      return;
    }
    setState(() => _saving = true);
    try {
      final data = <String, dynamic>{
        for (final e in _fields.entries)
          e.key: e.value.text.trim().isEmpty ? null : e.value.text.trim(),
        'creditDays': int.parse(_fields['creditDays']!.text.trim()),
        'isActive': _active,
        'entityTypeCode': _type,
        'rowVersion': _version,
      };
      final saved = await widget.api.save(data, id: _id);
      if (!mounted) return;
      setState(() {
        _id = (saved['vendorID'] as num).toInt();
        _version = saved['rowVersion'] as String;
      });
      widget.onSaved();
      widget.onResult?.call(saved);
      showTimedSnackBar(context, message: 'บันทึกผู้ขายสำเร็จ');
    } catch (e) {
      if (mounted) {
        showTimedSnackBar(context, message: vendorError(e), error: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(
    String key,
    String label, {
    int max = 200,
    int lines = 1,
    bool required = false,
    bool email = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: _fields[key],
      enabled: _editable && !_saving,
      style: const TextStyle(fontSize: LaooTypography.inputText),
      maxLines: lines,
      keyboardType: key == 'creditDays'
          ? TextInputType.number
          : email
          ? TextInputType.emailAddress
          : TextInputType.text,
      decoration: vendorInput('$label${required ? ' *' : ''}', _primary),
      validator: (v) {
        final text = v?.trim() ?? '';
        if (required && text.isEmpty) return 'กรุณาระบุ$label';
        if (text.length > max) return 'ไม่เกิน $max ตัวอักษร';
        if (email &&
            text.isNotEmpty &&
            !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(text)) {
          return 'รูปแบบอีเมลไม่ถูกต้อง';
        }
        if (key == 'creditDays') {
          final n = int.tryParse(text);
          if (n == null || n < 0 || n > 3650) return 'ระบุจำนวนเต็ม 0–3650 วัน';
        }
        return null;
      },
    ),
  );
  @override
  Widget build(
    BuildContext context,
  ) => ValueListenableBuilder<WorkspaceThemePreset>(
    valueListenable: workspaceThemeController,
    builder: (context, theme, _) => PopScope(
      canPop: !_saving,
      child: Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(LaooLayout.dialogInsetPadding),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LaooRadius.xs),
        ),
        child: SizedBox(
          width: 480,
          height:
              (MediaQuery.sizeOf(context).height -
                      LaooLayout.dialogInsetPadding * 2)
                  .clamp(0, 700),
          child: Padding(
            padding: const EdgeInsets.all(LaooLayout.cardPadding),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.storefront_outlined, color: _primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${widget.caption} > ${_id == null
                            ? 'เพิ่ม'
                            : _editable
                            ? 'แก้ไข'
                            : 'แสดง'}',
                        style: LaooTypography.popupTitleStyle,
                      ),
                    ),
                  ],
                ),
                const Divider(color: LaooColors.border),
                Expanded(
                  child: Form(
                    key: _form,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text('สถานะ'),
                              const SizedBox(width: 8),
                              Switch(
                                value: _active,
                                activeThumbColor: _primary,
                                onChanged: _editable && !_saving
                                    ? (v) => setState(() => _active = v)
                                    : null,
                              ),
                            ],
                          ),
                          _field(
                            'vendorCode',
                            'รหัสผู้ขาย',
                            max: 50,
                            required: true,
                          ),
                          _field('vendorName', 'ชื่อผู้ขาย', required: true),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: DropdownButtonFormField<String>(
                              initialValue: _type,
                              isExpanded: true,
                              decoration: vendorInput(
                                'ประเภทผู้ขาย *',
                                _primary,
                              ),
                              style: TextStyle(
                                fontSize: LaooTypography.comboBox,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'PERSON',
                                  child: Text('บุคคล'),
                                ),
                                DropdownMenuItem(
                                  value: 'ORGANIZATION',
                                  child: Text('นิติบุคคล'),
                                ),
                              ],
                              onChanged: _editable && !_saving
                                  ? (v) => setState(() => _type = v!)
                                  : null,
                            ),
                          ),
                          _field('taxID', 'เลขประจำตัวผู้เสียภาษี', max: 50),
                          _field('telephone', 'โทรศัพท์', max: 50),
                          _field('email', 'อีเมล', max: 320, email: true),
                          ExpansionTile(
                            key: ValueKey('address-$_showValidation'),
                            maintainState: true,
                            initiallyExpanded: _showValidation,
                            tilePadding: EdgeInsets.zero,
                            shape: const Border(),
                            collapsedShape: const Border(),
                            title: const Text('ที่อยู่และเงื่อนไขการซื้อ'),
                            children: [
                              _field('address', 'ที่อยู่', max: 1000, lines: 3),
                              _field(
                                'creditDays',
                                'เครดิต (วัน)',
                                max: 4,
                                required: true,
                              ),
                            ],
                          ),
                          ExpansionTile(
                            key: ValueKey('contact-$_showValidation'),
                            maintainState: true,
                            initiallyExpanded: _showValidation,
                            tilePadding: EdgeInsets.zero,
                            shape: const Border(),
                            collapsedShape: const Border(),
                            title: const Text('ผู้ติดต่อและหมายเหตุ'),
                            children: [
                              _field('contactName', 'ชื่อผู้ติดต่อ'),
                              _field(
                                'contactTelephone',
                                'โทรศัพท์ผู้ติดต่อ',
                                max: 50,
                              ),
                              _field(
                                'contactEmail',
                                'อีเมลผู้ติดต่อ',
                                max: 320,
                                email: true,
                              ),
                              _field('remark', 'หมายเหตุ', max: 1000, lines: 3),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const Divider(color: LaooColors.border),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      style: vendorButton(_primary),
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      child: Text(_editable ? 'ยกเลิก' : 'ปิด'),
                    ),
                    if (_editable) ...[
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        style: vendorButton(_primary, filled: true),
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: const Text('บันทึก'),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
