part of 'patrol_page.dart';

extension _PatrolViews on _PatrolPageState {
  Widget list(
    List<Map<String, dynamic>> rows,
    Map<String, bool> actions,
    Map<String, dynamic> options,
  ) {
    final canAdd =
        actions['create'] == true || actions['enroll_credential'] == true;
    final start = (page - 1) * _PatrolPageState.pageSize,
        end = (start + _PatrolPageState.pageSize).clamp(0, rows.length);
    final visible = start < rows.length
        ? rows.sublist(start, end)
        : <Map<String, dynamic>>[];
    final pageCount = (rows.length / _PatrolPageState.pageSize).ceil().clamp(
      1,
      999999,
    );
    final trailing = Wrap(
      spacing: patrolTokens.itemSpacing,
      children: [
        LaooListCardToggle(
          tokens: patrolTokens,
          cards: cards,
          onChanged: setCardMode,
        ),
        if (canAdd)
          FilledButton.icon(
            onPressed: () => showCreate(options),
            icon: const Icon(Icons.add),
            label: const Text('เพิ่ม'),
          ),
      ],
    );
    final body = rows.isEmpty
        ? state('ไม่พบข้อมูล')
        : cards
        ? _cards(visible, actions)
        : _table(visible, actions);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        caption(trailing: trailing),
        SizedBox(height: patrolTokens.sectionSpacing),
        Expanded(child: body),
        SizedBox(height: patrolTokens.sectionSpacing),
        LaooPaginationCard(
          tokens: patrolTokens,
          page: page,
          pageCount: pageCount,
          pageSize: _PatrolPageState.pageSize,
          total: rows.length,
          onPrevious: page > 1 ? previousPage : null,
          onNext: page < pageCount ? nextPage : null,
        ),
      ],
    );
  }

  Widget _table(List<Map<String, dynamic>> rows, Map<String, bool> actions) {
    final keys = _keys(rows);
    const actionMenus = {
      '56002',
      '56003',
      '56004',
      '56005',
      '56006',
      '56007',
      '56009',
      '56010',
    };
    final hasActions = actionMenus.contains(widget.menuCode);
    return LaooTableCard(
      tokens: patrolTokens,
      child: LayoutBuilder(
        builder: (context, constraints) => LaooWorkspaceDataTable(
          tokens: patrolTokens,
          columns: [
            const DataColumn(label: Text('ID')),
            const DataColumn(label: Text('Action')),
            ...keys.map((key) => DataColumn(label: Text(_label(key)))),
          ],
          rows: rows
              .map(
                (row) => DataRow(
                  onSelectChanged: widget.menuCode == '56008'
                      ? (_) => showRun((row['id'] as num).toInt(), actions)
                      : null,
                  cells: [
                    DataCell(Text(_value(row['id']))),
                    DataCell(
                      hasActions
                          ? _rowActions(row, actions)
                          : const SizedBox.shrink(),
                    ),
                    ...keys.map(
                      (key) => DataCell(
                        Text(
                          _value(row[key]),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _rowActions(Map<String, dynamic> row, Map<String, bool> actions) {
    final id = (row['id'] as num).toInt();
    final buttons = <Widget>[];
    if ({
          '56002',
          '56003',
          '56004',
          '56005',
          '56006',
        }.contains(widget.menuCode) &&
        actions['edit'] == true) {
      buttons.add(
        IconButton(
          tooltip: 'แก้ไข',
          onPressed: () async {
            try {
              final raw = await api.get(
                '/api/company/patrol/options?menuCode=' + widget.menuCode,
              );
              await showCreate(_map(raw), existing: row);
            } catch (e) {
              if (mounted)
                patrolMessage(context, message: e.toString(), error: true);
            }
          },
          icon: Icon(Icons.edit_outlined, color: patrolTokens.primaryColor),
        ),
      );
    }
    if ({
          '56002',
          '56003',
          '56004',
          '56005',
          '56006',
        }.contains(widget.menuCode) &&
        actions['delete'] == true) {
      buttons.add(
        IconButton(
          tooltip: 'ปิดใช้งาน',
          onPressed: () => _deactivate(row),
          icon: const Icon(Icons.delete_outline, color: Colors.red),
        ),
      );
    }
    if (widget.menuCode == '56007' &&
        row['status'] == 'PLANNED' &&
        actions['edit'] == true) {
      buttons.add(
        IconButton(
          tooltip: 'แก้ไข',
          onPressed: () async {
            try {
              final raw = await api.get(
                '/api/company/patrol/options?menuCode=56007',
              );
              await showCreate(_map(raw), existing: row);
            } catch (e) {
              if (mounted)
                patrolMessage(context, message: e.toString(), error: true);
            }
          },
          icon: Icon(Icons.edit_outlined, color: patrolTokens.primaryColor),
        ),
      );
    }
    if (widget.menuCode == '56007' &&
        row['status'] == 'PLANNED' &&
        actions['assign'] == true) {
      buttons.add(
        IconButton(
          tooltip: 'เปิดรอบตรวจ',
          onPressed: () => run(
            () => api.post('/api/company/patrol/schedules/$id/open'),
            'เปิดรอบตรวจแล้ว',
          ),
          icon: Icon(
            Icons.play_circle_outline,
            color: patrolTokens.primaryColor,
          ),
        ),
      );
    }
    if (widget.menuCode == '56007' &&
        row['status'] == 'PLANNED' &&
        actions['cancel'] == true) {
      buttons.add(
        IconButton(
          tooltip: 'ยกเลิกตาราง',
          onPressed: () async {
            final reason = await askPatrolReason('ยกเลิกตารางตรวจ');
            if (reason != null)
              await run(
                () => api.post(
                  '/api/company/patrol/schedules/$id/cancel',
                  body: {'reason': reason},
                ),
                'ยกเลิกตารางตรวจแล้ว',
              );
          },
          icon: const Icon(Icons.cancel_outlined, color: Colors.red),
        ),
      );
    }
    if (widget.menuCode == '56009' && actions['acknowledge'] == true) {
      buttons.add(
        IconButton(
          tooltip: 'รับทราบ',
          onPressed: () async {
            final reason = await askPatrolReason('รับทราบรอบตรวจ');
            if (reason != null)
              await run(
                () => api.put(
                  '/api/company/patrol/monitor/$id/acknowledge',
                  body: {'reason': reason},
                ),
                'รับทราบรอบตรวจแล้ว',
              );
          },
          icon: const Icon(Icons.task_alt_outlined),
        ),
      );
    }
    if (widget.menuCode == '56010' && actions['acknowledge'] == true) {
      buttons.add(
        IconButton(
          tooltip: 'รับทราบเหตุ',
          onPressed: () => run(
            () => api.put('/api/company/patrol/incidents/$id/acknowledge'),
            'รับทราบเหตุแล้ว',
          ),
          icon: const Icon(Icons.done_all_outlined),
        ),
      );
    }
    if (widget.menuCode == '56010' && actions['escalate'] == true) {
      buttons.add(
        IconButton(
          tooltip: 'ยกระดับเหตุ',
          onPressed: () async {
            final reason = await askPatrolReason('ยกระดับเหตุ');
            if (reason != null)
              await run(
                () => api.put(
                  '/api/company/patrol/incidents/$id/escalate',
                  body: {'reason': reason},
                ),
                'ยกระดับเหตุแล้ว',
              );
          },
          icon: const Icon(Icons.trending_up_outlined),
        ),
      );
    }
    if (widget.menuCode == '56010' &&
        actions['create_service'] == true &&
        row['serviceRequestId'] == null) {
      buttons.add(
        IconButton(
          tooltip: 'สร้างใบงาน Service',
          onPressed: () => run(
            () => api.post('/api/company/patrol/incidents/$id/service-request'),
            'สร้างใบงาน Service แล้ว',
          ),
          icon: const Icon(Icons.build_outlined),
        ),
      );
    }
    return Wrap(spacing: 4, children: buttons);
  }

  Future<void> _deactivate(Map<String, dynamic> row) async {
    final errorColor = Theme.of(context).colorScheme.error;
    final label =
        (row['code'] ?? row['name'] ?? row['id']).toString() +
        ' — ' +
        (row['name'] ?? '').toString();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(patrolTokens.radius),
          side: BorderSide(color: errorColor),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: patrolTokens.cardPadding,
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: errorColor, size: 24),
                    const SizedBox(width: 10),
                    Text(
                      'ยืนยันการลบข้อมูล',
                      style: patrolTokens.captionStyle.copyWith(
                        color: errorColor,
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: patrolTokens.borderColor),
              Padding(
                padding: patrolTokens.cardPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: patrolTokens.cardPadding,
                      color: errorColor.withAlpha(20),
                      child: Text(label),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'ข้อมูลจะถูกปิดใช้งานและเรียกคืนจากหน้านี้ไม่ได้ ประวัติการตรวจเดิมจะยังคงอยู่',
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: patrolTokens.borderColor),
              Padding(
                padding: patrolTokens.cardPadding,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('ยกเลิก'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: errorColor,
                      ),
                      onPressed: () => Navigator.pop(dialogContext, true),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('ลบ'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true) return;
    final id = (row['id'] as num).toInt();
    await run(
      () => api.delete('/api/company/patrol/' + widget.endpoint + '/$id'),
      'ปิดใช้งานข้อมูลแล้ว',
    );
  }

  Widget _cards(List<Map<String, dynamic>> rows, Map<String, bool> actions) =>
      LaooSurfaceCard(
        tokens: patrolTokens,
        child: GridView.builder(
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 360,
            mainAxisExtent: 210,
            crossAxisSpacing: patrolTokens.itemSpacing,
            mainAxisSpacing: patrolTokens.itemSpacing,
          ),
          itemCount: rows.length,
          itemBuilder: (context, index) {
            final row = rows[index];
            final keys = _keys([row]);
            return InkWell(
              onTap: widget.menuCode == '56008'
                  ? () => showRun((row['id'] as num).toInt(), actions)
                  : null,
              borderRadius: BorderRadius.circular(patrolTokens.radius),
              child: Container(
                padding: patrolTokens.cardPadding,
                decoration: BoxDecoration(
                  color: patrolTokens.surfaceColor,
                  border: Border.all(color: patrolTokens.borderColor),
                  borderRadius: BorderRadius.circular(patrolTokens.radius),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.fact_check_outlined,
                      color: patrolTokens.primaryColor,
                    ),
                    const SizedBox(height: 8),
                    for (final key in keys.take(4))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '${_label(key)}: ${_value(row[key])}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    if (widget.menuCode == '56009' ||
                        widget.menuCode == '56010')
                      Align(
                        alignment: Alignment.centerRight,
                        child: _rowActions(row, actions),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      );
  List<String> _keys(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) return const [];
    const hidden = {'employeeId', 'serviceRequestId'};
    final keys = rows.first.keys
        .where((k) => !hidden.contains(k))
        .take(8)
        .toList();
    return keys;
  }

  String _value(dynamic v) {
    if (v == null) return '-';
    if (v is bool) return v ? 'ใช้งาน' : 'ไม่ใช้งาน';
    final t = v.toString();
    return t.length > 19 && t.contains('T')
        ? t.substring(0, 16).replaceFirst('T', ' ')
        : t;
  }

  String _label(String key) =>
      const <String, String>{
        'id': 'ID',
        'code': 'รหัส',
        'name': 'ชื่อ',
        'branch': 'สาขา',
        'timeMode': 'รูปแบบเวลา',
        'requireGps': 'GPS',
        'requirePhoto': 'รูป',
        'requireChecklist': 'Checklist',
        'adapter': 'Adapter',
        'type': 'ประเภท',
        'hint': 'ข้อมูลอ้างอิง',
        'workType': 'ประเภทงาน',
        'sequenceMode': 'ลำดับ',
        'checkpointCount': 'จำนวนจุด',
        'route': 'เส้นทาง',
        'startsAt': 'เริ่ม',
        'endsAt': 'สิ้นสุด',
        'employee': 'พนักงาน',
        'team': 'ทีม',
        'status': 'สถานะ',
        'totalPoints': 'จุดทั้งหมด',
        'completedPoints': 'ตรวจแล้ว',
        'pending': 'รอตรวจ',
        'missed': 'พลาด',
        'late': 'สาย',
        'total': 'ทั้งหมด',
        'severity': 'ระดับ',
        'reportedAt': 'วันที่แจ้ง',
        'action': 'Action',
        'entity': 'รายการ',
        'entityId': 'รหัสรายการ',
        'detail': 'รายละเอียด',
        'createdAt': 'สร้างเมื่อ',
      }[key] ??
      key;

  Widget settings(Map<String, dynamic> data, Map<String, bool> actions) {
    final values = <String, String>{
      'GraceBefore': (data['defaultGraceBeforeMinutes'] ?? 0).toString(),
      'GraceAfter': (data['defaultGraceAfterMinutes'] ?? 15).toString(),
      'OfflineHours': (data['offlineMaxHours'] ?? 24).toString(),
      'GpsRadius': (data['gpsRadiusMeters'] ?? 100).toString(),
      'EscalateAfter': (data['escalateAfterMinutes'] ?? 30).toString(),
    };
    final labels = <String, String>{
      'GraceBefore': 'ผ่อนผันก่อนเวลา (นาที)',
      'GraceAfter': 'ผ่อนผันหลังเวลา (นาที)',
      'OfflineHours': 'อายุข้อมูล Offline (ชั่วโมง)',
      'GpsRadius': 'รัศมี GPS (เมตร)',
      'EscalateAfter': 'แจ้งเตือนเมื่อเกินเวลา (นาที)',
    };
    final controllers = values.map(
      (k, v) => MapEntry(k, TextEditingController(text: v)),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        caption(),
        SizedBox(height: patrolTokens.sectionSpacing),
        Expanded(
          child: LaooSurfaceCard(
            tokens: patrolTokens,
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  for (final e in controllers.entries)
                    SizedBox(
                      width: 280,
                      child: TextField(
                        controller: e.value,
                        keyboardType: TextInputType.number,
                        decoration: input(labels[e.key]!),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        if (actions['edit'] == true) ...[
          SizedBox(height: patrolTokens.sectionSpacing),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: () => run(
                () => api.put(
                  '/api/company/patrol/settings',
                  body: {
                    'graceBefore':
                        int.tryParse(controllers['GraceBefore']!.text) ?? 0,
                    'graceAfter':
                        int.tryParse(controllers['GraceAfter']!.text) ?? 15,
                    'offlineHours':
                        int.tryParse(controllers['OfflineHours']!.text) ?? 24,
                    'gpsRadius':
                        int.tryParse(controllers['GpsRadius']!.text) ?? 100,
                    'escalateAfter':
                        int.tryParse(controllers['EscalateAfter']!.text) ?? 30,
                  },
                ),
                'บันทึกการตั้งค่าสำเร็จ',
              ),
              icon: const Icon(Icons.save_outlined),
              label: const Text('บันทึก'),
            ),
          ),
        ],
      ],
    );
  }

  Widget dashboard(Map<String, dynamic> data) {
    final summary = _map(data['summary']), routes = _rows(data['routes']);
    final cards = <String, String>{
      'รอบตรวจทั้งหมด': _value(summary['totalRuns']),
      'รอบเสร็จสิ้น': _value(summary['completedRuns']),
      'ตรงเวลา': _value(summary['onTime']),
      'สาย': _value(summary['late']),
      'ก่อนเวลา': _value(summary['early']),
      'ตรวจจุดไม่กำหนดเวลา': _value(summary['anytimeCompleted']),
      'พลาดตรวจ': _value(summary['missed']),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        caption(),
        SizedBox(height: patrolTokens.sectionSpacing),
        Wrap(
          spacing: patrolTokens.itemSpacing,
          runSpacing: patrolTokens.itemSpacing,
          children: cards.entries
              .map(
                (e) => SizedBox(
                  width: 190,
                  height: 110,
                  child: LaooSurfaceCard(
                    tokens: patrolTokens,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.key),
                        const Spacer(),
                        Text(
                          e.value,
                          style: patrolTokens.captionStyle.copyWith(
                            color: patrolTokens.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        SizedBox(height: patrolTokens.sectionSpacing),
        Expanded(
          child: routes.isEmpty
              ? state('ยังไม่มีข้อมูลสรุป')
              : _table(routes, const <String, bool>{}),
        ),
      ],
    );
  }
}
