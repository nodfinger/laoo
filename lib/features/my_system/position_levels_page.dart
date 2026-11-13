import 'package:flutter/material.dart';
import 'package:laoo_shared_admin_ui/laoo_shared_admin_ui.dart'
    show FilterHeightSync, filterActionHeightStyle;
import '../../app/theme/laoo_design_tokens.dart';
import '../../core/api/api_client.dart';
import '../../core/navigation/navigation_menu_repository.dart';
import '../../core/widgets/timed_snack_bar.dart';
import '../company/ocr/business_card_ocr_ui.dart';
import '../support/presentation/widgets/support_workspace_shell.dart';

class PositionLevelsPage extends StatefulWidget {
  const PositionLevelsPage({super.key});
  @override
  State<PositionLevelsPage> createState() => _PositionLevelsPageState();
}

class _PositionLevelsPageState extends State<PositionLevelsPage> {
  final _api = ApiClient();
  final _search = TextEditingController();
  String _query = '';
  final _positions = <String, String>{};
  final _positionLevels = <String, String?>{};
  final _levels = <String, String>{};
  final _vacant = <String, bool>{};
  final _substitutes = <String, int?>{};
  final _employees = <Map<String, dynamic>>[];
  bool _positionsLoading = true,
      _positionsSaving = false,
      _canEditPositions = false;
  String? _positionsError;
  String _title = '';
  @override
  void initState() {
    super.initState();
    _loadPositions();
    _loadTitle();
  }

  Future<void> _loadTitle() async {
    final menu = await NavigationMenuRepository().findMenu(menuCode: '10009');
    if (mounted) setState(() => _title = menu?.name ?? 'กำหนดระดับตำแหน่งงาน');
  }

  @override
  void dispose() {
    _search.dispose();
    _api.dispose();
    super.dispose();
  }

