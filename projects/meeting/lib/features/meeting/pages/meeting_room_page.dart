import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/laoo_design_tokens.dart';
import '../../../app/theme/workspace_theme_presets.dart';
import '../../../app/theme/laoo_typography.dart';
import '../../../app/router/route_paths.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/config/api_config.dart';
import '../../../core/navigation/navigation_menu_repository.dart';
import '../../../core/widgets/auto_dismiss_message.dart';
import '../../support/branch/data/branch_repository.dart';
import '../../support/presentation/widgets/support_workspace_shell.dart';
import '../data/meeting_room_repository.dart';
import '../data/meeting_facility_repository.dart';
import '../data/meeting_structure_repository.dart';
import '../../support/employee/data/employee_repository.dart';
import '../../support/organization/data/organization_repository.dart';
import '../../profile/pages/user_profile_dialog.dart';

class MeetingRoomPage extends StatefulWidget {
  const MeetingRoomPage({super.key});
  @override
  State<MeetingRoomPage> createState() => _MeetingRoomPageState();
}

class _MeetingRoomPageState extends State<MeetingRoomPage> {
  final _repo = MeetingRoomRepository();
  final _employeeRepo = EmployeeRepository();
  final _organizationRepo = OrganizationRepository();
  final _facilityRepo = MeetingFacilityRepository();
  final _branchRepo = BranchRepository();
  final _structure = MeetingStructureRepository();
  final _search = TextEditingController();
  List<Map<String, dynamic>> _rooms = [],
      _facilities = [],
      _buildings = [],
      _branches = [];
  Map<String, bool> _actions = {};
  String _caption = '';
  String? _message;
  bool _loading = true;
  bool _showCards = false;
  int _page = 0;
  int? _sortColumn;
  bool _sortAscending = true;
  int? _filterBranchId;
  int? _filterBuildingId;
  int? _filterFloorId;
  static const _size = 20;
  @override
  void initState() {
    super.initState();
    _showCards = userDefaultViewModeNotifier.value == 'CARD';
    userDefaultViewModeNotifier.addListener(_syncDefaultViewMode);
    _load();
    _captionLoad();
  }

  @override
  void dispose() {
    userDefaultViewModeNotifier.removeListener(_syncDefaultViewMode);
    _search.dispose();
    super.dispose();
  }

  void _syncDefaultViewMode() {
    if (mounted)
      setState(() => _showCards = userDefaultViewModeNotifier.value == 'CARD');
  }

