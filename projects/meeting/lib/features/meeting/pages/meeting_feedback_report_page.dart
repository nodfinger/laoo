import 'package:flutter/material.dart';

import '../../../app/theme/laoo_design_tokens.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/navigation/navigation_menu_repository.dart';
import '../../../core/widgets/auto_dismiss_message.dart';
import '../../support/presentation/widgets/support_workspace_shell.dart';
import '../data/meeting_room_usage_repository.dart';
import '../meeting_feature_host.dart';
import '../meeting_route_contract.dart';
import '../widgets/meeting_pagination_card.dart';

class MeetingFeedbackReportPage extends StatefulWidget {
  const MeetingFeedbackReportPage({super.key});

  @override
  State<MeetingFeedbackReportPage> createState() =>
      _MeetingFeedbackReportPageState();
}

class _MeetingFeedbackReportPageState extends State<MeetingFeedbackReportPage> {
  final _repo = MeetingRoomUsageRepository();
  final _search = TextEditingController();
  DateTime _from = DateTime.now().subtract(const Duration(days: 30));
  DateTime _to = DateTime.now();
  int? _roomId;
  int _page = 1, _total = 0;
  bool _loading = true;
  String? _loadError;
  String _caption = 'ผลประเมินห้องประชุม';
  String _message = '';
  bool _messageError = false;
  List<Map<String, dynamic>> _rooms = const [];
  List<Map<String, dynamic>> _items = const [];
  Map<String, dynamic> _summary = const {};

  @override
  void initState() {
    super.initState();
    _loadCaption();
    _loadRooms();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadCaption() async {
    final caption = await NavigationMenuRepository().resolveMenuName(
      menuCode: MeetingMenuCodes.feedbackReport,
      routeName: MeetingRouteNames.feedbackReport,
      fallback: _caption,
    );
    if (mounted) setState(() => _caption = caption);
  }

  Future<void> _loadRooms() async {
    try {
      final rooms = await _repo.rooms();
      if (mounted) setState(() => _rooms = rooms);
    } catch (_) {}
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final result = await _repo.feedback(
        from: _from,
        to: _to,
        search: _search.text,
        roomId: _roomId,
        page: _page,
      );
      if (!mounted) return;
      setState(() {
        _items = List<Map<String, dynamic>>.from(
          result['items'] as List? ?? const [],
        );
        _summary = Map<String, dynamic>.from(
          result['summary'] as Map? ?? const {},
        );
        _total = (result['total'] as num?)?.toInt() ?? _items.length;
      });
    } catch (error) {
      if (mounted) {
        final message = _error(error);
        setState(() {
          _items = const [];
          _summary = const {};
          _total = 0;
          _loadError = message;
        });
        _notify(message, true);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDate(bool from) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: from ? _from : _to,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (from) {
        _from = picked;
        if (_from.isAfter(_to)) _to = picked;
      } else {
        _to = picked;
        if (_to.isBefore(_from)) _from = picked;
      }
      _page = 1;
    });
  }

  void _notify(String message, bool error) => setState(() {
    _message = message;
    _messageError = error;
  });

