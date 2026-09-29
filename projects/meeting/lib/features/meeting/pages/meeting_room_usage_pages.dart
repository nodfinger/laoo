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
import '../widgets/meeting_popup.dart';

enum _UsageMode { usage, utilization, noShow }

class MeetingRoomUsagePage extends StatefulWidget {
  const MeetingRoomUsagePage({super.key}) : mode = _UsageMode.usage;
  const MeetingRoomUsagePage._({super.key, required this.mode});
  final _UsageMode mode;

  @override
  State<MeetingRoomUsagePage> createState() => _MeetingRoomUsagePageState();
}

class MeetingUtilizationReportPage extends MeetingRoomUsagePage {
  const MeetingUtilizationReportPage({super.key})
    : super._(mode: _UsageMode.utilization);
}

class MeetingNoShowReportPage extends MeetingRoomUsagePage {
  const MeetingNoShowReportPage({super.key}) : super._(mode: _UsageMode.noShow);
}

class _MeetingRoomUsagePageState extends State<MeetingRoomUsagePage> {
  final _repo = MeetingRoomUsageRepository();
  final _search = TextEditingController();
  DateTime _from = DateTime.now().subtract(const Duration(days: 30));
  DateTime _to = DateTime.now();
  int? _roomId;
  String? _status;
  int _page = 1, _total = 0;
  bool _loading = true, _working = false, _messageError = false;
  String _caption = '', _message = '';
  List<Map<String, dynamic>> _items = const [], _rooms = const [];
  Map<String, dynamic> _summary = const {};

  String get _menu => switch (widget.mode) {
    _UsageMode.usage => MeetingMenuCodes.roomCheckIn,
    _UsageMode.utilization => MeetingMenuCodes.utilizationReport,
    _UsageMode.noShow => MeetingMenuCodes.noShowReport,
  };
  String get _route => switch (widget.mode) {
    _UsageMode.usage => MeetingRouteNames.roomCheckIn,
    _UsageMode.utilization => MeetingRouteNames.utilizationReport,
    _UsageMode.noShow => MeetingRouteNames.noShowReport,
  };
  String get _fallback => switch (widget.mode) {
    _UsageMode.usage => 'เช็กอินและคืนห้อง',
    _UsageMode.utilization => 'รายงานการใช้ห้อง',
    _UsageMode.noShow => 'รายงาน No-show',
  };

