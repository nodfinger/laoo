import 'package:flutter/material.dart';

import '../../../app/theme/laoo_design_tokens.dart';
import '../../../app/theme/laoo_typography.dart';
import '../../../core/api/api_client.dart';
import '../../../core/navigation/navigation_menu_repository.dart';
import '../../../core/widgets/timed_snack_bar.dart';
import '../../company/shared/registry_ui.dart';
import '../presentation/widgets/support_workspace_shell.dart';

class DocumentNumberFormatPage extends StatefulWidget {
  const DocumentNumberFormatPage({super.key});
  @override
  State<DocumentNumberFormatPage> createState() =>
      _DocumentNumberFormatPageState();
}

class _DocumentNumberFormatPageState extends State<DocumentNumberFormatPage> {
  final _api = ApiClient();
  final _search = TextEditingController();
  List<Map<String, dynamic>> _rows = [];
  String _caption = '', _query = '', _group = 'ทั้งหมด';
  bool _loading = true, _saving = false, _canEdit = false;
  String? _error;
  int _page = 1;
  int _savedRevision = 0;
  static const _size = 10;
  InputDecoration _input(
    BuildContext context, {
    String? label,
    String? hint,
    IconData? icon,
    bool enabled = true,
  }) => registryInput(context, label: label, hint: hint, icon: icon).copyWith(
    floatingLabelStyle: TextStyle(
      fontSize: LaooTypography.materialFloatingLabelSource,
      color: enabled
          ? Theme.of(context).colorScheme.primary
          : Theme.of(context).disabledColor,
    ),
  );
  void _setDatePart(
    Map<String, dynamic> row, {
    String? year,
    bool? month,
    bool? day,
  }) {
    final current = row['dateFormat'] as String;
    final y =
        year ??
        (current.startsWith('yyyy')
            ? 'yyyy'
            : current.startsWith('yy')
            ? 'yy'
            : '');
    final m = month ?? current.contains('MM');
    final d = day ?? current.contains('dd');
    final result = '$y${m ? 'MM' : ''}${d ? 'dd' : ''}';
    setState(() => row['dateFormat'] = result.isEmpty ? 'NONE' : result);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final menu = await NavigationMenuRepository().findMenu(menuCode: '05004');
      final response =
          await _api.get('/api/company/document-number-formats') as Map;
      if (!mounted) return;
      setState(() {
        _caption = menu?.name ?? '';
        _canEdit = response['canEdit'] == true;
        _rows = (response['rows'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error =
              'โหลดรูปแบบเลขที่เอกสารไม่สำเร็จ กรุณาตรวจสอบสิทธิ์และลองใหม่';
        });
      }
    }
  }

