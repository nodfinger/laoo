import 'package:flutter/material.dart';

import '../../../app/theme/laoo_design_tokens.dart';
import '../../../app/theme/workspace_theme_presets.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/navigation/navigation_menu_repository.dart';
import '../../../core/widgets/auto_dismiss_message.dart';
import '../../support/presentation/widgets/support_workspace_shell.dart';
import '../data/meeting_attendance_repository.dart';
import '../meeting_feature_host.dart';
import '../meeting_route_contract.dart';
import '../widgets/meeting_pagination_card.dart';

class MeetingUtilizationReportPage extends StatefulWidget {
  const MeetingUtilizationReportPage({super.key});

  @override
  State<MeetingUtilizationReportPage> createState() =>
      _MeetingUtilizationReportPageState();
}

class _MeetingUtilizationReportPageState
    extends State<MeetingUtilizationReportPage> {
  final _repository = MeetingAttendanceRepository();
  final _today = DateUtils.dateOnly(DateTime.now());
  late DateTime _from = DateTime(_today.year, _today.month, 1);
  late DateTime _to = _today;
  String _caption = 'รายงานการใช้ห้อง';
  String? _message;
  bool _messageError = false;
  bool _loading = true;
  List<Map<String, dynamic>> _items = [];
  int _total = 0;
  int _page = 1;
  static const _pageSize = 20;

  @override
  void initState() {
    super.initState();
    NavigationMenuRepository()
        .resolveMenuName(
          menuCode: MeetingMenuCodes.utilizationReport,
          routeName: MeetingRouteNames.utilizationReport,
          fallback: _caption,
        )
        .then((value) {
          if (mounted) setState(() => _caption = value);
        });
    _load();
  }

  @override
  void dispose() {
    _repository.dispose();
    super.dispose();
  }

  String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

  String _errorText(Object error) => error is ApiException
      ? '${error.message}${error.description == null ? '' : '\n${error.description}'}'
      : 'ไม่สามารถโหลดรายงานได้\nรายละเอียดเพิ่มเติม: $error';

  void _notify(String value, {bool error = false}) => setState(() {
    _message = value;
    _messageError = error;
  });

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _repository.utilizationReport(
        dateFrom: _from,
        dateTo: _to,
        page: _page,
        pageSize: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _items = List<Map<String, dynamic>>.from(
          data['items'] as List? ?? const [],
        );
        _total = (data['total'] as num?)?.toInt() ?? 0;
      });
    } catch (error) {
      if (mounted) _notify(_errorText(error), error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDate(bool isFrom) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: isFrom ? _from : _to,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (selected == null || !mounted) return;
    setState(() {
      if (isFrom) {
        _from = selected;
        if (_to.isBefore(selected)) _to = selected;
      } else {
        _to = selected;
        if (_from.isAfter(selected)) _from = selected;
      }
      _page = 1;
    });
  }

  int _number(Map<String, dynamic> item, String key) =>
      (item[key] as num?)?.toInt() ?? 0;

  Widget _summaryCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) => Expanded(
    child: WorkspaceSectionCard(
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: LaooColors.textSecondary),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _filters() => WorkspaceSectionCard(
    child: Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        OutlinedButton.icon(
          onPressed: () => _pickDate(true),
          icon: const Icon(Icons.calendar_today_outlined),
          label: Text('จาก ${_date(_from)}'),
        ),
        OutlinedButton.icon(
          onPressed: () => _pickDate(false),
          icon: const Icon(Icons.event_outlined),
          label: Text('ถึง ${_date(_to)}'),
        ),
        FilledButton.icon(
          onPressed: () {
            setState(() => _page = 1);
            _load();
          },
          icon: const Icon(Icons.search),
          label: const Text('ค้นหา'),
        ),
        OutlinedButton.icon(
          onPressed: () {
            setState(() {
              _from = DateTime(_today.year, _today.month, 1);
              _to = _today;
              _page = 1;
            });
            _load();
          },
          icon: const Icon(Icons.clear),
          label: const Text('ล้าง Filter'),
        ),
      ],
    ),
  );

  Widget _roomCard(Map<String, dynamic> item, WorkspaceThemePreset preset) {
    final minutes = _number(item, 'minutes');
    final hours = (minutes / 60).toStringAsFixed(1);
    return WorkspaceSectionCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.meeting_room_outlined, color: preset.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item['roomCode'] ?? '-'} | ${item['roomName'] ?? '-'}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 16,
                  runSpacing: 6,
                  children: [
                    Text('รอบการจอง ${_number(item, 'bookingCount')} รายการ'),
                    Text('ช่วงเวลา ${_number(item, 'slotCount')} รอบ'),
                    Text('ใช้ห้อง $hours ชม.'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pager() {
    return MeetingPaginationCard(
      total: _total,
      pageIndex: _page - 1,
      pageSize: _pageSize,
      primary: workspaceThemeController.value.primary,
      onPrevious: _page > 1
          ? () {
              setState(() => _page--);
              _load();
            }
          : null,
      onNext: _page * _pageSize < _total
          ? () {
              setState(() => _page++);
              _load();
            }
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final preset = workspaceThemeController.value;
    final bookings = _items.fold<int>(
      0,
      (sum, item) => sum + _number(item, 'bookingCount'),
    );
    final minutes = _items.fold<int>(
      0,
      (sum, item) => sum + _number(item, 'minutes'),
    );
    return buildMeetingWorkspaceShell(
      pageTitle: _caption,
      activeMenu: MeetingMenuCodes.utilizationReport,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(LaooLayout.cardMargin),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                WorkspaceSectionCard(
                  child: WorkspaceActionHeader(
                    title: _caption,
                    favoriteKey: MeetingMenuCodes.utilizationReport,
                    actions: const [],
                  ),
                ),
                const SizedBox(height: LaooLayout.listSectionSpacing),
                Row(
                  children: [
                    _summaryCard(
                      icon: Icons.meeting_room_outlined,
                      label: 'ห้องที่มีการใช้งาน',
                      value: '$_total ห้อง',
                      color: preset.primary,
                    ),
                    const SizedBox(width: LaooLayout.cardSpacing),
                    _summaryCard(
                      icon: Icons.event_available_outlined,
                      label: 'รอบการจอง',
                      value: '$bookings รายการ',
                      color: LaooColors.success,
                    ),
                    const SizedBox(width: LaooLayout.cardSpacing),
                    _summaryCard(
                      icon: Icons.schedule_outlined,
                      label: 'ชั่วโมงใช้งาน (หน้านี้)',
                      value: '${(minutes / 60).toStringAsFixed(1)} ชม.',
                      color: LaooColors.blue,
                    ),
                  ],
                ),
                const SizedBox(height: LaooLayout.listSectionSpacing),
                _filters(),
                const SizedBox(height: LaooLayout.listSectionSpacing),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _items.isEmpty
                      ? const Center(
                          child: Text('ไม่พบข้อมูลการใช้ห้องในช่วงวันที่เลือก'),
                        )
                      : ListView.separated(
                          itemCount: _items.length,
                          separatorBuilder: (_, _) => const SizedBox(
                            height: LaooLayout.listItemSpacing,
                          ),
                          itemBuilder: (_, index) =>
                              _roomCard(_items[index], preset),
                        ),
                ),
                const SizedBox(height: LaooLayout.listSectionSpacing),
                _pager(),
              ],
            ),
          ),
          if (_message != null)
            Positioned(
              top: 12,
              right: 12,
              child: AutoDismissMessage(
                message: _message!,
                error: _messageError,
                onClose: () => setState(() => _message = null),
              ),
            ),
        ],
      ),
    );
  }
}