  @override
  void initState() {
    super.initState();
    _caption = _fallback;
    if (widget.mode == _UsageMode.usage) {
      _from = DateTime.now().subtract(const Duration(days: 7));
      _to = DateTime.now().add(const Duration(days: 7));
    }
    _captionLoad();
    _roomsLoad();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _captionLoad() async {
    final value = await NavigationMenuRepository().resolveMenuName(
      menuCode: _menu,
      routeName: _route,
      fallback: _fallback,
    );
    if (mounted) setState(() => _caption = value);
  }

  Future<void> _roomsLoad() async {
    try {
      final value = await _repo.rooms();
      if (mounted) setState(() => _rooms = value);
    } catch (_) {}
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final result = switch (widget.mode) {
        _UsageMode.usage => await _repo.list(
          from: _from,
          to: _to,
          search: _search.text,
          status: _status,
          roomId: _roomId,
          page: _page,
        ),
        _UsageMode.utilization => await _repo.utilization(
          from: _from,
          to: _to,
          roomId: _roomId,
          page: _page,
        ),
        _UsageMode.noShow => await _repo.noShow(
          from: _from,
          to: _to,
          search: _search.text,
          roomId: _roomId,
          page: _page,
        ),
      };
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
    } catch (e) {
      if (mounted) _notify(_error(e, 'ไม่สามารถโหลดข้อมูลได้'), true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _notify(String value, bool error) => setState(() {
    _message = value;
    _messageError = error;
  });

  Future<void> _pick(bool isFrom) async {
    final value = await showDatePicker(
      context: context,
      initialDate: isFrom ? _from : _to,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (value == null) return;
    setState(() {
      if (isFrom) {
        _from = value;
        if (_from.isAfter(_to)) _to = value;
      } else {
        _to = value;
        if (_to.isBefore(_from)) _from = value;
      }
      _page = 1;
    });
  }

  Future<void> _check(Map<String, dynamic> item) async {
    setState(() => _working = true);
    try {
      await _repo.checkIn(
        (item['bookingId'] as num).toInt(),
        (item['slotId'] as num).toInt(),
      );
      _notify('เช็กอินห้องเรียบร้อย', false);
      await _load();
    } catch (e) {
      _notify(_error(e, 'เช็กอินห้องไม่ได้'), true);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _return(Map<String, dynamic> item) async {
    final text = TextEditingController();
    final remark = await showDialog<String>(
      context: context,
      builder: (context) => MeetingPopup(
        title: const MeetingPopupTitle(
          icon: Icons.keyboard_return_outlined,
          text: 'ยืนยันคืนห้อง',
        ),
        content: SizedBox(
          width: 460,
          child: TextField(
            controller: text,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'หมายเหตุการคืนห้อง'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, text.text.trim()),
            child: const Text('ยืนยันคืนห้อง'),
          ),
        ],
      ),
    );
    text.dispose();
    if (remark == null) return;
    setState(() => _working = true);
    try {
      await _repo.returnRoom(
        (item['bookingId'] as num).toInt(),
        (item['slotId'] as num).toInt(),
        remark,
      );
      _notify('คืนห้องเรียบร้อย', false);
      await _load();
    } catch (e) {
      _notify(_error(e, 'คืนห้องไม่ได้'), true);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) => buildMeetingWorkspaceShell(
    pageTitle: _caption,
    activeMenu: _route,
    child: Padding(
      padding: const EdgeInsets.all(LaooLayout.cardMargin),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              WorkspaceSectionCard(
                child: WorkspacePageTitle(title: _caption, favoriteKey: _menu),
              ),
              const SizedBox(height: LaooLayout.listSectionSpacing),
              WorkspaceSectionCard(child: _filters()),
              if (widget.mode != _UsageMode.usage) ...[
                const SizedBox(height: LaooLayout.listSectionSpacing),
                _summaryCards(),
              ],
              const SizedBox(height: LaooLayout.listSectionSpacing),
              Expanded(
                child: WorkspaceSectionCard(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _items.isEmpty
                      ? Center(child: Text('ไม่พบ' + _caption))
                      : ListView.separated(
                          itemCount: _items.length,
                          separatorBuilder: (_, _) => const Divider(
                            height: 1,
                            color: LaooColors.border,
                          ),
                          itemBuilder: (_, i) => _card(_items[i]),
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
        onPressed: () => _pick(true),
        icon: const Icon(Icons.calendar_today_outlined),
        label: Text('จาก ' + _date(_from)),
      ),
      OutlinedButton.icon(
        onPressed: () => _pick(false),
        icon: const Icon(Icons.calendar_today_outlined),
        label: Text('ถึง ' + _date(_to)),
      ),
      if (widget.mode != _UsageMode.utilization)
        SizedBox(
          width: 270,
          child: TextField(
            controller: _search,
            onSubmitted: (_) {
              setState(() => _page = 1);
              _load();
            },
            decoration: const InputDecoration(
              labelText: 'เลขที่จอง / หัวข้อ / ผู้เข้าร่วม',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
      SizedBox(
        width: 220,
        child: DropdownButtonFormField<int?>(
          value: _roomId,
          decoration: const InputDecoration(labelText: 'ห้อง'),
          items: [
            const DropdownMenuItem(value: null, child: Text('ทุกห้อง')),
            ..._rooms.map(
              (x) => DropdownMenuItem(
                value: (x['roomId'] as num).toInt(),
                child: Text(
                  x['code'].toString() + ' | ' + x['name'].toString(),
                ),
              ),
            ),
          ],
          onChanged: (v) => setState(() {
            _roomId = v;
            _page = 1;
          }),
        ),
      ),
      if (widget.mode == _UsageMode.usage)
        SizedBox(
          width: 190,
          child: DropdownButtonFormField<String?>(
            value: _status,
            decoration: const InputDecoration(labelText: 'สถานะ'),
            items: const [
              DropdownMenuItem(value: null, child: Text('ทั้งหมด')),
              DropdownMenuItem(value: 'WAITING', child: Text('ยังไม่ถึงเวลา')),
              DropdownMenuItem(value: 'READY', child: Text('รอเช็กอิน')),
              DropdownMenuItem(value: 'IN_USE', child: Text('กำลังใช้งาน')),
              DropdownMenuItem(value: 'RETURNED', child: Text('คืนห้องแล้ว')),
              DropdownMenuItem(value: 'EXPIRED', child: Text('หมดเวลา')),
            ],
            onChanged: (v) => setState(() {
              _status = v;
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
                  _status = null;
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
    final cards = widget.mode == _UsageMode.utilization
        ? [
            ('รอบการจอง', _number('bookingSlots')),
            ('ชั่วโมงตามจอง', _hours('scheduledMinutes')),
            ('เช็กอินห้อง', _number('checkedIn')),
            ('คืนห้องแล้ว', _number('returned')),
          ]
        : [
            ('ตอบรับเข้าร่วม', _number('accepted')),
            ('No-show', _number('noShow')),
            ('อัตรา No-show', _rate()),
          ];
    return Wrap(
      spacing: LaooLayout.cardSpacing,
      runSpacing: LaooLayout.cardSpacing,
      children: [
        for (final c in cards)
          SizedBox(
            width: 210,
            child: WorkspaceSectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.$1),
                  Text(
                    c.$2.toString(),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _card(Map<String, dynamic> item) => Padding(
    padding: const EdgeInsets.all(LaooLayout.cardPadding),
    child: switch (widget.mode) {
      _UsageMode.usage => _usage(item),
      _UsageMode.utilization => _utilization(item),
      _UsageMode.noShow => _noShow(item),
    },
  );
  Widget _usage(Map<String, dynamic> x) {
    final state = x['status'].toString();
    final allowed = x['canManage'] == true && !_working;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                x['bookingNo'].toString() + ' | ' + x['subject'].toString(),
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            Chip(label: Text(_state(state))),
          ],
        ),
        Text(x['roomCode'].toString() + ' | ' + x['roomName'].toString()),
        Text(
          _dateTime(x['startDateTime']) + ' – ' + _dateTime(x['endDateTime']),
        ),
        if (x['checkInDate'] != null)
          Text('เช็กอินห้อง: ' + _dateTime(x['checkInDate'])),
        if (x['returnDate'] != null)
          Text('คืนห้อง: ' + _dateTime(x['returnDate'])),
        if ((x['returnRemark'] ?? '').toString().isNotEmpty)
          Text('หมายเหตุ: ' + x['returnRemark'].toString()),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            if (state == 'READY' && allowed)
              FilledButton.icon(
                onPressed: () => _check(x),
                icon: const Icon(Icons.login_outlined),
                label: const Text('เช็กอินเข้าห้อง'),
              ),
            if (state == 'IN_USE' && allowed)
              FilledButton.icon(
                onPressed: () => _return(x),
                icon: const Icon(Icons.keyboard_return_outlined),
                label: const Text('คืนห้อง'),
              ),
          ],
        ),
      ],
    );
  }

  Widget _utilization(Map<String, dynamic> x) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        _date(x['date']) +
            ' | ' +
            x['roomCode'].toString() +
            ' ' +
            x['roomName'].toString(),
        style: Theme.of(context).textTheme.titleSmall,
      ),
      Text(
        'รอบจอง ' +
            x['bookingSlots'].toString() +
            ' รอบ | เวลาตามจอง ' +
            _mins(x['scheduledMinutes']),
      ),
      Text(
        'เช็กอิน ' +
            x['checkedIn'].toString() +
            ' รอบ | คืนห้อง ' +
            x['returned'].toString() +
            ' รอบ | ใช้จริง ' +
            _mins(x['actualMinutes']),
      ),
    ],
  );
  Widget _noShow(Map<String, dynamic> x) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        x['name'].toString() + ' | ' + (x['employeeCode'] ?? '-').toString(),
        style: Theme.of(context).textTheme.titleSmall,
      ),
      Text('แผนก: ' + (x['department'] ?? '-').toString()),
      Text(x['bookingNo'].toString() + ' | ' + x['subject'].toString()),
      Text(
        x['roomCode'].toString() +
            ' | ' +
            x['roomName'].toString() +
            ' | ' +
            _dateTime(x['startDateTime']),
      ),
      const Text('สถานะ: No-show'),
    ],
  );
  int _number(String key) => (_summary[key] as num?)?.toInt() ?? 0;
  String _hours(String key) => _mins(_summary[key]);
  String _mins(Object? x) =>
      (((x as num?)?.toInt() ?? 0) / 60).toStringAsFixed(1) + ' ชม.';
  String _rate() {
    final all = _number('accepted');
    return all == 0
        ? '0%'
        : (_number('noShow') * 100 / all).toStringAsFixed(1) + '%';
  }

  String _state(String x) => switch (x) {
    'WAITING' => 'ยังไม่ถึงเวลา',
    'READY' => 'รอเช็กอิน',
    'IN_USE' => 'กำลังใช้งาน',
    'RETURNED' => 'คืนห้องแล้ว',
    'EXPIRED' => 'หมดเวลา',
    _ => x,
  };
  String _date(Object? x) {
    final d = x is DateTime ? x : DateTime.tryParse(x.toString());
    return d == null
        ? '-'
        : d.day.toString().padLeft(2, '0') +
              '/' +
              d.month.toString().padLeft(2, '0') +
              '/' +
              d.year.toString();
  }

  String _dateTime(Object? x) {
    final d = x is DateTime ? x : DateTime.tryParse(x.toString());
    return d == null
        ? '-'
        : _date(d) +
              ' ' +
              d.hour.toString().padLeft(2, '0') +
              ':' +
              d.minute.toString().padLeft(2, '0');
  }

  String _error(Object e, String fallback) => e is ApiException
      ? e.message +
            '\nรายละเอียดเพิ่มเติม: ' +
            (e.description ?? 'กรุณาโหลดข้อมูลล่าสุดแล้วลองอีกครั้ง')
      : fallback +
            '\nรายละเอียดเพิ่มเติม: กรุณาตรวจสอบการเชื่อมต่อแล้วลองอีกครั้ง';
}
