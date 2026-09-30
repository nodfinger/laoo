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

class MeetingNoShowReportPage extends StatefulWidget {
  const MeetingNoShowReportPage({super.key});

  @override
  State<MeetingNoShowReportPage> createState() =>
      _MeetingNoShowReportPageState();
}

class _MeetingNoShowReportPageState extends State<MeetingNoShowReportPage> {
  final _repository = MeetingAttendanceRepository();
  final _today = DateUtils.dateOnly(DateTime.now());
  late DateTime _from = DateTime(_today.year, _today.month, 1);
  late DateTime _to = _today;
  String _caption = 'รายงาน No-show';
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
          menuCode: MeetingMenuCodes.noShowReport,
          routeName: MeetingRouteNames.noShowReport,
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

  String _dateTime(Object? value) {
    final dateTime = DateTime.tryParse('$value')?.toLocal();
    return dateTime == null
        ? '-'
        : '${_date(dateTime)} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _notify(String value, {bool error = false}) => setState(() {
    _message = value;
    _messageError = error;
  });

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _repository.noShowReport(
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
      final detail = error is ApiException
          ? '${error.message}${error.description == null ? '' : '\n${error.description}'}'
          : 'ไม่สามารถโหลดรายงานได้\nรายละเอียดเพิ่มเติม: $error';
      if (mounted) _notify(detail, error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDate(bool isFrom) async {
    final value = await showDatePicker(
      context: context,
      initialDate: isFrom ? _from : _to,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (value == null || !mounted) return;
    setState(() {
      if (isFrom) {
        _from = value;
        if (_to.isBefore(value)) _to = value;
      } else {
        _to = value;
        if (_from.isAfter(value)) _from = value;
      }
      _page = 1;
    });
  }

  Widget _filters() => WorkspaceSectionCard(
    child: Wrap(
      spacing: 8,
      runSpacing: 8,
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

  Widget _itemCard(
    Map<String, dynamic> item,
    WorkspaceThemePreset preset,
  ) => WorkspaceSectionCard(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.person_off_outlined, color: LaooColors.error),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${item['participantName'] ?? '-'}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 5),
              Text('${item['bookingNo'] ?? '-'} | ${item['subject'] ?? '-'}'),
              const SizedBox(height: 4),
              Text('${item['roomCode'] ?? '-'} | ${item['roomName'] ?? '-'}'),
              const SizedBox(height: 4),
              Text(
                'เวลาประชุม ${_dateTime(item['startDateTime'])} - ${_dateTime(item['endDateTime'])}',
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: preset.primary.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(LaooRadius.xs),
          ),
          child: Text(
            'ไม่เช็กอิน',
            style: TextStyle(
              color: preset.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );

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
    return buildMeetingWorkspaceShell(
      pageTitle: _caption,
      activeMenu: MeetingMenuCodes.noShowReport,
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
                    favoriteKey: MeetingMenuCodes.noShowReport,
                    actions: const [],
                  ),
                ),
                const SizedBox(height: LaooLayout.listSectionSpacing),
                WorkspaceSectionCard(
                  child: Row(
                    children: [
                      Icon(Icons.person_off_outlined, color: LaooColors.error),
                      const SizedBox(width: 12),
                      Text(
                        'ผู้ตอบรับแต่ไม่เช็กอิน $_total คน',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: LaooLayout.listSectionSpacing),
                _filters(),
                const SizedBox(height: LaooLayout.listSectionSpacing),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _items.isEmpty
                      ? const Center(
                          child: Text('ไม่พบผู้ไม่เข้าประชุมในช่วงวันที่เลือก'),
                        )
                      : ListView.separated(
                          itemCount: _items.length,
                          separatorBuilder: (_, _) => const SizedBox(
                            height: LaooLayout.listItemSpacing,
                          ),
                          itemBuilder: (_, index) =>
                              _itemCard(_items[index], preset),
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