  Future<void> _save() async {
    if (_rows.any(
      (r) =>
          !RegExp(r'^[A-Za-z0-9_-]{0,12}$').hasMatch(r['prefix'] as String) ||
          !RegExp(r'^[-_/.]{0,2}$').hasMatch(r['afterPrefix'] as String) ||
          !RegExp(r'^[-_/.]{0,2}$').hasMatch(r['beforeSequence'] as String) ||
          (int.tryParse('${r['digits']}') ?? 0) < 1 ||
          (int.tryParse('${r['digits']}') ?? 0) > 9 ||
          (r['prefix'] as String).length +
                  (r['afterPrefix'] as String).length +
                  ((r['dateFormat'] == 'NONE')
                      ? 0
                      : (r['dateFormat'] as String).length) +
                  (r['beforeSequence'] as String).length +
                  (int.tryParse('${r['digits']}') ?? 0) >
              30,
    )) {
      showTimedSnackBar(
        context,
        message:
            'ตรวจสอบ Prefix สัญลักษณ์ (- _ / .) จำนวนหลัก 1–9 และความยาวรวมไม่เกิน 30 ตัวอักษร',
        error: true,
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await _api.put(
        '/api/company/document-number-formats',
        body: _rows
            .map(
              (r) => {
                'menuCode': r['menuCode'],
                'prefix': (r['prefix'] as String).toUpperCase(),
                'dateFormat': r['dateFormat'],
                'digits': int.parse('${r['digits']}'),
                'afterPrefix': r['afterPrefix'],
                'beforeSequence': r['beforeSequence'],
              },
            )
            .toList(),
      );
      if (mounted) {
        setState(() {
          for (final row in _rows) {
            row['prefix'] = (row['prefix'] as String).toUpperCase();
            row['hasConfig'] = true;
          }
          _savedRevision++;
        });
        showTimedSnackBar(context, message: 'บันทึกรูปแบบเลขที่เอกสารแล้ว');
      }
    } catch (_) {
      if (mounted) {
        showTimedSnackBar(
          context,
          message:
              'บันทึกรูปแบบเลขที่เอกสารไม่สำเร็จ กรุณาตรวจสอบสิทธิ์และลองใหม่',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _api.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final groups = <String>{
      'ทั้งหมด',
      ..._rows.map((r) => r['group'] as String),
    };
    final filtered = _rows
        .where(
          (r) =>
              (_group == 'ทั้งหมด' || r['group'] == _group) &&
              '${r['name']}'.toLowerCase().contains(_query.toLowerCase()),
        )
        .toList();
    final visible = filtered.skip((_page - 1) * _size).take(_size);
    return SupportWorkspaceShell(
      pageTitle: _caption,
      activeMenu: 'companyDocumentNumberFormat',
      menuScope: WorkspaceMenuScope.company,
      child: ColoredBox(
        color: LaooColors.background,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(child: Text(_error!))
            : ListView(
                padding: const EdgeInsets.all(LaooLayout.cardMargin),
                children: [
                  registrySurface(
                    Row(
                      children: [
                        Expanded(
                          child: WorkspacePageTitle(
                            title: _caption,
                            favoriteKey: 'companyDocumentNumberFormat',
                          ),
                        ),
                        if (_canEdit)
                          FilledButton.icon(
                            onPressed: _saving ? null : _save,
                            style: registryButton(primary, filled: true),
                            icon: const Icon(Icons.save_outlined),
                            label: const Text('บันทึก'),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  registrySurface(
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SizedBox(
                          width: 330,
                          child: TextField(
                            controller: _search,
                            decoration: _input(
                              context,
                              hint: 'ค้นหาชื่อหน้าจอ',
                              icon: Icons.search,
                            ),
                            onSubmitted: (_) => setState(() {
                              _query = _search.text;
                              _page = 1;
                            }),
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: () => setState(() {
                            _query = _search.text;
                            _page = 1;
                          }),
                          style: registryButton(primary, filled: true),
                          icon: const Icon(Icons.search),
                          label: const Text('ค้นหา'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => setState(() {
                            _search.clear();
                            _query = '';
                            _group = 'ทั้งหมด';
                            _page = 1;
                          }),
                          style: registryButton(primary),
                          icon: const Icon(Icons.filter_alt_off_outlined),
                          label: const Text('ล้าง Filter'),
                        ),
                        SizedBox(
                          width: 220,
                          child: DropdownButtonFormField<String>(
                            initialValue: _group,
                            decoration: _input(context, label: 'กลุ่มเมนู'),
                            items: groups
                                .map(
                                  (g) => DropdownMenuItem(
                                    value: g,
                                    child: Text(g),
                                  ),
                                )
                                .toList(),
                            onChanged: (g) => setState(() {
                              _group = g ?? 'ทั้งหมด';
                              _page = 1;
                            }),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (filtered.isEmpty)
                    registrySurface(
                      const Text('ไม่พบเอกสารที่รองรับการกำหนดเลข'),
                    ),
                  ...visible.map(
                    (row) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: registrySurface(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${row['group']} > ${row['name']}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                            if (row['hasConfig'] != true)
                              const Padding(
                                padding: EdgeInsets.only(bottom: 12),
                                child: Text(
                                  'ค่าเริ่มต้นใหม่นี้จะเริ่มใช้เมื่อกดบันทึก ก่อนบันทึกระบบใช้เลขเดิม',
                                ),
                              ),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final scale = constraints.maxWidth >= 1150
                                    ? ((constraints.maxWidth - 72) / 1350)
                                          .clamp(0.75, 1.0)
                                    : 1.0;
                                double fieldWidth(double width) =>
                                    (width * scale).clamp(
                                      0.0,
                                      constraints.maxWidth,
                                    );
                                return Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: [
                                    SizedBox(
                                      width: fieldWidth(220),
                                      child: TextFormField(
                                        key: ValueKey(
                                          'prefix-${row['menuCode']}-$_savedRevision',
                                        ),
                                        initialValue: row['prefix'] as String,
                                        enabled: _canEdit,
                                        maxLength: 12,
                                        style: const TextStyle(
                                          fontSize: LaooTypography.inputText,
                                        ),
                                        decoration: _input(
                                          context,
                                          label: 'Prefix',
                                          enabled: _canEdit,
                                        ).copyWith(counterText: ''),
                                        onChanged: (v) => row['prefix'] = v,
                                      ),
                                    ),
                                    SizedBox(
                                      width: fieldWidth(220),
                                      child: TextFormField(
                                        initialValue:
                                            row['afterPrefix'] as String,
                                        enabled: _canEdit,
                                        maxLength: 2,
                                        style: const TextStyle(
                                          fontSize: LaooTypography.inputText,
                                        ),
                                        decoration: _input(
                                          context,
                                          label: 'สัญลักษณ์หลัง Prefix',
                                          enabled: _canEdit,
                                        ).copyWith(counterText: ''),
                                        onChanged: (v) =>
                                            row['afterPrefix'] = v,
                                      ),
                                    ),
                                    SizedBox(
                                      width: fieldWidth(180),
                                      child: DropdownButtonFormField<String>(
                                        initialValue:
                                            (row['dateFormat'] as String)
                                                .startsWith('yyyy')
                                            ? 'yyyy'
                                            : (row['dateFormat'] as String)
                                                  .startsWith('yy')
                                            ? 'yy'
                                            : '',
                                        style: TextStyle(
                                          fontSize: LaooTypography.comboBox,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
                                        ),
                                        decoration: _input(
                                          context,
                                          label: 'ปี',
                                          enabled: _canEdit,
                                        ),
                                        items: const [
                                          DropdownMenuItem(
                                            value: '',
                                            child: Text('ไม่ใช้ปี'),
                                          ),
                                          DropdownMenuItem(
                                            value: 'yy',
                                            child: Text('2 หลัก (yy)'),
                                          ),
                                          DropdownMenuItem(
                                            value: 'yyyy',
                                            child: Text('4 หลัก (yyyy)'),
                                          ),
                                        ],
                                        onChanged: !_canEdit
                                            ? null
                                            : (v) => _setDatePart(
                                                row,
                                                year: v ?? '',
                                              ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: fieldWidth(170),
                                      child: DropdownButtonFormField<bool>(
                                        initialValue:
                                            (row['dateFormat'] as String)
                                                .contains('MM'),
                                        decoration: _input(
                                          context,
                                          label: 'เดือน',
                                          enabled: _canEdit,
                                        ),
                                        style: TextStyle(
                                          fontSize: LaooTypography.comboBox,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
                                        ),
                                        items: const [
                                          DropdownMenuItem(
                                            value: false,
                                            child: Text('ไม่ใช้เดือน'),
                                          ),
                                          DropdownMenuItem(
                                            value: true,
                                            child: Text('2 หลัก'),
                                          ),
                                        ],
                                        onChanged: !_canEdit
                                            ? null
                                            : (v) => _setDatePart(
                                                row,
                                                month: v == true,
                                              ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: fieldWidth(170),
                                      child: DropdownButtonFormField<bool>(
                                        initialValue:
                                            (row['dateFormat'] as String)
                                                .contains('dd'),
                                        decoration: _input(
                                          context,
                                          label: 'วัน',
                                          enabled: _canEdit,
                                        ),
                                        style: TextStyle(
                                          fontSize: LaooTypography.comboBox,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
                                        ),
                                        items: const [
                                          DropdownMenuItem(
                                            value: false,
                                            child: Text('ไม่ใช้วัน'),
                                          ),
                                          DropdownMenuItem(
                                            value: true,
                                            child: Text('2 หลัก'),
                                          ),
                                        ],
                                        onChanged: !_canEdit
                                            ? null
                                            : (v) => _setDatePart(
                                                row,
                                                day: v == true,
                                              ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: fieldWidth(220),
                                      child: TextFormField(
                                        initialValue:
                                            row['beforeSequence'] as String,
                                        enabled: _canEdit,
                                        maxLength: 2,
                                        style: const TextStyle(
                                          fontSize: LaooTypography.inputText,
                                        ),
                                        decoration: _input(
                                          context,
                                          label: 'สัญลักษณ์ก่อนลำดับ',
                                          enabled: _canEdit,
                                        ).copyWith(counterText: ''),
                                        onChanged: (v) =>
                                            row['beforeSequence'] = v,
                                      ),
                                    ),
                                    SizedBox(
                                      width: fieldWidth(170),
                                      child: TextFormField(
                                        initialValue: '${row['digits']}',
                                        enabled: _canEdit,
                                        keyboardType: TextInputType.number,
                                        style: const TextStyle(
                                          fontSize: LaooTypography.inputText,
                                        ),
                                        decoration: _input(
                                          context,
                                          label: 'จำนวนหลัก',
                                          enabled: _canEdit,
                                        ),
                                        onChanged: (v) => row['digits'] = v,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  RegistryPagination(
                    page: _page,
                    pageSize: _size,
                    total: filtered.length,
                    primary: primary,
                    onPage: (p) => setState(() => _page = p),
                  ),
                ],
              ),
      ),
    );
  }
}