  Future<void> _loadPositions() async {
    try {
      final data = await _api.get(
        '/api/company/travel-settings/position-levels',
      );
      if (data is! Map ||
          data['positions'] is! List ||
          data['levels'] is! List) {
        throw StateError('Invalid response');
      }
      if (!mounted) return;
      setState(() {
        _positions.clear();
        _positionLevels.clear();
        _levels.clear();
        _vacant.clear();
        _substitutes.clear();
        _employees.clear();
        for (final item in (data['positions'] as List).whereType<Map>()) {
          final code = item['code'].toString();
          _positions[code] = item['name'].toString();
          _positionLevels[code] = item['level']?.toString();
          _vacant[code] = item['vacant'] == true;
          _substitutes[code] = (item['substituteId'] as num?)?.toInt();
        }
        for (final item in (data['levels'] as List).whereType<Map>()) {
          _levels[item['code'].toString()] = item['name'].toString();
        }
        if (data['employees'] is List) {
          _employees.addAll(
            (data['employees'] as List).whereType<Map>().map(
              (e) => Map<String, dynamic>.from(e),
            ),
          );
        }
        _canEditPositions = data['canEdit'] == true;
        _positionsLoading = false;
        _positionsError = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _positionsLoading = false;
          _positionsError =
              'โหลดระดับตำแหน่งงานไม่ได้ กรุณาตรวจสอบสิทธิ์และลองใหม่';
        });
      }
    }
  }

  Future<void> _savePositions() async {
    setState(() => _positionsSaving = true);
    try {
      await _api.put(
        '/api/company/travel-settings/position-levels',
        body: {
          'items': _positions.keys
              .map(
                (code) => {
                  'code': code,
                  'level': _positionLevels[code],
                  'vacant': _vacant[code] ?? false,
                  'substituteId': _substitutes[code],
                },
              )
              .toList(),
        },
      );
      if (mounted) {
        showTimedSnackBar(
          context,
          message: 'บันทึกระดับตำแหน่งงานเรียบร้อยแล้ว',
        );
      }
    } catch (_) {
      if (mounted) {
        showTimedSnackBar(
          context,
          message:
              'บันทึกระดับตำแหน่งงานไม่สำเร็จ กรุณาตรวจสอบข้อมูลและลองใหม่',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _positionsSaving = false);
    }
  }

  Future<void> _chooseEmployee(String positionCode) async {
    final search = TextEditingController();
    String query = '';
    final departments =
        _employees
            .where((e) => e['active'] != false)
            .map((e) => '${e['department'] ?? ''}'.trim())
            .where((name) => name.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    String department = departments.isEmpty ? '' : departments.first;
    final selected = await showDialog<int>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) {
          final t = businessCardOcrUi(context);
          final rows = _employees.where((e) {
            final text = '${e['name']} ${e['nickname'] ?? ''}'.toLowerCase();
            return e['active'] != false &&
                text.contains(query.toLowerCase()) &&
                (department.isEmpty ||
                    '${e['department'] ?? ''}'.trim() == department);
          }).toList();
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            title: Row(
              children: [
                Icon(Icons.person_search_outlined, color: t.primaryColor),
                const SizedBox(width: 12),
                const Expanded(child: Text('เลือกพนักงานทำงานแทน')),
              ],
            ),
            content: SizedBox(
              width: 600,
              height: MediaQuery.sizeOf(context).height * .58,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Divider(thickness: .6),
                  TextField(
                    controller: search,
                    style: t.inputStyle,
                    decoration: ocrInput(
                      context,
                      'ค้นหาชื่อพนักงาน',
                      icon: Icons.search,
                    ),
                    onChanged: (v) => update(() => query = v.trim()),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: department,
                    isExpanded: true,
                    decoration: ocrInput(context, 'แผนก'),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('ทั้งหมด')),
                      for (final d in departments)
                        DropdownMenuItem(value: d, child: Text(d)),
                    ],
                    onChanged: (v) => update(() => department = v ?? ''),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: rows.isEmpty
                        ? const Center(child: Text('ไม่พบพนักงาน'))
                        : ListView.separated(
                            itemCount: rows.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1, thickness: .6),
                            itemBuilder: (context, i) {
                              final e = rows[i];
                              return ListTile(
                                title: Text('${e['name']}'),
                                subtitle: Text('${e['department'] ?? ''}'),
                                onTap: () => Navigator.pop(
                                  dialogContext,
                                  (e['id'] as num).toInt(),
                                ),
                              );
                            },
                          ),
                  ),
                  const Divider(thickness: .6),
                ],
              ),
            ),
            actions: [
              OutlinedButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('ปิด'),
              ),
            ],
          );
        },
      ),
    );
    search.dispose();
    if (selected != null && mounted) {
      setState(() => _substitutes[positionCode] = selected);
    }
  }

  Widget _buildPositionTab(BuildContext context) {
    if (_positionsLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_positionsError != null) return Center(child: Text(_positionsError!));
    final t = businessCardOcrUi(context);
    final positions = _positions.entries
        .where((e) => e.value.toLowerCase().contains(_query.toLowerCase()))
        .toList();
    if (positions.isEmpty) return const Center(child: Text('ไม่พบตำแหน่งงาน'));
    final canEdit = _canEditPositions && !_positionsSaving;
    Widget header(String text) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: Text(
        text,
        style: t.tableStyle.copyWith(
          color: t.primaryColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.all(LaooLayout.cardPadding),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 700;
          if (narrow) {
            return ListView.separated(
              itemCount: positions.length,
              separatorBuilder: (_, _) => const Divider(thickness: .6),
              itemBuilder: (context, i) {
                final p = positions[i];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(p.value, style: t.tableStyle),
                    _positionLevelControl(p.key, canEdit),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('สถานะว่าง'),
                      value: _vacant[p.key] ?? false,
                      onChanged: canEdit
                          ? (v) => setState(() => _vacant[p.key] = v)
                          : null,
                    ),
                    _substituteControl(p.key, canEdit),
                  ],
                );
              },
            );
          }
          return SingleChildScrollView(
            child: Table(
              columnWidths: const {
                0: FlexColumnWidth(2),
                1: FlexColumnWidth(1.2),
                2: FlexColumnWidth(3),
                3: FlexColumnWidth(3),
              },
              border: TableBorder(
                horizontalInside: BorderSide(
                  color: Theme.of(context).dividerColor,
                  width: .6,
                ),
              ),
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                TableRow(
                  decoration: BoxDecoration(
                    color: t.primaryColor.withValues(alpha: .12),
                  ),
                  children: [
                    header('ระดับตำแหน่ง'),
                    header('สถานะว่าง'),
                    header('ชื่อตำแหน่ง'),
                    header('กรณีว่าง'),
                  ],
                ),
                for (final p in positions)
                  TableRow(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: _positionLevelControl(p.key, canEdit),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Switch(
                          value: _vacant[p.key] ?? false,
                          activeThumbColor: t.primaryColor,
                          onChanged: canEdit
                              ? (v) => setState(() => _vacant[p.key] = v)
                              : null,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(p.value, style: t.tableStyle),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: _substituteControl(p.key, canEdit),
                      ),
                    ],
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _positionLevelControl(String code, bool canEdit) =>
      DropdownButtonFormField<String>(
        initialValue: _levels.containsKey(_positionLevels[code])
            ? _positionLevels[code]
            : null,
        isExpanded: true,
        decoration: ocrInput(context, 'ระดับตำแหน่งงาน'),
        items: [
          const DropdownMenuItem(value: '', child: Text('ไม่กำหนด')),
          for (final level in _levels.entries)
            DropdownMenuItem(value: level.key, child: Text(level.value)),
        ],
        onChanged: canEdit
            ? (value) => setState(
                () => _positionLevels[code] = value == null || value.isEmpty
                    ? null
                    : value,
              )
            : null,
      );

  Widget _substituteControl(String code, bool canEdit) {
    final id = _substitutes[code];
    final found = _employees.where((e) => e['id'] == id).firstOrNull;
    final name = id == null
        ? 'เลือกพนักงาน'
        : found == null
        ? 'พนักงานไม่พร้อมใช้งาน'
        : '${found['name']}${found['active'] == false ? ' (ไม่ใช้งาน)' : ''}';
    return Row(
      children: [
        if (canEdit)
          IconButton(
            tooltip: 'ค้นหาพนักงาน',
            onPressed: () => _chooseEmployee(code),
            icon: Icon(
              Icons.search,
              color: businessCardOcrUi(context).primaryColor,
            ),
          ),
        Expanded(child: Text(name, overflow: TextOverflow.ellipsis)),
        if (canEdit) ...[
          if (id != null)
            IconButton(
              tooltip: 'ล้างพนักงานที่เลือก',
              onPressed: () => setState(() => _substitutes[code] = null),
              icon: const Icon(Icons.close),
            ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) => SupportWorkspaceShell(
    pageTitle: _title,
    activeMenu: '10009',
    menuScope: WorkspaceMenuScope.company,
    child: Padding(
      padding: const EdgeInsets.all(LaooLayout.cardMargin),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WorkspaceSectionCard(
            child: Row(
              children: [
                Expanded(
                  child: WorkspacePageTitle(
                    title: _title,
                    favoriteKey: '10009',
                  ),
                ),
                if (_canEditPositions && _positions.isNotEmpty)
                  FilledButton.icon(
                    onPressed: _positionsSaving ? null : _savePositions,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('บันทึก'),
                  ),
              ],
            ),
          ),
          const SizedBox(height: LaooLayout.cardSpacing),
          WorkspaceSectionCard(
            child: FilterHeightSync(
              builder: (context, key, height) {
                final t = businessCardOcrUi(context);
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: (MediaQuery.sizeOf(context).width - 80).clamp(
                        0.0,
                        340.0,
                      ),
                      child: TextField(
                        key: key,
                        controller: _search,
                        style: t.inputStyle,
                        decoration: ocrInput(
                          context,
                          'ค้นหาตำแหน่งงาน',
                          icon: Icons.search,
                        ),
                        onSubmitted: (_) =>
                            setState(() => _query = _search.text.trim()),
                      ),
                    ),
                    FilledButton.icon(
                      style: filterActionHeightStyle(height),
                      onPressed: () =>
                          setState(() => _query = _search.text.trim()),
                      icon: const Icon(Icons.search),
                      label: const Text('ค้นหา'),
                    ),
                    OutlinedButton.icon(
                      style: filterActionHeightStyle(height),
                      onPressed: () => setState(() {
                        _search.clear();
                        _query = '';
                      }),
                      icon: const Icon(Icons.filter_alt_off_outlined),
                      label: const Text('ล้าง Filter'),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: LaooLayout.cardSpacing),
          Expanded(
            child: Card(
              margin: EdgeInsets.zero,
              child: _buildPositionTab(context),
            ),
          ),
        ],
      ),
    ),
  );
}