  Future<void> _captionLoad() async {
    final v = await NavigationMenuRepository().resolveMenuName(
      menuCode: '23002',
      routeName: 'meetingRooms',
      fallback: 'ห้องประชุม',
    );
    if (mounted) setState(() => _caption = v);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await Future.wait([
        _repo.get(),
        _repo.actions(),
        _structure.get(),
        _facilityRepo.get(),
        _branchRepo.get(company: true),
      ]);
      if (mounted)
        setState(() {
          _rooms = List<Map<String, dynamic>>.from(data[0] as List);
          _actions = Map<String, bool>.from(data[1] as Map);
          _buildings = List<Map<String, dynamic>>.from(data[2] as List);
          _facilities = List<Map<String, dynamic>>.from(data[3] as List);
          _branches = List<Map<String, dynamic>>.from(data[4] as List);
          _loading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          _message = _error(e, 'โหลดข้อมูลห้องประชุมไม่สำเร็จ');
          _loading = false;
        });
    }
  }

  String _error(Object e, String f) => e is ApiException
      ? (e.description == null ? e.message : '${e.message}\n${e.description}')
      : '$f\n$e';
  String _imageUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    if (uri != null && uri.hasScheme) return uri.toString();
    return Uri.parse(ApiConfig.baseUrl).resolve(value.trim()).toString();
  }

  void _showRoomImage(String value) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100, maxHeight: 800),
          child: InteractiveViewer(
            child: Image.network(
              _imageUrl(value),
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Padding(
                padding: EdgeInsets.all(24),
                child: Text('ไม่สามารถโหลดรูปได้'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _roomImages(Map<String, dynamic> item) {
    final room = item['roomImageUrl']?.toString() ?? '';
    final plan = item['locationImageUrl']?.toString() ?? '';
    Widget image(String url, String label) => url.isEmpty
        ? Container(
            width: 56,
            height: 56,
            color: Colors.grey.shade100,
            child: Icon(
              Icons.image_not_supported_outlined,
              color: Colors.grey.shade500,
            ),
          )
        : Tooltip(
            message: label,
            child: InkWell(
              onTap: () => _showRoomImage(url),
              child: Image.network(
                _imageUrl(url),
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox(
                  width: 56,
                  height: 56,
                  child: Icon(Icons.broken_image_outlined),
                ),
              ),
            ),
          );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        image(room, 'รูปห้องประชุม'),
        const SizedBox(width: 8),
        image(plan, 'รูปแผนผัง'),
      ],
    );
  }

  Widget _cardImages(Map<String, dynamic> item, WorkspaceThemePreset preset) {
    final room = item['roomImageUrl']?.toString() ?? '';
    final plan = item['locationImageUrl']?.toString() ?? '';
    Widget image(String url, String label, IconData icon) {
      final content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            style: TextStyle(
              color: preset.primary,
              fontSize: LaooTypography.inputText,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 100,
            child: url.isEmpty
                ? Container(
                    color: Colors.grey.shade100,
                    child: Icon(icon, color: preset.border, size: 32),
                  )
                : InkWell(
                    onTap: () => _showRoomImage(url),
                    child: Image.network(
                      _imageUrl(url),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.broken_image_outlined,
                        color: preset.border,
                      ),
                    ),
                  ),
          ),
        ],
      );
      return content;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 520;
        final roomWidget = compact
            ? Expanded(
                child: image(
                  room,
                  'รูปห้องประชุม',
                  Icons.meeting_room_outlined,
                ),
              )
            : SizedBox(
                width: 180,
                child: image(
                  room,
                  'รูปห้องประชุม',
                  Icons.meeting_room_outlined,
                ),
              );
        final planWidget = compact
            ? Expanded(child: image(plan, 'รูปแผนผัง', Icons.map_outlined))
            : SizedBox(
                width: 180,
                child: image(plan, 'รูปแผนผัง', Icons.map_outlined),
              );
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [roomWidget, const SizedBox(width: 12), planWidget],
        );
      },
    );
  }

  bool _matchesRoom(Map<String, dynamic> r) {
    final q = _search.text.trim().toLowerCase();
    final building = _buildings.where(
      (b) => b['buildingId'] == r['buildingId'],
    );
    final branchOk =
        _filterBranchId == null ||
        (building.isNotEmpty && building.first['branchId'] == _filterBranchId);
    final buildingOk =
        _filterBuildingId == null || r['buildingId'] == _filterBuildingId;
    final floorOk = _filterFloorId == null || r['floorId'] == _filterFloorId;
    final textOk =
        q.isEmpty ||
        '${r['code']} ${r['nameTh']} ${r['description'] ?? ''}'
            .toLowerCase()
            .contains(q);
    return branchOk && buildingOk && floorOk && textOk;
  }

  String _roomLocation(Map<String, dynamic> room) {
    final matches = _buildings
        .where((b) => b['buildingId'] == room['buildingId'])
        .toList();
    final building = matches.isEmpty ? null : matches.first;
    final branchMatches = _branches
        .where((b) => b['branchId'] == building?['branchId'])
        .toList();
    final branch = branchMatches.isEmpty ? null : branchMatches.first;
    final floors = (building?['floors'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
    final floorMatches = floors
        .where((f) => f['floorId'] == room['floorId'])
        .toList();
    final floor = floorMatches.isEmpty ? null : floorMatches.first;
    return '${branch?['branchNameTh'] ?? branch?['branchCode'] ?? '-'} | ${building?['nameTh'] ?? building?['code'] ?? '-'} | ${floor?['nameTh'] ?? floor?['code'] ?? '-'}';
  }

  Widget _roomLocationCell(
    Map<String, dynamic> room,
    WorkspaceThemePreset preset,
  ) {
    final matches = _buildings
        .where((b) => b['buildingId'] == room['buildingId'])
        .toList();
    final building = matches.isEmpty ? null : matches.first;
    final branchMatches = _branches
        .where((b) => b['branchId'] == building?['branchId'])
        .toList();
    final branch = branchMatches.isEmpty ? null : branchMatches.first;
    final floors = (building?['floors'] as List? ?? const [])
        .cast<Map<String, dynamic>>();
    final floorMatches = floors
        .where((f) => f['floorId'] == room['floorId'])
        .toList();
    final floor = floorMatches.isEmpty ? null : floorMatches.first;
    final branchText =
        '${branch?['branchNameTh'] ?? branch?['branchCode'] ?? '-'}';
    final buildingText =
        '${building?['nameTh'] ?? building?['code'] ?? '-'} | ${floor?['nameTh'] ?? floor?['code'] ?? '-'}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            branchText,
            style: TextStyle(
              color: preset.textPrimary,
              fontSize: LaooTypography.inputText,
            ),
          ),
          Text(
            buildingText,
            style: TextStyle(
              color: preset.textPrimary,
              fontSize: LaooTypography.inputText,
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> get _filtered {
    final a = _rooms.where(_matchesRoom).toList();
    if (_sortColumn != null) {
      a.sort((left, right) {
        Object? value(Map<String, dynamic> r) {
          if (_sortColumn == 0) return r['roomId'];
          if (_sortColumn == 7) return '${r['code']} ${r['nameTh']}';
          if (_sortColumn == 8) return r['capacity'] ?? -1;
          if (_sortColumn == 9) return r['isActive'] == true ? 1 : 0;
          return '';
        }

        final l = value(left), r = value(right);
        final c = l is num && r is num
            ? l.compareTo(r)
            : l.toString().toLowerCase().compareTo(r.toString().toLowerCase());
        return _sortAscending ? c : -c;
      });
    }
    final s = _page * _size;
    return s >= a.length
        ? const []
        : a.sublist(s, (s + _size).clamp(0, a.length));
  }

  int get _total => _rooms.where(_matchesRoom).length;
  void _onSort(int column, bool ascending) {
    setState(() {
      _sortColumn = column;
      _sortAscending = ascending;
      _page = 0;
    });
  }

  Widget _statusCell(Map<String, dynamic> item, WorkspaceThemePreset preset) {
    final active = item['isActive'] == true;
    final color = active ? preset.primary : Colors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        active ? 'ใช้งาน' : 'ไม่ใช้งาน',
        style: TextStyle(color: color),
      ),
    );
  }

  Widget _facilityButton(
    WorkspaceThemePreset preset, {
    Map<String, dynamic>? room,
  }) => SizedBox(
    width: 100,
    child: OutlinedButton.icon(
      onPressed: room == null
          ? () => context.push(RoutePaths.meetingFacilities)
          : () => _editRoomFacilities(room, preset),
      style: OutlinedButton.styleFrom(
        foregroundColor: preset.primary,
        side: BorderSide(color: preset.primary),
        padding: EdgeInsets.zero,
      ),
      icon: const Icon(Icons.devices_other_outlined, size: 16),
      label: const Text('อุปกรณ์'),
    ),
  );
  Future<void> _editRoomFacilities(
    Map<String, dynamic> room,
    WorkspaceThemePreset preset,
  ) async {
    final selected = <int, Map<String, dynamic>>{};
    for (final raw in (room['facilityItems'] as List?) ?? const []) {
      final m = Map<String, dynamic>.from(raw as Map);
      selected[(m['facilityId'] as num).toInt()] = m;
    }
    final picked = await _pickFacilities(
      preset,
      selected,
      roomName: room['code'].toString() + ' ' + room['nameTh'].toString(),
    );
    if (picked == null) return;
    try {
      await _repo.save({
        ...room,
        'facilityItems': picked.values.toList(),
      }, id: room['roomId']);
      if (mounted) {
        setState(() => _message = 'บันทึกอุปกรณ์สำเร็จ');
        await _load();
      }
    } catch (error) {
      if (mounted)
        setState(() => _message = _error(error, 'บันทึกอุปกรณ์ไม่สำเร็จ'));
    }
  }

  Widget _adminButton(Map<String, dynamic> room, WorkspaceThemePreset preset) =>
      SizedBox(
        width: 88,
        child: OutlinedButton.icon(
          onPressed: () => _showRoomAdmin(room, preset),
          style: OutlinedButton.styleFrom(
            foregroundColor: preset.primary,
            side: BorderSide(color: preset.primary),
            padding: EdgeInsets.zero,
          ),
          icon: const Icon(Icons.person_outline, size: 16),
          label: const Text('Admin'),
        ),
      );
  Widget _rulesButton(Map<String, dynamic> room, WorkspaceThemePreset preset) =>
      SizedBox(
        width: 72,
        child: OutlinedButton.icon(
          onPressed: () => _showRoomRulePopup(room, preset),
          style: OutlinedButton.styleFrom(
            foregroundColor: preset.primary,
            side: BorderSide(color: preset.primary),
            padding: EdgeInsets.zero,
          ),
          icon: const Icon(Icons.rule_outlined, size: 16),
          label: const Text('กฎ'),
        ),
      );
  Future<void> _showRoomAdmin(
    Map<String, dynamic> room,
    WorkspaceThemePreset preset,
  ) async {
    List<Map<String, dynamic>> employees = [];
    List<Map<String, dynamic>> departments = [];
    int? departmentId;
    final selected = <int>{};
    try {
      final employeeResult = await _employeeRepo.list(
        company: true,
        isActive: true,
        page: 1,
        pageSize: 100,
      );
      employees = List<Map<String, dynamic>>.from(
        (employeeResult['items'] as List?) ?? const [],
      );
      final organization = await _organizationRepo.load();
      departments =
          List<Map<String, dynamic>>.from(
                (organization['units'] as List?) ?? const [],
              )
              .where(
                (unit) =>
                    unit['unitType'] == 'DEP' && unit['isActive'] != false,
              )
              .toList();
      if (departments.isNotEmpty)
        departmentId = departments.first['orgUnitId'] as int;
      final current = await _repo.contacts((room['roomId'] as num).toInt());
      selected.addAll(
        current.map((item) => (item['employeeId'] as num).toInt()),
      );
    } catch (error) {
      if (mounted)
        setState(
          () => _message = _error(error, 'โหลดข้อมูลผู้ดูแลห้องไม่สำเร็จ'),
        );
    }
    final search = TextEditingController();
    String? dialogMessage;
    bool saving = false;
    await showDialog<void>(
      context: context,
      builder: (dc) => StatefulBuilder(
        builder: (context, refresh) {
          final term = search.text.trim().toLowerCase();
          final filtered = employees.where((item) {
            if (departmentId != null &&
                item['departmentOrgUnitId'] != departmentId)
              return false;
            final value = [
              item['employeeCode'],
              item['fullName'],
              item['nickName'],
            ].map((v) => v?.toString() ?? '').join(' ').toLowerCase();
            return term.isEmpty || value.contains(term);
          }).toList();
          return AlertDialog(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.admin_panel_settings_outlined,
                      color: preset.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'กำหนดผู้ดูแลห้องประชุม',
                      style: LaooTypography.popupTitleStyle,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  color: preset.primary.withValues(alpha: .12),
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    room['code'].toString() + ' ' + room['nameTh'].toString(),
                    style: TextStyle(
                      color: preset.primary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 520,
              height: 420,
              child: Column(
                children: [
                  if (dialogMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: AutoDismissMessage(
                        message: dialogMessage!,
                        onClose: () => refresh(() => dialogMessage = null),
                      ),
                    ),
                  DropdownButtonFormField<int>(
                    style: const TextStyle(fontSize: LaooTypography.comboBox),
                    initialValue: departmentId,
                    decoration: InputDecoration(
                      labelText: 'แผนก',
                      labelStyle: TextStyle(color: preset.primary),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: preset.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: preset.primary,
                          width: 1.5,
                        ),
                      ),
                    ),
                    items: departments
                        .map(
                          (unit) => DropdownMenuItem<int>(
                            value: unit['orgUnitId'] as int,
                            child: Text(unit['nameTh'].toString()),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => refresh(() => departmentId = value),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: search,
                    onChanged: (_) => refresh(() {}),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      labelText: 'ค้นหารหัส / ชื่อ / ชื่อเล่น',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) =>
                          Divider(color: preset.border, height: 1),
                      itemBuilder: (_, index) {
                        final item = filtered[index];
                        final id = (item['employeeId'] as num).toInt();
                        final nick = item['nickName']?.toString() ?? '';
                        return CheckboxListTile(
                          value: selected.contains(id),
                          activeColor: preset.primary,
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            item['employeeCode'].toString() +
                                ' | ' +
                                item['fullName'].toString() +
                                (nick.isEmpty ? '' : ' | $nick'),
                          ),
                          onChanged: (value) => refresh(() {
                            if (value == true) {
                              selected.add(id);
                            } else {
                              selected.remove(id);
                            }
                          }),
                        );
                      },
                    ),
                  ),
                  Divider(color: preset.primary, height: 1),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(dc),
                child: Text('ยกเลิก', style: TextStyle(color: preset.primary)),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: preset.primary),
                onPressed: saving
                    ? null
                    : () async {
                        refresh(() => saving = true);
                        try {
                          await _repo.saveContacts(
                            (room['roomId'] as num).toInt(),
                            selected.toList(),
                          );
                          refresh(() {
                            saving = false;
                            dialogMessage = 'บันทึกผู้ดูแลห้องสำเร็จ';
                          });
                          await _load();
                        } catch (error) {
                          refresh(() {
                            saving = false;
                            dialogMessage = _error(
                              error,
                              'บันทึกผู้ดูแลห้องไม่สำเร็จ',
                            );
                          });
                        }
                      },
                child: Text(saving ? 'กำลังบันทึก...' : 'บันทึก'),
              ),
            ],
          );
        },
      ),
    );
    search.dispose();
  }

  Future<void> _showRoomRulePopup(
    Map<String, dynamic> room,
    WorkspaceThemePreset preset,
  ) async {
    List<Map<String, dynamic>> employees = [];
    List<Map<String, dynamic>> rules = [];
    List<Map<String, dynamic>> departments = [];
    int? departmentId;
    try {
      final result = await Future.wait([
        _repo.rules((room['roomId'] as num).toInt()),
        _employeeRepo.list(
          company: true,
          isActive: true,
          page: 1,
          pageSize: 500,
        ),
        _organizationRepo.load(),
      ]);
      rules = List<Map<String, dynamic>>.from(result[0] as List);
      final employeeResult = result[1] as Map;
      employees = List<Map<String, dynamic>>.from(
        employeeResult['items'] as List? ?? const [],
      );
      final organization = result[2] as Map;
      departments =
          List<Map<String, dynamic>>.from(
                (organization['units'] as List?) ?? const [],
              )
              .where(
                (unit) =>
                    unit['unitType'] == 'DEP' && unit['isActive'] != false,
              )
              .toList();
      if (departments.isNotEmpty)
        departmentId = (departments.first['orgUnitId'] as num).toInt();
    } catch (error) {
      if (mounted)
        setState(() => _message = _error(error, 'โหลดกฎห้องประชุมไม่สำเร็จ'));
      return;
    }

    final item = rules.isEmpty ? null : rules.first;
    final advance = TextEditingController(
      text: '${item?['maxAdvanceDays'] ?? ''}',
    );
    final duration = TextEditingController(
      text: '${item?['maxDurationMinutes'] ?? ''}',
    );
    final cancel = TextEditingController(
      text: '${item?['cancelBeforeMinutes'] ?? ''}',
    );
    final remark = TextEditingController(
      text: item?['remark']?.toString() ?? '',
    );
    var mode = item?['approvalMode']?.toString() ?? 'NONE';
    if (mode == 'REQUIRED') mode = 'SELECTED';
    final modeNotifier = ValueNotifier<String>(mode);
    var requireAll = item?['requireAllApprovers'] != false;
    int? asInt(dynamic value) {
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '');
    }

    final selected = <int>{};
    for (final approver in (item?['approvers'] as List?) ?? const []) {
      final id = asInt(approver['employeeId']);
      if (id != null) selected.add(id);
    }
    String? dialogMessage;
    final inputStyle = TextStyle(
      color: preset.textPrimary,
      fontSize: LaooTypography.inputText,
    );
    InputDecoration ruleInput(String label) => InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: preset.primary,
        fontSize: LaooTypography.inputLabel,
      ),
      floatingLabelStyle: TextStyle(
        color: preset.primary,
        fontSize: LaooTypography.inputLabel,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: preset.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: preset.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: ThemeData.fallback().colorScheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(
          color: ThemeData.fallback().colorScheme.error,
          width: 2,
        ),
      ),
    );

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, refresh) {
          final errorColor = Theme.of(context).colorScheme.error;
          return AlertDialog(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.rule_outlined, color: preset.primary),
                    const SizedBox(width: 8),
                    Text(
                      'กำหนดกฎห้องประชุม',
                      style: LaooTypography.popupTitleStyle,
                    ),
                  ],
                ),
              ],
            ),
            content: SizedBox(
              width: 560,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      color: preset.primary.withValues(alpha: .10),
                      child: Text(
                        '${room['code']} | ${room['nameTh']}',
                        style: TextStyle(
                          color: preset.primary,
                          fontSize: LaooTypography.sectionTitle,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Divider(
                      color: preset.primary.withValues(alpha: .45),
                      height: 1,
                      thickness: 1,
                    ),
                    if (dialogMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          dialogMessage!,
                          style: TextStyle(color: errorColor),
                        ),
                      ),
                    const SizedBox(height: 20),
                    ValueListenableBuilder<String>(
                      valueListenable: modeNotifier,
                      builder: (context, currentMode, _) =>
                          DropdownButtonFormField<String>(
                            key: ValueKey(currentMode),
                            initialValue: currentMode,
                            style: inputStyle,
                            decoration: ruleInput('รูปแบบการอนุมัติ *'),
                            items: const [
                              DropdownMenuItem(
                                value: 'NONE',
                                child: Text('ไม่ต้องอนุมัติ'),
                              ),
                              DropdownMenuItem(
                                value: 'LINE_MANAGER',
                                child: Text('อนุมัติโดยหัวหน้าแผนกของผู้ขอจอง'),
                              ),
                              DropdownMenuItem(
                                value: 'SELECTED',
                                child: Text('กำหนดผู้อนุมัติโดย Admin'),
                              ),
                            ],
                            onChanged: (value) =>
                                modeNotifier.value = value ?? 'NONE',
                          ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: advance,
                            style: inputStyle,
                            keyboardType: TextInputType.number,
                            decoration: ruleInput('จองล่วงหน้าสูงสุด (วัน)'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: duration,
                            style: inputStyle,
                            keyboardType: TextInputType.number,
                            decoration: ruleInput('ใช้ห้องสูงสุด (นาที)'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: cancel,
                      style: inputStyle,
                      keyboardType: TextInputType.number,
                      decoration: ruleInput('ยกเลิกก่อนเวลา (นาที)'),
                    ),
                    ValueListenableBuilder<String>(
                      valueListenable: modeNotifier,
                      builder: (context, currentMode, _) {
                        if (currentMode != 'SELECTED')
                          return const SizedBox.shrink();
                        return StatefulBuilder(
                          builder: (context, refreshApprovers) => Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: 12),
                              DropdownButtonFormField<int>(
                                initialValue: departmentId,
                                style: inputStyle,
                                decoration: ruleInput('แผนก'),
                                items: departments
                                    .map(
                                      (unit) => DropdownMenuItem<int>(
                                        value: (unit['orgUnitId'] as num)
                                            .toInt(),
                                        child: Text(
                                          unit['nameTh']?.toString() ?? '-',
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) => refreshApprovers(
                                  () => departmentId = value,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'ผู้อนุมัติ *${selected.isEmpty ? '' : ' (${selected.length} คน)'}',
                                style: TextStyle(
                                  color: preset.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (selected.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    employees
                                        .where((employee) {
                                          final id = asInt(
                                            employee['employeeId'],
                                          );
                                          return id != null &&
                                              selected.contains(id);
                                        })
                                        .map((employee) {
                                          final department = departments
                                              .where(
                                                (unit) =>
                                                    asInt(unit['orgUnitId']) ==
                                                    asInt(
                                                      employee['departmentOrgUnitId'],
                                                    ),
                                              )
                                              .map(
                                                (unit) =>
                                                    unit['nameTh']
                                                        ?.toString() ??
                                                    '',
                                              )
                                              .firstWhere(
                                                (name) => name.isNotEmpty,
                                                orElse: () => '-',
                                              );
                                          return '$department | ${employee['fullName'] ?? '-'}';
                                        })
                                        .join('\n'),
                                    style: TextStyle(
                                      color: preset.textPrimary,
                                      fontSize: LaooTypography.inputText,
                                    ),
                                  ),
                                ),
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                value: requireAll,
                                activeColor: preset.primary,
                                title: const Text('ต้องอนุมัติครบทุกคน'),
                                onChanged: (value) =>
                                    refreshApprovers(() => requireAll = value),
                              ),
                              ...employees
                                  .where((employee) {
                                    if (departmentId == null) return true;
                                    return asInt(
                                          employee['departmentOrgUnitId'],
                                        ) ==
                                        departmentId;
                                  })
                                  .map((employee) {
                                    final id = asInt(employee['employeeId']);
                                    if (id == null) {
                                      return const SizedBox.shrink();
                                    }
                                    final nickname =
                                        employee['nickName']?.toString() ?? '';
                                    return CheckboxListTile(
                                      value: selected.contains(id),
                                      activeColor: preset.primary,
                                      controlAffinity:
                                          ListTileControlAffinity.leading,
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(
                                        '${employee['employeeCode']} | ${employee['fullName']}${nickname.isEmpty ? '' : ' | $nickname'}',
                                        style: inputStyle,
                                      ),
                                      onChanged: (value) =>
                                          refreshApprovers(() {
                                            if (value == true) {
                                              selected.add(id);
                                            } else {
                                              selected.remove(id);
                                            }
                                          }),
                                    );
                                  }),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: remark,
                      style: inputStyle,
                      maxLines: 2,
                      decoration: ruleInput('หมายเหตุ'),
                    ),
                    const SizedBox(height: 12),
                    Divider(color: preset.primary, height: 1, thickness: 1),
                  ],
                ),
              ),
            ),
            actions: [
              if (item != null && _actions['delete'] == true)
                IconButton(
                  tooltip: 'ลบกฎ',
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: dialogContext,
                      builder: (confirmContext) => AlertDialog(
                        title: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: preset.primary.withValues(alpha: .10),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.delete_outline,
                                color: preset.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Flexible(
                              child: Text(
                                'ยืนยันการลบข้อมูล',
                                style: LaooTypography.popupTitleStyle,
                              ),
                            ),
                          ],
                        ),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: preset.primary.withValues(alpha: .08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'ต้องการลบ ${room['code']} - ${room['nameTh']} หรือไม่?',
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'ข้อมูลที่ลบแล้วไม่สามารถเรียกคืนกลับมาได้',
                              style: TextStyle(
                                fontSize: LaooTypography.validation,
                              ),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () =>
                                Navigator.pop(confirmContext, false),
                            child: Text(
                              'ยกเลิก',
                              style: TextStyle(color: preset.primary),
                            ),
                          ),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () =>
                                Navigator.pop(confirmContext, true),
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('ลบ'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed != true) return;
                    try {
                      await _repo.deleteRule((room['roomId'] as num).toInt());
                      if (!dialogContext.mounted) return;
                      Navigator.pop(dialogContext);
                      setState(() => _message = 'ลบกฎห้องประชุมสำเร็จ');
                    } catch (error) {
                      refresh(
                        () => dialogMessage = _error(
                          error,
                          'ลบกฎห้องประชุมไม่สำเร็จ',
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                ),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: preset.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(LaooRadius.xs),
                  ),
                ),
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('ยกเลิก'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: preset.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(LaooRadius.xs),
                  ),
                ),
                onPressed: () async {
                  final selectedMode = modeNotifier.value;
                  if (selectedMode == 'SELECTED' && selected.isEmpty) {
                    refresh(
                      () =>
                          dialogMessage = 'กรุณาเลือกผู้อนุมัติอย่างน้อย 1 คน',
                    );
                    return;
                  }
                  try {
                    await _repo.saveRule((room['roomId'] as num).toInt(), {
                      'approvalMode': selectedMode,
                      'maxAdvanceDays': int.tryParse(advance.text),
                      'maxDurationMinutes': int.tryParse(duration.text),
                      'cancelBeforeMinutes': int.tryParse(cancel.text),
                      'requireAllApprovers': requireAll,
                      'remark': remark.text.trim(),
                      'employeeIds': selected.toList(),
                      'isActive': true,
                    }, ruleId: item?['ruleId'] as int?);
                    if (!dialogContext.mounted) return;
                    Navigator.pop(dialogContext);
                    setState(() => _message = 'บันทึกกฎห้องประชุมสำเร็จ');
                  } catch (error) {
                    refresh(
                      () => dialogMessage = _error(
                        error,
                        'บันทึกกฎห้องประชุมไม่สำเร็จ',
                      ),
                    );
                  }
                },
                child: const Text('บันทึก'),
              ),
            ],
          );
        },
      ),
    );
    advance.dispose();
    duration.dispose();
    cancel.dispose();
    remark.dispose();
    modeNotifier.dispose();
  }

  Widget _roomCard(Map<String, dynamic> item, WorkspaceThemePreset preset) =>
      Card(
        child: Padding(
          padding: const EdgeInsets.all(LaooLayout.cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _cardImages(item, preset),
              const SizedBox(height: LaooLayout.cardSpacing),
              Text(
                '${_roomLocation(item)} | ความจุ ${item['capacity'] ?? '-'} คน',
                style: TextStyle(
                  color: preset.primary,
                  fontSize: LaooTypography.inputText,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${item['code']} ${item['nameTh']}',
                      style: const TextStyle(
                        fontSize: LaooTypography.inputText,
                      ),
                    ),
                  ),
                  _actionsRow(item, preset),
                ],
              ),
              const SizedBox(height: 4),
              const Divider(color: LaooColors.border, height: 14),
              Row(
                children: [
                  _statusCell(item, preset),
                  const Spacer(),
                  _adminButton(item, preset),
                  const SizedBox(width: 8),
                  _rulesButton(item, preset),
                  const SizedBox(width: 8),
                  _facilityButton(preset, room: item),
                ],
              ),
            ],
          ),
        ),
      );
  Widget _roomContent(WorkspaceThemePreset p) => LayoutBuilder(
    builder: (context, c) {
      final cards = _showCards || c.maxWidth < 900;
      return Column(
        children: [
          Expanded(
            child: cards
                ? ListView.separated(
                    itemCount: _filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) => _roomCard(_filtered[i], p),
                  )
                : Card(
                    margin: EdgeInsets.zero,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minWidth: c.maxWidth),
                        child: DataTable(
                          border: TableBorder(
                            horizontalInside: BorderSide(
                              color: LaooColors.border.withValues(alpha: .45),
                              width: .25,
                            ),
                          ),
                          dataRowMinHeight: 84,
                          dataRowMaxHeight: 96,
                          columnSpacing: 12,
                          sortColumnIndex: _sortColumn,
                          sortAscending: _sortAscending,
                          headingRowColor: WidgetStatePropertyAll(
                            p.primary.withValues(alpha: .1),
                          ),
                          headingTextStyle: TextStyle(
                            color: p.primary,
                            fontWeight: FontWeight.w700,
                          ),
                          columns: [
                            DataColumn(
                              columnWidth: LaooDataTable.idColumnWidth,
                              onSort: _onSort,
                              label: Text('ID'),
                            ),
                            DataColumn(
                              label: SizedBox(
                                width: 100,
                                child: Center(child: Text('Action')),
                              ),
                            ),
                            DataColumn(label: Text('Admin')),
                            DataColumn(label: Text('กฎ')),
                            DataColumn(label: Text('กำหนดอุปกรณ์')),
                            DataColumn(label: Text('รูปห้อง/แผนผัง')),
                            DataColumn(label: Text('สถานที่ตั้ง')),
                            DataColumn(
                              onSort: _onSort,
                              label: Text('ชื่อห้อง'),
                            ),
                            DataColumn(onSort: _onSort, label: Text('ความจุ')),
                            DataColumn(onSort: _onSort, label: Text('สถานะ')),
                          ],
                          rows: _filtered
                              .asMap()
                              .entries
                              .map(
                                (e) => DataRow(
                                  cells: [
                                    DataCell(
                                      Text('${_page * _size + e.key + 1}'),
                                    ),
                                    DataCell(
                                      SizedBox(
                                        width: 100,
                                        child: Center(
                                          child: _actionsRow(e.value, p),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      IconButton(
                                        tooltip: 'ผู้ดูแลห้องประชุม',
                                        color: p.primary,
                                        onPressed: () =>
                                            _showRoomAdmin(e.value, p),
                                        icon: const Icon(Icons.person_outline),
                                      ),
                                    ),
                                    DataCell(_rulesButton(e.value, p)),
                                    DataCell(_facilityButton(p, room: e.value)),
                                    DataCell(_roomImages(e.value)),
                                    DataCell(_roomLocationCell(e.value, p)),
                                    DataCell(
                                      Text(
                                        '${e.value['code']} | ${e.value['nameTh']}',
                                      ),
                                    ),
                                    DataCell(
                                      Text('${e.value['capacity'] ?? '-'}'),
                                    ),
                                    DataCell(_statusCell(e.value, p)),
                                  ],
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 8),
          WorkspaceSectionCard(child: _pagination(_total, p)),
        ],
      );
    },
  );
  InputDecoration _roomInput(String label, WorkspaceThemePreset p) =>
      InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: p.primary,
          fontSize: LaooTypography.inputLabel,
        ),
        floatingLabelStyle: TextStyle(
          color: p.primary,
          fontSize: LaooTypography.inputLabel,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: p.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: p.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: p.primary, width: 1.5),
        ),
      );
  Future<void> _edit({Map<String, dynamic>? item}) async {
    final code = TextEditingController(
          text: item?['code']?.toString().toUpperCase() ?? '',
        ),
        name = TextEditingController(text: item?['nameTh'] ?? ''),
        capacity = TextEditingController(text: '${item?['capacity'] ?? ''}'),
        description = TextEditingController(text: item?['description'] ?? '');
    var active = item?['isActive'] ?? true;
    final matchingBuilding = _buildings.where(
      (b) => b['buildingId'] == item?['buildingId'],
    );
    int? branchId = matchingBuilding.isEmpty
            ? null
            : matchingBuilding.first['branchId'] as int?,
        buildingId = item?['buildingId'],
        floorId = item?['floorId'];
    final facilityValues = <int, Map<String, dynamic>>{};
    for (final raw in (item?['facilityItems'] as List?) ?? const []) {
      final m = Map<String, dynamic>.from(raw as Map);
      facilityValues[(m['facilityId'] as num).toInt()] = m;
    }
    final preset = workspaceThemeController.value;
    String? branchError,
        buildingError,
        floorError,
        codeError,
        nameError,
        capacityError;
    code.addListener(() {
      final upper = code.text.toUpperCase();
      if (upper != code.text) {
        code.value = code.value.copyWith(
          text: upper,
          selection: TextSelection.collapsed(offset: upper.length),
        );
      }
    });
    PlatformFile? roomImage;
    PlatformFile? locationImage;
    final value = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dc) => StatefulBuilder(
        builder: (context, refresh) {
          final buildings = _buildings
              .where((b) => branchId == null || b['branchId'] == branchId)
              .toList();
          final floors = buildings
              .expand(
                (b) => (b['floors'] as List? ?? const [])
                    .cast<Map<String, dynamic>>(),
              )
              .where((f) => buildingId == null || f['buildingId'] == buildingId)
              .toList();

          Future<void> pickImage(bool location) async {
            final result = await FilePicker.platform.pickFiles(
              type: FileType.image,
              withData: true,
            );
            final picked = result?.files.single;
            if (picked?.bytes == null || picked!.size > 1024 * 1024) return;
            refresh(() {
              if (location) {
                locationImage = picked;
              } else {
                roomImage = picked;
              }
            });
          }

          Widget preview(PlatformFile? file, String? url, IconData icon) {
            if (file?.bytes != null) {
              return InkWell(
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (_) => Dialog(
                    child: InteractiveViewer(
                      child: Image.memory(file!.bytes!, fit: BoxFit.contain),
                    ),
                  ),
                ),
                child: Image.memory(
                  file!.bytes!,
                  width: 130,
                  height: 82,
                  fit: BoxFit.cover,
                ),
              );
            }
            if (url?.isNotEmpty == true) {
              return InkWell(
                onTap: () => _showRoomImage(url!),
                child: Image.network(
                  _imageUrl(url!),
                  width: 130,
                  height: 82,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => SizedBox(
                    width: 130,
                    height: 82,
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: preset.border,
                    ),
                  ),
                ),
              );
            }
            return SizedBox(
              width: 130,
              height: 82,
              child: Icon(icon, color: preset.border, size: 32),
            );
          }

          Widget uploadColumn({
            required String title,
            required IconData icon,
            required PlatformFile? file,
            required String? oldUrl,
            required VoidCallback onPick,
          }) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: LaooColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Center(child: preview(file, oldUrl, icon)),
                const SizedBox(height: 6),
                OutlinedButton.icon(
                  onPressed: onPick,
                  icon: Icon(icon, color: preset.primary),
                  label: Text(
                    file?.name ?? 'เลือกรูป',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: preset.primary),
                  ),
                ),
              ],
            );
          }

          return AlertDialog(
            title: Row(
              children: [
                Icon(
                  item == null ? Icons.add : Icons.edit_outlined,
                  color: preset.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  item == null ? 'เพิ่มห้องประชุม' : 'แก้ไขห้องประชุม',
                  style: LaooTypography.popupTitleStyle,
                ),
              ],
            ),
            content: SizedBox(
              width: (MediaQuery.sizeOf(context).width - 48)
                  .clamp(280.0, 620.0)
                  .toDouble(),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Divider(color: preset.primary.withValues(alpha: .45)),
                    Row(
                      children: [
                        const Text('พร้อมใช้งาน'),
                        const SizedBox(width: 8),
                        Switch(
                          value: active,
                          trackColor: WidgetStatePropertyAll(preset.primary),
                          thumbColor: const WidgetStatePropertyAll(
                            Colors.white,
                          ),
                          onChanged: (v) => refresh(() => active = v),
                        ),
                      ],
                    ),
                    LayoutBuilder(
                      builder: (context, box) {
                        final compact = box.maxWidth < 560;
                        final branchField = DropdownButtonFormField<int>(
                          style: const TextStyle(
                            fontSize: LaooTypography.comboBox,
                          ),
                          initialValue: branchId,
                          decoration: _roomInput(
                            'สาขา *',
                            preset,
                          ).copyWith(errorText: branchError),
                          items: _branches
                              .map(
                                (b) => DropdownMenuItem<int>(
                                  value: b['branchId'] as int,
                                  child: Text(
                                    b['branchCode'].toString() +
                                        ' ' +
                                        b['branchNameTh'].toString(),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => refresh(() {
                            branchId = v;
                            branchError = null;
                            buildingId = null;
                            buildingError = null;
                            floorId = null;
                            floorError = null;
                          }),
                        );
                        final buildingField = DropdownButtonFormField<int>(
                          style: const TextStyle(
                            fontSize: LaooTypography.comboBox,
                          ),
                          initialValue: buildingId,
                          decoration: _roomInput(
                            'อาคาร *',
                            preset,
                          ).copyWith(errorText: buildingError),
                          items: buildings
                              .map(
                                (b) => DropdownMenuItem<int>(
                                  value: b['buildingId'] as int,
                                  child: Text(
                                    b['code'].toString() +
                                        ' ' +
                                        b['nameTh'].toString(),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => refresh(() {
                            buildingId = v;
                            buildingError = null;
                            floorId = null;
                            floorError = null;
                          }),
                        );
                        final floorField = DropdownButtonFormField<int>(
                          style: const TextStyle(
                            fontSize: LaooTypography.comboBox,
                          ),
                          initialValue:
                              floors.any((f) => f['floorId'] == floorId)
                              ? floorId
                              : null,
                          decoration: _roomInput(
                            'ชั้น *',
                            preset,
                          ).copyWith(errorText: floorError),
                          items: floors
                              .map(
                                (f) => DropdownMenuItem<int>(
                                  value: f['floorId'] as int,
                                  child: Text(
                                    f['code'].toString() +
                                        ' ' +
                                        f['nameTh'].toString(),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => refresh(() {
                            floorId = v;
                            floorError = null;
                          }),
                        );
                        return compact
                            ? Column(
                                children: [
                                  branchField,
                                  const SizedBox(height: 10),
                                  buildingField,
                                  const SizedBox(height: 10),
                                  floorField,
                                ],
                              )
                            : Row(
                                children: [
                                  Expanded(child: branchField),
                                  const SizedBox(width: 10),
                                  Expanded(child: buildingField),
                                  const SizedBox(width: 10),
                                  Expanded(child: floorField),
                                ],
                              );
                      },
                    ),
                    const SizedBox(height: 10),
                    LayoutBuilder(
                      builder: (context, box) {
                        final compact = box.maxWidth < 560;
                        final fields = [
                          SizedBox(
                            width: compact ? double.infinity : 180,
                            child: TextField(
                              controller: code,
                              onChanged: (_) => refresh(() => codeError = null),
                              style: const TextStyle(
                                fontSize: LaooTypography.inputText,
                              ),
                              decoration: _roomInput(
                                'รหัสห้อง *',
                                preset,
                              ).copyWith(errorText: codeError),
                            ),
                          ),
                          SizedBox(
                            width: compact ? double.infinity : 120,
                            child: TextField(
                              controller: capacity,
                              onChanged: (_) =>
                                  refresh(() => capacityError = null),
                              style: const TextStyle(
                                fontSize: LaooTypography.inputText,
                              ),
                              keyboardType: TextInputType.number,
                              decoration: _roomInput(
                                'ความจุ *',
                                preset,
                              ).copyWith(errorText: capacityError),
                            ),
                          ),
                        ];
                        final nameField = TextField(
                          controller: name,
                          onChanged: (_) => refresh(() => nameError = null),
                          style: const TextStyle(
                            fontSize: LaooTypography.inputText,
                          ),
                          decoration: _roomInput(
                            'ชื่อห้อง *',
                            preset,
                          ).copyWith(errorText: nameError),
                        );
                        return compact
                            ? Column(
                                children: [
                                  fields[0],
                                  const SizedBox(height: 10),
                                  nameField,
                                  const SizedBox(height: 10),
                                  fields[1],
                                ],
                              )
                            : Row(
                                children: [
                                  fields[0],
                                  const SizedBox(width: 12),
                                  Expanded(child: nameField),
                                  const SizedBox(width: 12),
                                  fields[1],
                                ],
                              );
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: description,
                      style: const TextStyle(
                        fontSize: LaooTypography.inputText,
                      ),
                      maxLines: 1,
                      decoration: _roomInput('รายละเอียด', preset),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: uploadColumn(
                            title: 'รูปห้องประชุม',
                            icon: Icons.meeting_room_outlined,
                            file: roomImage,
                            oldUrl: item?['roomImageUrl']?.toString(),
                            onPick: () => pickImage(false),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: uploadColumn(
                            title: 'รูปแผนผัง',
                            icon: Icons.map_outlined,
                            file: locationImage,
                            oldUrl: item?['locationImageUrl']?.toString(),
                            onPick: () => pickImage(true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'รูปขนาดไม่เกิน 1 MB',
                        style: TextStyle(fontSize: 12, color: preset.primary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Divider(color: preset.primary, height: 1),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await _pickFacilities(
                            preset,
                            facilityValues,
                            roomName: item == null
                                ? null
                                : item['code'].toString() +
                                      ' ' +
                                      item['nameTh'].toString(),
                          );
                          if (picked != null) {
                            refresh(
                              () => facilityValues
                                ..clear()
                                ..addAll(picked),
                            );
                          }
                        },
                        icon: Icon(
                          Icons.devices_other_outlined,
                          color: preset.primary,
                        ),
                        label: Text(
                          'อุปกรณ์',
                          style: TextStyle(color: preset.primary),
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: preset.primary,
                        ),
                        onPressed: () => Navigator.pop(dc),
                        child: const Text('ยกเลิก'),
                      ),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: preset.primary,
                          foregroundColor: Theme.of(
                            context,
                          ).colorScheme.onPrimary,
                        ),
                        onPressed: () {
                          if (branchId == null) branchError = 'กรุณาเลือกสาขา';
                          if (buildingId == null)
                            buildingError = 'กรุณาเลือกอาคาร';
                          if (floorId == null) floorError = 'กรุณาเลือกชั้น';
                          if (code.text.trim().isEmpty)
                            codeError = 'กรุณากรอกรหัสห้อง';
                          if (name.text.trim().isEmpty)
                            nameError = 'กรุณากรอกชื่อห้อง';
                          if (capacity.text.trim().isEmpty)
                            capacityError = 'กรุณากรอกความจุ';
                          final parsedCapacity = int.tryParse(
                            capacity.text.trim(),
                          );
                          if (capacity.text.trim().isNotEmpty &&
                              parsedCapacity == null) {
                            capacityError = 'ความจุต้องเป็นตัวเลข';
                          }
                          if (branchError != null ||
                              buildingError != null ||
                              floorError != null ||
                              codeError != null ||
                              nameError != null ||
                              capacityError != null) {
                            refresh(() {});
                            return;
                          }
                          if (!context.mounted) return;
                          Navigator.pop(dc, {
                            'buildingId': buildingId,
                            'floorId': floorId,
                            'code': code.text.trim(),
                            'nameTh': name.text.trim(),
                            'capacity': parsedCapacity,
                            'description': description.text.trim(),
                            'facilityItems': facilityValues.values.toList(),
                            'isActive': active,
                          });
                        },
                        child: const Text('บันทึก'),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
    code.dispose();
    name.dispose();
    capacity.dispose();
    description.dispose();
    if (value == null) return;
    try {
      final id = await _repo.save(value, id: item?['roomId']);
      if (roomImage?.bytes != null) {
        await _repo.uploadImage(id, 'room', roomImage!.bytes!, roomImage!.name);
      }
      if (locationImage?.bytes != null) {
        await _repo.uploadImage(
          id,
          'location',
          locationImage!.bytes!,
          locationImage!.name,
        );
      }
      setState(() => _message = 'บันทึกข้อมูลสำเร็จ');
      await _load();
    } catch (e) {
      final message = _error(e, 'บันทึกข้อมูลไม่สำเร็จ');
      setState(() => _message = message);
    }
  }

  Future<void> _upload(int id, String kind) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    final f = result?.files.single;
    if (f?.bytes != null && f!.size <= 1024 * 1024)
      await _repo.uploadImage(id, kind, f.bytes!, f.name);
  }

  Future<Map<int, Map<String, dynamic>>?> _pickFacilities(
    WorkspaceThemePreset preset,
    Map<int, Map<String, dynamic>> selected, {
    String? roomName,
  }) async {
    final checked = <int>{...selected.keys};
    final quantities = <int, TextEditingController>{
      for (final e in selected.entries)
        e.key: TextEditingController(text: '${e.value['quantity'] ?? ''}'),
    };
    final remarks = <int, TextEditingController>{
      for (final e in selected.entries)
        e.key: TextEditingController(text: '${e.value['remark'] ?? ''}'),
    };
    final result = await showDialog<Map<int, Map<String, dynamic>>>(
      context: context,
      builder: (dc) => StatefulBuilder(
        builder: (context, refresh) => AlertDialog(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.devices_other_outlined, color: preset.primary),
                  const SizedBox(width: 8),
                  Text('เลือกอุปกรณ์', style: LaooTypography.popupTitleStyle),
                ],
              ),
              if (roomName != null) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  color: preset.primary.withValues(alpha: .12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Text(
                    roomName!,
                    style: TextStyle(
                      color: preset.primary,
                      fontSize: LaooTypography.sectionTitle,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Divider(color: preset.primary.withValues(alpha: .45), height: 1),
            ],
          ),
          content: SizedBox(
            width: 560,
            height: 420,
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    children: _facilities.map((f) {
                      final id = (f['facilityId'] as num).toInt();
                      final on = checked.contains(id);
                      final facilityActive = selected[id]?['isActive'] != false;
                      quantities.putIfAbsent(id, () => TextEditingController());
                      remarks.putIfAbsent(id, () => TextEditingController());
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            CheckboxListTile(
                              value: on,
                              activeColor: preset.primary,
                              controlAffinity: ListTileControlAffinity.leading,
                              contentPadding: EdgeInsets.zero,
                              title: Text('${f['code']} ${f['nameTh']}'),
                              secondary: Switch(
                                value: facilityActive,
                                activeTrackColor: preset.primary,
                                onChanged: (v) => refresh(() {
                                  selected[id] = {
                                    ...(selected[id] ?? {'facilityId': id}),
                                    'isActive': v,
                                  };
                                }),
                              ),
                              onChanged: (v) => refresh(() {
                                if (v == true) {
                                  checked.add(id);
                                } else {
                                  checked.remove(id);
                                }
                              }),
                            ),
                            if (on)
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: quantities[id],
                                      keyboardType: TextInputType.number,
                                      decoration: _roomInput('จำนวน', preset),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    flex: 2,
                                    child: TextField(
                                      controller: remarks[id],
                                      decoration: _roomInput(
                                        'หมายเหตุ',
                                        preset,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            Divider(color: preset.border, height: 18),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
                Divider(
                  color: preset.primary.withValues(alpha: .45),
                  height: 1,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dc),
              child: Text('ยกเลิก', style: TextStyle(color: preset.primary)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: preset.primary),
              onPressed: () => Navigator.pop(dc, {
                for (final id in checked)
                  id: {
                    'facilityId': id,
                    'quantity': int.tryParse(quantities[id]!.text),
                    'remark': remarks[id]!.text.trim().isEmpty
                        ? null
                        : remarks[id]!.text.trim(),
                    'isActive': selected[id]?['isActive'] != false,
                  },
              }),
              child: const Text('บันทึก'),
            ),
          ],
        ),
      ),
    );
    for (final c in quantities.values) {
      c.dispose();
    }
    for (final c in remarks.values) {
      c.dispose();
    }
    return result;
  }

  Future<void> _confirmRoomDelete(Map<String, dynamic> room) async {
    final preset = workspaceThemeController.value;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: preset.primary.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.delete_outline, color: preset.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'ยืนยันการลบข้อมูล',
                style: LaooTypography.popupTitleStyle,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: preset.primary.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'ต้องการลบ ${room['code']} - ${room['nameTh']} หรือไม่?',
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 12),
            const Text('ข้อมูลที่ลบแล้วไม่สามารถเรียกคืนกลับมาได้'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('ยกเลิก', style: TextStyle(color: preset.primary)),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _repo.delete(room['roomId']);
      if (mounted) {
        setState(() => _message = 'ลบข้อมูลสำเร็จ');
        await _load();
      }
    } catch (error) {
      if (mounted)
        setState(() => _message = _error(error, 'ลบข้อมูลไม่สำเร็จ'));
    }
  }

  Future<void> _deleteLegacy(Map<String, dynamic> r) async {
    final p = workspaceThemeController.value;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.delete_outline, color: Colors.red),
            ),
            const SizedBox(height: 14),
            const Text(
              'ยืนยันการลบข้อมูล',
              style: LaooTypography.popupTitleStyle,
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: .08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'ต้องการลบ ${r['code']} - ${r['nameTh']} หรือไม่?',
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'ข้อมูลที่ลบแล้วไม่สามารถเรียกคืนกลับมาได้',
              style: TextStyle(fontSize: LaooTypography.validation),
            ),
          ],
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: p.primary),
            onPressed: () => Navigator.pop(c, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(c, true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await _repo.delete(r['roomId']);
        setState(() => _message = 'ลบข้อมูลสำเร็จ');
        await _load();
      } catch (e) {
        setState(() => _message = _error(e, 'ลบข้อมูลไม่สำเร็จ'));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = workspaceThemeController.value;
    final filterBuildings = _buildings
        .where(
          (b) => _filterBranchId == null || b['branchId'] == _filterBranchId,
        )
        .toList();
    final filterFloors = filterBuildings
        .expand(
          (b) =>
              (b['floors'] as List? ?? const []).cast<Map<String, dynamic>>(),
        )
        .where(
          (f) =>
              _filterBuildingId == null || f['buildingId'] == _filterBuildingId,
        )
        .toList();
    return SupportWorkspaceShell(
      menuScope: WorkspaceMenuScope.company,
      pageTitle: _caption,
      activeMenu: '23002',
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(LaooLayout.cardMargin),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                WorkspaceSectionCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: WorkspacePageTitle(
                          title: _caption,
                          favoriteKey: '23002',
                        ),
                      ),
                      if (MediaQuery.sizeOf(context).width >= 900)
                        IconButton(
                          tooltip: _showCards ? 'แสดง List' : 'แสดง Card',
                          style: IconButton.styleFrom(
                            foregroundColor: p.primary,
                            side: BorderSide(color: p.primary),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                LaooRadius.xs,
                              ),
                            ),
                          ),
                          onPressed: () =>
                              setState(() => _showCards = !_showCards),
                          icon: Icon(
                            _showCards
                                ? Icons.table_rows_outlined
                                : Icons.grid_view_outlined,
                          ),
                        ),
                      if (MediaQuery.sizeOf(context).width >= 900)
                        const SizedBox(width: 8),
                      if (_actions['create'] == true)
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: p.primary,
                            foregroundColor: Theme.of(
                              context,
                            ).colorScheme.onPrimary,
                          ),
                          onPressed: () => _edit(),
                          icon: const Icon(Icons.add),
                          label: const Text('เพิ่ม'),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                WorkspaceSectionCard(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 600;
                      final filterWidth = compact
                          ? constraints.maxWidth
                          : 180.0;
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          SizedBox(
                            width: compact ? constraints.maxWidth : 260,
                            child: TextField(
                              controller: _search,
                              onSubmitted: (_) => setState(() => _page = 0),
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.search),
                                suffixIcon: const Icon(Icons.arrow_forward),
                                labelText: 'ค้นหารหัสหรือชื่อ',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                    LaooRadius.xs,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: p.primary,
                              foregroundColor: Theme.of(
                                context,
                              ).colorScheme.onPrimary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  LaooRadius.xs,
                                ),
                              ),
                            ),
                            onPressed: () => setState(() => _page = 0),
                            icon: const Icon(Icons.search),
                            label: const Text('ค้นหา'),
                          ),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: p.primary,
                              side: BorderSide(color: p.primary),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  LaooRadius.xs,
                                ),
                              ),
                            ),
                            onPressed: () {
                              _search.clear();
                              setState(() {
                                _filterBranchId = null;
                                _filterBuildingId = null;
                                _filterFloorId = null;
                                _page = 0;
                              });
                            },
                            icon: const Icon(Icons.clear),
                            label: const Text('ล้าง Filter'),
                          ),
                          SizedBox(
                            width: filterWidth,
                            child: DropdownButtonFormField<int>(
                              isExpanded: true,
                              style: const TextStyle(
                                fontSize: LaooTypography.comboBox,
                              ),
                              value: _filterBranchId,
                              decoration: const InputDecoration(
                                labelText: 'สาขา',
                              ),
                              items: <DropdownMenuItem<int>>[
                                const DropdownMenuItem<int>(
                                  value: null,
                                  child: Text(
                                    'ทั้งหมด',
                                    style: TextStyle(
                                      fontSize: LaooTypography.comboBox,
                                    ),
                                  ),
                                ),
                                ..._branches.map<DropdownMenuItem<int>>(
                                  (b) => DropdownMenuItem<int>(
                                    value: b['branchId'] as int,
                                    child: Text(
                                      '${b['branchNameTh']}',
                                      style: const TextStyle(
                                        fontSize: LaooTypography.comboBox,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              onChanged: (v) => setState(() {
                                _filterBranchId = v;
                                _filterBuildingId = null;
                                _filterFloorId = null;
                                _page = 0;
                              }),
                            ),
                          ),
                          SizedBox(
                            width: filterWidth,
                            child: DropdownButtonFormField<int>(
                              isExpanded: true,
                              style: const TextStyle(
                                fontSize: LaooTypography.comboBox,
                              ),
                              value:
                                  filterBuildings.any(
                                    (b) => b['buildingId'] == _filterBuildingId,
                                  )
                                  ? _filterBuildingId
                                  : null,
                              decoration: const InputDecoration(
                                labelText: 'อาคาร',
                              ),
                              items: <DropdownMenuItem<int>>[
                                const DropdownMenuItem<int>(
                                  value: null,
                                  child: Text(
                                    'ทั้งหมด',
                                    style: TextStyle(
                                      fontSize: LaooTypography.comboBox,
                                    ),
                                  ),
                                ),
                                ...filterBuildings.map<DropdownMenuItem<int>>(
                                  (b) => DropdownMenuItem<int>(
                                    value: b['buildingId'] as int,
                                    child: Text(
                                      '${b['nameTh']}',
                                      style: const TextStyle(
                                        fontSize: LaooTypography.comboBox,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              onChanged: (v) => setState(() {
                                _filterBuildingId = v;
                                _filterFloorId = null;
                                _page = 0;
                              }),
                            ),
                          ),
                          SizedBox(
                            width: compact ? constraints.maxWidth : 120,
                            child: DropdownButtonFormField<int>(
                              isExpanded: true,
                              style: const TextStyle(
                                fontSize: LaooTypography.comboBox,
                              ),
                              value:
                                  filterFloors.any(
                                    (f) => f['floorId'] == _filterFloorId,
                                  )
                                  ? _filterFloorId
                                  : null,
                              decoration: const InputDecoration(
                                labelText: 'ชั้น',
                              ),
                              items: <DropdownMenuItem<int>>[
                                const DropdownMenuItem<int>(
                                  value: null,
                                  child: Text(
                                    'ทั้งหมด',
                                    style: TextStyle(
                                      fontSize: LaooTypography.comboBox,
                                    ),
                                  ),
                                ),
                                ...filterFloors.map<DropdownMenuItem<int>>(
                                  (f) => DropdownMenuItem<int>(
                                    value: f['floorId'] as int,
                                    child: Text(
                                      '${f['nameTh']}',
                                      style: const TextStyle(
                                        fontSize: LaooTypography.comboBox,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              onChanged: (v) => setState(() {
                                _filterFloorId = v;
                                _page = 0;
                              }),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
                if (_loading) const LinearProgressIndicator(),
                Expanded(child: _roomContent(p)),
              ],
            ),
          ),
          if (_message != null)
            Positioned(
              top: 12,
              right: 12,
              child: AutoDismissMessage(
                message: _message!,
                onClose: () => setState(() => _message = null),
              ),
            ),
        ],
      ),
    );
  }

  Widget _actionsRow(Map<String, dynamic> r, WorkspaceThemePreset p) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (_actions['edit'] == true)
        IconButton(
          onPressed: () => _edit(item: r),
          icon: Icon(Icons.edit_outlined, color: p.primary),
        ),
      if (_actions['delete'] == true)
        IconButton(
          onPressed: () => _confirmRoomDelete(r),
          icon: const Icon(Icons.delete_outline, color: Colors.red),
        ),
    ],
  );
  Widget _pagination(int total, WorkspaceThemePreset p) {
    final pages = (total / _size).ceil();
    final muted = Theme.of(context).colorScheme.surfaceContainerHighest;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(LaooRadius.xs),
    );
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            backgroundColor: muted,
            disabledBackgroundColor: muted,
            foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
            disabledForegroundColor: Theme.of(
              context,
            ).colorScheme.onSurfaceVariant,
            side: BorderSide.none,
            shape: shape,
          ),
          onPressed: _page > 0 ? () => setState(() => _page--) : null,
          child: const Icon(Icons.chevron_left),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: p.primary,
            disabledBackgroundColor: p.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            disabledForegroundColor: Theme.of(context).colorScheme.onPrimary,
            shape: shape,
            padding: const EdgeInsets.all(14),
          ),
          onPressed: null,
          child: Text('${pages == 0 ? 0 : _page + 1}'),
        ),
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            backgroundColor: muted,
            disabledBackgroundColor: muted,
            foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
            disabledForegroundColor: Theme.of(
              context,
            ).colorScheme.onSurfaceVariant,
            side: BorderSide.none,
            shape: shape,
          ),
          onPressed: _page < pages - 1 ? () => setState(() => _page++) : null,
          child: const Icon(Icons.chevron_right),
        ),
        Text(
          '${total == 0 ? 0 : _page * _size + 1}-${((_page + 1) * _size).clamp(0, total)} จาก $total',
        ),
      ],
    );
  }
}