  @override
  Widget build(BuildContext context) => buildMeetingWorkspaceShell(
    pageTitle: _caption,
    activeMenu: MeetingRouteNames.feedbackReport,
    child: Padding(
      padding: const EdgeInsets.all(LaooLayout.cardMargin),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              WorkspaceSectionCard(
                child: WorkspacePageTitle(
                  title: _caption,
                  favoriteKey: MeetingMenuCodes.feedbackReport,
                ),
              ),
              const SizedBox(height: 6),
              WorkspaceSectionCard(child: _filters()),
              const SizedBox(height: LaooLayout.listSectionSpacing),
              _summaryCards(),
              const SizedBox(height: LaooLayout.listSectionSpacing),
              Expanded(
                child: WorkspaceSectionCard(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _loadError != null
                      ? Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 420),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(_loadError!, textAlign: TextAlign.center),
                                const SizedBox(height: 16),
                                OutlinedButton(
                                  onPressed: _load,
                                  child: const Text('ลองอีกครั้ง'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _items.isEmpty
                      ? const Center(
                          child: Text(
                            'ยังไม่มีผลประเมินห้องประชุมในช่วงเวลาที่เลือก',
                          ),
                        )
                      : ListView.separated(
                          itemCount: _items.length,
                          separatorBuilder: (_, _) => const Divider(
                            height: 1,
                            color: LaooColors.border,
                          ),
                          itemBuilder: (_, index) => _item(_items[index]),
                        ),
                ),
              ),
              const SizedBox(height: LaooLayout.listSectionSpacing),
              MeetingPaginationCard(
                total: _total,
                pageIndex: _page - 1,
                pageSize: 20,
                primary: Theme.of(context).colorScheme.primary,
                onPrevious: _page > 1 && !_loading
                    ? () {
                        setState(() => _page--);
                        _load();
                      }
                    : null,
                onNext: _page * 20 < _total && !_loading
                    ? () {
                        setState(() => _page++);
                        _load();
                      }
                    : null,
              ),
            ],
          ),
          if (_message.isNotEmpty)
            Positioned(
              top: 12,
              right: 12,
              child: AutoDismissMessage(
                message: _message,
                error: _messageError,
                onClose: () => setState(() => _message = ''),
              ),
            ),
        ],
      ),
    ),
  );

  Widget _filters() => Wrap(
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
        icon: const Icon(Icons.calendar_today_outlined),
        label: Text('ถึง ${_date(_to)}'),
      ),
      SizedBox(
        width: 280,
        child: TextField(
          controller: _search,
          onSubmitted: (_) {
            setState(() => _page = 1);
            _load();
          },
          decoration: const InputDecoration(
            labelText: 'เลขที่จอง / หัวข้อ / รอบประเมิน',
            prefixIcon: Icon(Icons.search),
          ),
        ),
      ),
      SizedBox(
        width: 220,
        child: DropdownButtonFormField<int?>(
          key: ValueKey('room-${_roomId ?? 'all'}'),
          initialValue: _roomId,
          decoration: const InputDecoration(labelText: 'ห้อง'),
          items: [
            const DropdownMenuItem(value: null, child: Text('ทุกห้อง')),
            ..._rooms.map(
              (room) => DropdownMenuItem(
                value: (room['roomId'] as num).toInt(),
                child: Text('${room['code']} | ${room['name']}'),
              ),
            ),
          ],
          onChanged: (value) => setState(() {
            _roomId = value;
            _page = 1;
          }),
        ),
      ),
      FilledButton.icon(
        onPressed: _loading
            ? null
            : () {
                setState(() => _page = 1);
                _load();
              },
        icon: const Icon(Icons.search),
        label: const Text('ค้นหา'),
      ),
      OutlinedButton.icon(
        onPressed: _loading
            ? null
            : () {
                setState(() {
                  _search.clear();
                  _roomId = null;
                  _page = 1;
                });
                _load();
              },
        icon: const Icon(Icons.clear),
        label: const Text('ล้าง Filter'),
      ),
    ],
  );

  Widget _summaryCards() {
    final cards = [
      ('รอบประเมิน', _number('rounds').toString(), Icons.assignment_outlined),
      ('ผู้มีสิทธิ์ตอบ', _number('eligible').toString(), Icons.groups_outlined),
      ('ตอบแล้ว', _number('submitted').toString(), Icons.fact_check_outlined),
      ('คะแนนเฉลี่ย', _average(), Icons.star_outline),
    ];
    return Wrap(
      spacing: LaooLayout.cardSpacing,
      runSpacing: LaooLayout.cardSpacing,
      children: [
        for (final card in cards)
          SizedBox(
            width: 210,
            child: WorkspaceSectionCard(
              child: Row(
                children: [
                  Icon(card.$3, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(card.$1),
                        Text(
                          card.$2,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _item(Map<String, dynamic> item) {
    final eligible = (item['eligible'] as num?)?.toInt() ?? 0;
    final submitted = (item['submitted'] as num?)?.toInt() ?? 0;
    final rate = eligible == 0 ? 0 : submitted * 100 / eligible;
    return Padding(
      padding: const EdgeInsets.all(LaooLayout.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${item['roundNo']} | ${item['roundName']}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Chip(label: Text(_status(item['status']?.toString()))),
            ],
          ),
          Text('${item['bookingNo']} | ${item['subject']}'),
          Text(
            '${item['roomCode']} | ${item['roomName']} | ${_date(item['meetingDate'])}',
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              Text(
                'ตอบแล้ว $submitted / $eligible คน (${rate.toStringAsFixed(1)}%)',
              ),
              Text('คะแนนเฉลี่ย ${_itemAverage(item)} / 5'),
            ],
          ),
          if (submitted < 5)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text('ซ่อนรายละเอียดผลเพื่อคงความเป็นนิรนาม'),
            ),
        ],
      ),
    );
  }

  int _number(String key) => (_summary[key] as num?)?.toInt() ?? 0;
  String _average() =>
      (_summary['averageRating'] as num?)?.toStringAsFixed(2) ?? '-';
  String _itemAverage(Map<String, dynamic> item) =>
      (item['averageRating'] as num?)?.toStringAsFixed(2) ?? '-';
  String _status(String? value) => switch (value) {
    'DRAFT' => 'ร่าง',
    'PENDING_APPROVAL' => 'รออนุมัติ',
    'PUBLISHED' => 'เผยแพร่แล้ว',
    'CLOSED' => 'ปิดรอบแล้ว',
    _ => value ?? '-',
  };
  String _date(Object? value) {
    final date = value is DateTime ? value : DateTime.tryParse('$value');
    return date == null
        ? '-'
        : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _error(Object error) => error is ApiException
      ? '${error.message}\\nรายละเอียดเพิ่มเติม: ${error.description ?? 'กรุณาโหลดข้อมูลใหม่แล้วลองอีกครั้ง'}'
      : 'ไม่สามารถโหลดผลประเมินได้\\nรายละเอียดเพิ่มเติม: กรุณาตรวจสอบการเชื่อมต่อแล้วลองอีกครั้ง';
}
