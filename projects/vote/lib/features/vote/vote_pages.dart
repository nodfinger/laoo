import 'package:flutter/material.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'vote_feature_host.dart';
import 'vote_ui.dart';

class VotePage extends StatefulWidget {
  const VotePage(this.kind, {super.key});
  final String kind;
  @override
  State<VotePage> createState() => _VotePageState();
}

class _VotePageState extends State<VotePage> {
  late final JsonApiClient api = createVoteApiClient();
  late Future<dynamic> future;
  final _searchController = TextEditingController();
  String _appliedSearch = '';
  String _status = '';
  int _page = 1;
  static const int _pageSize = 20;
  bool _cardMode = false;
  @override
  void initState() {
    super.initState();
    future = _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    disposeVoteApiClient(api);
    super.dispose();
  }

  Future<dynamic> _load() {
    final query = <String, String>{
      if (_appliedSearch.isNotEmpty) 'search': _appliedSearch,
      if (_status.isNotEmpty) 'status': _status,
      'page': '$_page',
      'pageSize': '$_pageSize',
    };
    String path(String route) =>
        Uri(path: route, queryParameters: query).toString();
    if (widget.kind == 'results') {
      return Future.wait([
        api.get('/api/company/votes/results/dashboard'),
        api.get(path('/api/company/votes/results')),
      ]);
    }
    if (widget.kind == 'topics') {
      return Future.wait([
        api.get(path('/api/company/votes')),
        api.get('/api/company/votes/actions'),
      ]);
    }
    if (widget.kind == 'approvals') {
      return api.get(path('/api/company/votes/approvals'));
    }
    return api.get(switch (widget.kind) {
      'settings' => '/api/company/votes/settings',
      'topics' => '/api/company/votes',
      'approvals' => '/api/company/votes/approvals',
      'mine' => '/api/company/votes/mine',
      _ => '/api/company/votes/results/dashboard',
    });
  }

  String get title => switch (widget.kind) {
    'settings' => 'ตั้งค่าระบบโหวต',
    'topics' => 'หัวข้อโหวต',
    'approvals' => 'กล่องอนุมัติหัวข้อโหวต',
    'mine' => 'โหวตของฉัน',
    _ => 'ผลและรายงานการโหวต',
  };
  void reload() => setState(() {
    future = _load();
  });

  void _search() {
    _appliedSearch = _searchController.text.trim();
    _page = 1;
    reload();
  }

  void _clearFilters() {
    _searchController.clear();
    _appliedSearch = '';
    _status = '';
    _page = 1;
    reload();
  }

  void _changePage(int page) {
    _page = page;
    reload();
  }

  String get menuCode => switch (widget.kind) {
    'settings' => '44001',
    'topics' => '44002',
    'approvals' => '44003',
    'mine' => '44004',
    _ => '44005',
  };

  @override
  Widget build(BuildContext context) => buildVoteWorkspaceShell(
    pageTitle: title,
    activeMenu: menuCode,
    child: FutureBuilder<dynamic>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return VotePageLayout(
            title: title,
            menuCode: menuCode,
            content: const VoteEmptyCard(message: 'กำลังโหลดข้อมูล...'),
          );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return VotePageLayout(
            title: title,
            menuCode: menuCode,
            content: VoteEmptyCard(
              message:
                  'ไม่สามารถโหลดข้อมูลได้\nรายละเอียดเพิ่มเติม: กรุณาตรวจสอบการเชื่อมต่อหรือสิทธิ์ใช้งาน แล้วลองอีกครั้ง',
              onRetry: reload,
            ),
          );
        }
        return _loaded(context, snapshot.data);
      },
    ),
  );

  Widget _loaded(BuildContext contentContext, dynamic data) {
    if (widget.kind == 'settings') {
      return VotePageLayout(
        title: title,
        menuCode: menuCode,
        content: _settings(
          contentContext,
          Map<String, dynamic>.from(data as Map),
        ),
      );
    }

    Map<String, dynamic> payload;
    Map<String, dynamic> actions = const <String, dynamic>{};
    Widget? summary;
    if (widget.kind == 'topics') {
      final values = data as List;
      payload = Map<String, dynamic>.from(values[0] as Map);
      actions = Map<String, dynamic>.from(values[1] as Map);
    } else if (widget.kind == 'results') {
      final values = data as List;
      summary = _dashboard(Map<String, dynamic>.from(values[0] as Map));
      payload = Map<String, dynamic>.from(values[1] as Map);
    } else {
      payload = Map<String, dynamic>.from(data as Map);
    }

    var items = (payload['items'] as List? ?? const <dynamic>[])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    var total = (payload['total'] as num?)?.toInt() ?? items.length;
    var currentPage = (payload['page'] as num?)?.toInt() ?? _page;
    var pageSize = (payload['pageSize'] as num?)?.toInt() ?? _pageSize;

    if (widget.kind == 'mine') {
      final term = _appliedSearch.toLowerCase();
      items = items.where((item) {
        final matchesSearch =
            term.isEmpty ||
            '${item['voteNo']} ${item['name']} ${item['description'] ?? ''}'
                .toLowerCase()
                .contains(term);
        final voted = item['votedAt'] != null;
        final matchesStatus =
            _status.isEmpty ||
            (_status == 'VOTED' && voted) ||
            (_status == 'PENDING' && !voted);
        return matchesSearch && matchesStatus;
      }).toList();
      total = items.length;
      currentPage = _page;
      pageSize = _pageSize;
      final start = ((_page - 1) * _pageSize).clamp(0, items.length);
      final end = (start + _pageSize).clamp(0, items.length);
      items = items.sublist(start, end);
    }

    final createButton = widget.kind == 'topics' && actions['create'] == true
        ? FilledButton.icon(
            style: voteFilledButtonStyle(context),
            onPressed: _create,
            icon: const Icon(Icons.add),
            label: const Text('เพิ่ม'),
          )
        : null;

    return VotePageLayout(
      title: title,
      menuCode: menuCode,
      summary: summary,
      filter: _filterBar(),
      primaryAction: createButton,
      cardMode: _cardMode,
      onToggleMode: () => setState(() => _cardMode = !_cardMode),
      content: _resultContent(items, actions),
      pagination: VotePaginationCard(
        page: currentPage,
        pageSize: pageSize,
        total: total,
        onChanged: _changePage,
      ),
    );
  }

  Widget _filterBar() {
    if (widget.kind == 'approvals') {
      return Text(
        'สถานะ: รออนุมัติ',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: VoteUiTokens.bodyFontSize,
        ),
      );
    }
    final items = switch (widget.kind) {
      'mine' => const <DropdownMenuItem<String>>[
        DropdownMenuItem(value: '', child: Text('ทั้งหมด')),
        DropdownMenuItem(value: 'PENDING', child: Text('รอลงคะแนน')),
        DropdownMenuItem(value: 'VOTED', child: Text('ลงคะแนนแล้ว')),
      ],
      'results' => const <DropdownMenuItem<String>>[
        DropdownMenuItem(value: '', child: Text('ทั้งหมด')),
        DropdownMenuItem(value: 'PUBLISHED', child: Text('เปิดโหวต')),
        DropdownMenuItem(value: 'CLOSED', child: Text('ปิดแล้ว')),
      ],
      _ => const <DropdownMenuItem<String>>[
        DropdownMenuItem(value: '', child: Text('ทั้งหมด')),
        DropdownMenuItem(value: 'DRAFT', child: Text('ร่าง')),
        DropdownMenuItem(value: 'PENDING_APPROVAL', child: Text('รออนุมัติ')),
        DropdownMenuItem(value: 'APPROVED', child: Text('อนุมัติแล้ว')),
        DropdownMenuItem(value: 'PUBLISHED', child: Text('เผยแพร่แล้ว')),
        DropdownMenuItem(value: 'CLOSED', child: Text('ปิดแล้ว')),
      ],
    };
    return VoteFilterBar(
      searchController: _searchController,
      status: _status,
      statusItems: items,
      onStatusChanged: (value) {
        _status = value ?? '';
        _page = 1;
        reload();
      },
      onSearch: _search,
      onClear: _clearFilters,
    );
  }

  Widget _resultContent(
    List<Map<String, dynamic>> items,
    Map<String, dynamic> actions,
  ) => LayoutBuilder(
    builder: (context, constraints) {
      final cards = VoteCardList(
        children: items.map((item) => _recordCard(item, actions)).toList(),
      );
      if (_cardMode || constraints.maxWidth < VoteUiTokens.breakpoint) {
        return cards;
      }
      return _table(items, actions);
    },
  );

  Widget _recordCard(Map<String, dynamic> item, Map<String, dynamic> actions) {
    final status = widget.kind == 'mine'
        ? (item['votedAt'] == null ? 'รอลงคะแนน' : 'ลงคะแนนแล้ว')
        : '${item['status'] ?? 'PENDING_APPROVAL'}';
    final meta = switch (widget.kind) {
      'approvals' =>
        'เปิด ${_date(item['openAt'])} · ปิด ${_date(item['closeAt'])}',
      'mine' => '${item['description'] ?? ''} · ปิด ${_date(item['closeAt'])}',
      'results' =>
        'โหวตแล้ว ${item['voted'] ?? 0}/${item['eligible'] ?? 0} คน · $status',
      _ =>
        '$status · โหวตแล้ว ${item['voted'] ?? 0}/${item['eligible'] ?? 0} คน',
    };
    return VoteRecordCard(
      title: '${item['voteNo'] ?? '-'}',
      subtitle: '${item['name'] ?? '-'}',
      meta: meta,
      onTap: widget.kind == 'topics'
          ? () => _view(item['id'])
          : widget.kind == 'results' && status == 'CLOSED'
          ? () => _viewResult(item['id'])
          : null,
      trailing: _action(item, actions),
    );
  }

  Widget _table(
    List<Map<String, dynamic>> items,
    Map<String, dynamic> actions,
  ) {
    final columns = switch (widget.kind) {
      'approvals' => const [
        DataColumn(label: Text('Action')),
        DataColumn(label: Text('เลขที่')),
        DataColumn(label: Text('หัวข้อ')),
        DataColumn(label: Text('เปิด')),
        DataColumn(label: Text('ปิด')),
      ],
      'mine' => const [
        DataColumn(label: Text('Action')),
        DataColumn(label: Text('เลขที่')),
        DataColumn(label: Text('หัวข้อ')),
        DataColumn(label: Text('ปิด')),
        DataColumn(label: Text('สถานะ')),
      ],
      _ => const [
        DataColumn(label: Text('Action')),
        DataColumn(label: Text('เลขที่')),
        DataColumn(label: Text('หัวข้อ')),
        DataColumn(label: Text('สถานะ')),
        DataColumn(label: Text('ผู้มีสิทธิ์')),
        DataColumn(label: Text('โหวตแล้ว')),
      ],
    };
    return VoteTableCard(
      columns: columns,
      rows: items.map((item) {
        final status = widget.kind == 'mine'
            ? (item['votedAt'] == null ? 'รอลงคะแนน' : 'ลงคะแนนแล้ว')
            : '${item['status'] ?? 'PENDING_APPROVAL'}';
        final cells = switch (widget.kind) {
          'approvals' => [
            DataCell(_action(item, actions) ?? const SizedBox.shrink()),
            DataCell(Text('${item['voteNo'] ?? '-'}')),
            DataCell(Text('${item['name'] ?? '-'}')),
            DataCell(Text(_date(item['openAt']))),
            DataCell(Text(_date(item['closeAt']))),
          ],
          'mine' => [
            DataCell(_action(item, actions) ?? const SizedBox.shrink()),
            DataCell(Text('${item['voteNo'] ?? '-'}')),
            DataCell(Text('${item['name'] ?? '-'}')),
            DataCell(Text(_date(item['closeAt']))),
            DataCell(VoteStatusLabel(status)),
          ],
          _ => [
            DataCell(
              _action(item, actions) ??
                  (widget.kind == 'results' && status == 'CLOSED'
                      ? IconButton(
                          tooltip: 'ดูผล',
                          onPressed: () => _viewResult(item['id']),
                          icon: const Icon(Icons.visibility_outlined),
                        )
                      : const SizedBox.shrink()),
            ),
            DataCell(Text('${item['voteNo'] ?? '-'}')),
            DataCell(Text('${item['name'] ?? '-'}')),
            DataCell(VoteStatusLabel(status)),
            DataCell(Text('${item['eligible'] ?? 0}')),
            DataCell(Text('${item['voted'] ?? 0}')),
          ],
        };
        return DataRow(cells: cells);
      }).toList(),
    );
  }

  String _date(dynamic value) {
    final text = '${value ?? '-'}';
    return text.length >= 16
        ? text.substring(0, 16).replaceFirst('T', ' ')
        : text;
  }

  Widget _settings(BuildContext context, Map x) {
    final theme = Theme.of(context);
    return Card(
      color: theme.cardTheme.color ?? theme.colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: voteShape(),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ค่าการทำงานปัจจุบัน',
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: VoteUiTokens.sectionFontSize,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Divider(height: 1, color: theme.dividerColor),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'เปิดใช้งานระบบโหวต',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: VoteUiTokens.bodyFontSize,
                    ),
                  ),
                ),
                VoteStatusLabel(
                  (x['isEnabled'] ?? true) ? 'เปิดใช้งาน' : 'ปิดใช้งาน',
                ),
              ],
            ),
            const SizedBox(height: VoteUiTokens.fieldGap),
            Text(
              'ระยะเวลาเปิดโหวตเริ่มต้น: ${x['defaultOpenHours'] ?? 72} ชั่วโมง',
              style: const TextStyle(fontSize: VoteUiTokens.bodyFontSize),
            ),
            const SizedBox(height: VoteUiTokens.fieldGap),
            Text(
              'ผู้อนุมัติเริ่มต้น: ${x['defaultApproverUserId'] ?? 'ไม่กำหนด'}',
              style: const TextStyle(fontSize: VoteUiTokens.bodyFontSize),
            ),
            const SizedBox(height: VoteUiTokens.fieldGap),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                style: voteFilledButtonStyle(context),
                onPressed: () => _editSettings(x),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('แก้ไขการตั้งค่า'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editSettings(Map settings) async {
    var enabled = settings['isEnabled'] ?? true;
    final hours = TextEditingController(
      text: '${settings['defaultOpenHours'] ?? 72}',
    );
    final approver = TextEditingController(
      text: '${settings['defaultApproverUserId'] ?? ''}',
    );
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => VoteDialogFrame(
          title: 'ตั้งค่าระบบโหวต > แก้ไข',
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('เปิดใช้งานระบบ'),
                value: enabled,
                onChanged: (v) => setDialogState(() => enabled = v),
              ),
              const SizedBox(height: VoteUiTokens.fieldGap),
              TextField(
                controller: hours,
                keyboardType: TextInputType.number,
                decoration: voteInputDecoration(
                  context,
                  'ระยะเวลาเปิดโหวตเริ่มต้น (ชั่วโมง) *',
                ),
              ),
              const SizedBox(height: VoteUiTokens.fieldGap),
              TextField(
                controller: approver,
                keyboardType: TextInputType.number,
                decoration: voteInputDecoration(
                  context,
                  'รหัสผู้อนุมัติเริ่มต้น (ไม่บังคับ)',
                ),
              ),
            ],
          ),
          actions: [
            OutlinedButton(
              style: voteOutlinedButtonStyle(context),
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              style: voteFilledButtonStyle(context),
              onPressed: () async {
                final defaultHours = int.tryParse(hours.text.trim());
                if (defaultHours == null || defaultHours < 1) return;
                await api.put(
                  '/api/company/votes/settings',
                  body: {
                    'isEnabled': enabled,
                    'defaultOpenHours': defaultHours,
                    'defaultApproverUserId': approver.text.trim().isEmpty
                        ? null
                        : int.tryParse(approver.text.trim()),
                  },
                );
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                reload();
              },
              child: const Text('บันทึก'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _viewResult(Object id) async {
    final value = Map<String, dynamic>.from(
      await api.get('/api/company/votes/results/$id') as Map,
    );
    if (!mounted) return;
    final topicGroup = Map<String, dynamic>.from(value['topic'] as Map);
    final topic = Map<String, dynamic>.from(topicGroup['topic'] as Map);
    final options = value['options'] as List? ?? const [];
    final votes = options.fold<int>(
      0,
      (total, row) => total + ((row as Map)['votes'] as num).toInt(),
    );
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => VoteDialogFrame(
        title: 'ผลโหวต > ${topic['name']}',
        icon: Icons.bar_chart_outlined,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('จำนวนคะแนนทั้งหมด $votes เสียง'),
            const SizedBox(height: 12),
            Divider(height: 1, color: Theme.of(context).dividerColor),
            for (final option in options)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${option['text']}'),
                trailing: Text('${option['votes']} เสียง'),
              ),
          ],
        ),
        actions: [
          OutlinedButton(
            style: voteOutlinedButtonStyle(context),
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('ปิด'),
          ),
        ],
      ),
    );
  }

  Widget _dashboard(Map x) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.surface,
      surfaceTintColor: theme.colorScheme.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: voteShape(),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 24,
          runSpacing: 16,
          children: [
            for (final entry in {
              'หัวข้อเปิด': x['open'],
              'ปิดแล้ว': x['closed'],
              'รออนุมัติ': x['pendingApproval'],
              'ผู้มีสิทธิ์': x['eligible'],
              'อัตราโหวต': '${x['turnout'] ?? 0}%',
            }.entries)
              SizedBox(
                width: 160,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.key,
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: VoteUiTokens.bodyFontSize,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${entry.value}',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontSize: VoteUiTokens.metricFontSize,
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
  }

  Widget? _action(Map x, Map<String, dynamic> actions) {
    if (widget.kind == 'topics') {
      final status = '${x['status'] ?? ''}';
      final entries = <PopupMenuEntry<String>>[];
      if ((status == 'DRAFT' || status == 'RETURNED') &&
          actions['submit'] == true) {
        if (actions['edit'] == true) {
          entries.add(const PopupMenuItem(value: 'edit', child: Text('แก้ไข')));
        }
        if (actions['delete'] == true) {
          entries.add(const PopupMenuItem(value: 'delete', child: Text('ลบ')));
        }
        entries.add(
          const PopupMenuItem(value: 'submit', child: Text('ส่งอนุมัติ')),
        );
      }
      if (status == 'APPROVED' && actions['publish'] == true) {
        entries.add(
          const PopupMenuItem(value: 'publish', child: Text('เผยแพร่')),
        );
      }
      if (status == 'PUBLISHED' && actions['close'] == true) {
        entries.add(
          const PopupMenuItem(value: 'close', child: Text('ปิดโหวต')),
        );
      }
      if (entries.isEmpty) return null;
      return PopupMenuButton<String>(
        onSelected: (v) async {
          if (v == 'edit') return _edit(x['id']);
          if (v == 'delete') return _delete(x);
          await api.post('/api/company/votes/${x['id']}/$v');
          reload();
        },
        itemBuilder: (_) => entries,
      );
    }
    if (widget.kind == 'approvals') {
      return PopupMenuButton<String>(
        onSelected: (action) async {
          if (action == 'RETURN') return _returnApproval(x['id']);
          await api.post(
            '/api/company/votes/${x['id']}/approval',
            body: {'action': 'APPROVE'},
          );
          reload();
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'APPROVE', child: Text('อนุมัติ')),
          PopupMenuItem(value: 'RETURN', child: Text('ส่งกลับแก้ไข')),
        ],
      );
    }
    if (widget.kind == 'mine' && x['votedAt'] == null) {
      return FilledButton(
        style: voteFilledButtonStyle(context),
        onPressed: () => _vote(x['id']),
        child: const Text('ลงคะแนน'),
      );
    }
    return null;
  }

  Future<void> _returnApproval(Object id) async {
    final remark = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => VoteDialogFrame(
        title: 'กล่องอนุมัติหัวข้อโหวต > ส่งกลับแก้ไข',
        icon: Icons.undo_outlined,
        content: TextField(
          controller: remark,
          maxLines: 3,
          decoration: voteInputDecoration(context, 'เหตุผลที่ต้องแก้ไข *'),
        ),
        actions: [
          OutlinedButton(
            style: voteOutlinedButtonStyle(context),
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            style: voteFilledButtonStyle(context),
            onPressed: () async {
              if (remark.text.trim().isEmpty) return;
              await api.post(
                '/api/company/votes/$id/approval',
                body: {'action': 'RETURN', 'remark': remark.text.trim()},
              );
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              reload();
            },
            child: const Text('ส่งกลับแก้ไข'),
          ),
        ],
      ),
    );
  }

  Future<void> _vote(Object id) async {
    final detail = Map<String, dynamic>.from(
      await api.get('/api/company/votes/mine/$id') as Map,
    );
    final options = detail['options'] as List? ?? [];
    if (!mounted || options.isEmpty) return;
    Map<String, dynamic> selected = Map<String, dynamic>.from(
      options.first as Map,
    );
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => VoteDialogFrame(
          title: 'โหวตของฉัน > เลือกตัวเลือก',
          icon: Icons.how_to_vote_outlined,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RadioGroup<Map<String, dynamic>>(
                groupValue: selected,
                onChanged: (value) => setDialogState(() {
                  if (value != null) {
                    selected = value;
                  }
                }),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final option in options)
                      RadioListTile<Map<String, dynamic>>(
                        contentPadding: EdgeInsets.zero,
                        value: Map<String, dynamic>.from(option as Map),
                        title: Text('${option['text']}'),
                      ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            OutlinedButton(
              style: voteOutlinedButtonStyle(context),
              onPressed: () => Navigator.pop(context),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              style: voteFilledButtonStyle(context),
              onPressed: () async {
                await api.post(
                  '/api/company/votes/mine/$id/vote',
                  body: {'optionId': selected['id']},
                );
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                reload();
              },
              child: const Text('ยืนยันการโหวต'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _create() async {
    final name = TextEditingController();
    final a = TextEditingController();
    final b = TextEditingController();
    var targetMode = 'ALL';
    var targets = <Map<String, dynamic>>[];
    await showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (context, setDialogState) => VoteDialogFrame(
          title: 'หัวข้อโหวต > เพิ่ม',
          maxWidth: VoteUiTokens.popupWideWidth,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'ข้อมูลหัวข้อ',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: name,
                decoration: voteInputDecoration(context, 'ชื่อหัวข้อ *'),
              ),
              const SizedBox(height: VoteUiTokens.fieldGap),
              Text('ตัวเลือก', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              TextField(
                controller: a,
                decoration: voteInputDecoration(context, 'ตัวเลือก 1 *'),
              ),
              const SizedBox(height: VoteUiTokens.fieldGap),
              TextField(
                controller: b,
                decoration: voteInputDecoration(context, 'ตัวเลือก 2 *'),
              ),
              const SizedBox(height: VoteUiTokens.fieldGap),
              DropdownButtonFormField<String>(
                initialValue: targetMode,
                decoration: voteInputDecoration(context, 'ผู้มีสิทธิ์โหวต'),
                items: const [
                  DropdownMenuItem(
                    value: 'ALL',
                    child: Text('พนักงาน active ทั้งหมด'),
                  ),
                  DropdownMenuItem(
                    value: 'CUSTOM',
                    child: Text('กำหนดแผนก/พนักงาน'),
                  ),
                ],
                onChanged: (v) => setDialogState(() => targetMode = v ?? 'ALL'),
              ),
              if (targetMode == 'CUSTOM') ...[
                const SizedBox(height: VoteUiTokens.fieldGap),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    style: voteOutlinedButtonStyle(context),
                    onPressed: () async {
                      final selected = await _pickTargets(targets);
                      if (selected != null) {
                        setDialogState(() => targets = selected);
                      }
                    },
                    icon: const Icon(Icons.group_add),
                    label: Text(
                      targets.isEmpty
                          ? 'เลือกแผนกหรือพนักงาน'
                          : 'เลือกแล้ว ${targets.length} รายการ',
                    ),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            OutlinedButton(
              style: voteOutlinedButtonStyle(context),
              onPressed: () => Navigator.pop(c),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              style: voteFilledButtonStyle(context),
              onPressed: () async {
                final now = DateTime.now().toUtc();
                await api.post(
                  '/api/company/votes',
                  body: {
                    'name': name.text,
                    'targetMode': targetMode,
                    'identityMode': 'ANONYMOUS',
                    'openAt': now
                        .add(const Duration(hours: 1))
                        .toIso8601String(),
                    'closeAt': now
                        .add(const Duration(hours: 73))
                        .toIso8601String(),
                    'options': [a.text, b.text],
                    'targets': targets,
                  },
                );
                if (c.mounted) Navigator.pop(c);
                reload();
              },
              child: const Text('บันทึก'),
            ),
          ],
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>?> _pickTargets(
    List<Map<String, dynamic>> initial,
  ) async {
    final data = Map<String, dynamic>.from(
      await api.get('/api/company/votes/target-options') as Map,
    );
    if (!mounted) return null;
    final departments = data['departments'] as List? ?? const [];
    final employees = data['employees'] as List? ?? const [];
    final selected = <String, Map<String, dynamic>>{
      for (final item in initial) '${item['type']}:${item['id']}': item,
    };
    return showDialog<List<Map<String, dynamic>>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => VoteDialogFrame(
          title: 'หัวข้อโหวต > เลือกผู้มีสิทธิ์',
          icon: Icons.group_add_outlined,
          maxWidth: VoteUiTokens.popupWideWidth,
          content: SizedBox(
            height: 420,
            child: ListView(
              children: [
                const Text('แผนก'),
                for (final item in departments)
                  CheckboxListTile(
                    value: selected.containsKey('DEPARTMENT:${item['id']}'),
                    title: Text('${item['name']}'),
                    onChanged: (checked) => setDialogState(() {
                      final key = 'DEPARTMENT:${item['id']}';
                      if (checked == true) {
                        selected[key] = {
                          'type': 'DEPARTMENT',
                          'id': item['id'],
                        };
                      } else {
                        selected.remove(key);
                      }
                    }),
                  ),
                const Divider(),
                const Text('พนักงาน'),
                for (final item in employees)
                  CheckboxListTile(
                    value: selected.containsKey('EMPLOYEE:${item['id']}'),
                    title: Text('${item['code']} | ${item['name']}'),
                    onChanged: (checked) => setDialogState(() {
                      final key = 'EMPLOYEE:${item['id']}';
                      if (checked == true) {
                        selected[key] = {'type': 'EMPLOYEE', 'id': item['id']};
                      } else {
                        selected.remove(key);
                      }
                    }),
                  ),
              ],
            ),
          ),
          actions: [
            OutlinedButton(
              style: voteOutlinedButtonStyle(context),
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              style: voteFilledButtonStyle(context),
              onPressed: () =>
                  Navigator.pop(dialogContext, selected.values.toList()),
              child: const Text('ใช้รายชื่อที่เลือก'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _edit(Object id) async {
    final value = Map<String, dynamic>.from(
      await api.get('/api/company/votes/$id') as Map,
    );
    if (!mounted) return;
    final topic = Map<String, dynamic>.from(value['topic'] as Map);
    final options = value['options'] as List? ?? const [];
    final name = TextEditingController(text: '${topic['name'] ?? ''}');
    final description = TextEditingController(
      text: '${topic['description'] ?? ''}',
    );
    final a = TextEditingController(
      text: options.isNotEmpty ? '${(options[0] as Map)['text']}' : '',
    );
    final b = TextEditingController(
      text: options.length > 1 ? '${(options[1] as Map)['text']}' : '',
    );
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => VoteDialogFrame(
        title: 'หัวข้อโหวต > แก้ไข',
        maxWidth: VoteUiTokens.popupWideWidth,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'ข้อมูลหัวข้อ',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: name,
              decoration: voteInputDecoration(context, 'ชื่อหัวข้อ *'),
            ),
            const SizedBox(height: VoteUiTokens.fieldGap),
            TextField(
              controller: description,
              maxLines: 2,
              decoration: voteInputDecoration(context, 'รายละเอียด'),
            ),
            const SizedBox(height: VoteUiTokens.fieldGap),
            Text('ตัวเลือก', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextField(
              controller: a,
              decoration: voteInputDecoration(context, 'ตัวเลือก 1 *'),
            ),
            const SizedBox(height: VoteUiTokens.fieldGap),
            TextField(
              controller: b,
              decoration: voteInputDecoration(context, 'ตัวเลือก 2 *'),
            ),
          ],
        ),
        actions: [
          OutlinedButton(
            style: voteOutlinedButtonStyle(context),
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            style: voteFilledButtonStyle(context),
            onPressed: () async {
              await api.put(
                '/api/company/votes/$id',
                body: {
                  'name': name.text,
                  'description': description.text,
                  'targetMode': topic['targetMode'],
                  'identityMode': topic['identityMode'],
                  'openAt': topic['openAt'],
                  'closeAt': topic['closeAt'],
                  'options': [a.text, b.text],
                  'targets': value['targets'] ?? const [],
                },
              );
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              reload();
            },
            child: const Text('บันทึก'),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(Map x) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final error = Theme.of(context).colorScheme.error;
        return VoteDialogFrame(
          title: 'ยืนยันการลบข้อมูล',
          icon: Icons.delete_outline,
          iconColor: error,
          isDestructive: true,
          content: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: error.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(VoteUiTokens.radius),
            ),
            child: Text(
              '${x['voteNo']} | ${x['name']}\nข้อมูลที่ลบแล้วไม่สามารถเรียกคืนได้',
            ),
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.primary,
              ),
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('ยกเลิก'),
            ),
            FilledButton.icon(
              style: voteFilledButtonStyle(context).copyWith(
                backgroundColor: WidgetStatePropertyAll(error),
                foregroundColor: WidgetStatePropertyAll(
                  Theme.of(context).colorScheme.onError,
                ),
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.delete_outline),
              label: const Text('ลบ'),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      await api.delete('/api/company/votes/${x['id']}');
      reload();
    }
  }

  Future<void> _view(Object id) async {
    final value = Map<String, dynamic>.from(
      await api.get('/api/company/votes/$id') as Map,
    );
    if (!mounted) return;
    final topic = Map<String, dynamic>.from(value['topic'] as Map);
    final options = value['options'] as List? ?? [];
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => VoteDialogFrame(
        title: 'หัวข้อโหวต > ดูรายการ',
        icon: Icons.visibility_outlined,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${topic['voteNo']} | ${topic['name']}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: VoteUiTokens.fieldGap),
            Text('สถานะ: ${topic['status']}'),
            const SizedBox(height: VoteUiTokens.fieldGap),
            Text('เปิด ${topic['openAt']} ถึง ${topic['closeAt']}'),
            const SizedBox(height: VoteUiTokens.fieldGap),
            const Text('ตัวเลือก'),
            for (final option in options) Text('• ${option['text']}'),
          ],
        ),
        actions: [
          OutlinedButton(
            style: voteOutlinedButtonStyle(context),
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('ปิด'),
          ),
        ],
      ),
    );
  }
}
