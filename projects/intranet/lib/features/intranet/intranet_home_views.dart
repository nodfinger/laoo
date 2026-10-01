// ignore_for_file: deprecated_member_use, prefer_interpolation_to_compose_strings

part of 'intranet_pages.dart';

extension _IntranetHomeViews on _IntranetPageState {
  Widget homeView(Map<String, dynamic> data) {
    final items = _IntranetPageState.rowsOf(data['items']);
    final required = _IntranetPageState.rowsOf(data['required']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        caption(),
        SizedBox(height: intranetUiTokens.sectionSpacing),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact =
                  constraints.maxWidth < intranetUiTokens.compactBreakpoint;
              final feed = feedPanel(items);
              final side = requiredPanel(required);
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: intranetUiTokens.primaryColor.withValues(
                          alpha: .09,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.waving_hand_outlined,
                            size: 38,
                            color: intranetUiTokens.primaryColor,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'สวัสดี ยินดีต้อนรับสู่พื้นที่ทำงานของคุณ',
                                  style: intranetUiTokens.captionStyle,
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'ติดตามข่าว ประกาศ กิจกรรม และเอกสารสำคัญของบริษัทได้จากหน้านี้',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: intranetUiTokens.sectionSpacing),
                    LaooFilterCard(
                      tokens: intranetUiTokens,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          SizedBox(
                            width: compact ? constraints.maxWidth : 320,
                            child: TextField(
                              controller: search,
                              onSubmitted: (_) => reload(),
                              decoration: input(
                                'ค้นหาเนื้อหา',
                                icon: Icons.search,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: compact ? constraints.maxWidth : 220,
                            child: DropdownButtonFormField<String>(
                              value: type,
                              decoration: input('ประเภท'),
                              items: const [
                                DropdownMenuItem(
                                  value: '',
                                  child: Text('ทั้งหมด'),
                                ),
                                DropdownMenuItem(
                                  value: 'NEWS',
                                  child: Text('ข่าว'),
                                ),
                                DropdownMenuItem(
                                  value: 'ANNOUNCEMENT',
                                  child: Text('ประกาศ'),
                                ),
                                DropdownMenuItem(
                                  value: 'ACTIVITY',
                                  child: Text('กิจกรรม'),
                                ),
                                DropdownMenuItem(
                                  value: 'DOCUMENT',
                                  child: Text('เอกสาร'),
                                ),
                              ],
                              onChanged: (value) => type = value ?? '',
                            ),
                          ),
                          FilledButton.icon(
                            onPressed: reload,
                            icon: const Icon(Icons.search),
                            label: const Text('ค้นหา'),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: intranetUiTokens.sectionSpacing),
                    if (compact) ...[
                      side,
                      SizedBox(height: intranetUiTokens.sectionSpacing),
                      feed,
                    ] else
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 7, child: feed),
                          SizedBox(width: intranetUiTokens.sectionSpacing),
                          Expanded(flex: 3, child: side),
                        ],
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget feedPanel(List<Map<String, dynamic>> items) => LaooSurfaceCard(
    tokens: intranetUiTokens,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('เรื่องล่าสุด', style: intranetUiTokens.sectionStyle),
        const SizedBox(height: 12),
        if (items.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('ยังไม่มีเนื้อหาที่เผยแพร่')),
          )
        else
          ...items.map(
            (row) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: intranetUiTokens.primaryColor.withValues(
                        alpha: .10,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(
                      typeIcon(_IntranetPageState.textOf(row, 'type')),
                      color: intranetUiTokens.primaryColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (row['pinned'] == true) ...[
                              Icon(
                                Icons.push_pin_outlined,
                                size: 16,
                                color: intranetUiTokens.primaryColor,
                              ),
                              const SizedBox(width: 4),
                            ],
                            Expanded(
                              child: Text(
                                _IntranetPageState.textOf(row, 'title'),
                                style: intranetUiTokens.sectionStyle,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _IntranetPageState.textOf(row, 'summary', ''),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _IntranetPageState.typeLabel(
                                _IntranetPageState.textOf(row, 'type'),
                              ) +
                              ' • ' +
                              _IntranetPageState.dateOf(row['publishAt']),
                          style: intranetUiTokens.tableStyle,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );

  Widget requiredPanel(List<Map<String, dynamic>> rows) => LaooSurfaceCard(
    tokens: intranetUiTokens,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              Icons.fact_check_outlined,
              color: intranetUiTokens.primaryColor,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'รายการที่ต้องรับทราบ',
                style: intranetUiTokens.sectionStyle,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (rows.isEmpty)
          const Text('ไม่มีรายการค้างรับทราบ')
        else
          ...rows.map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(_IntranetPageState.textOf(row, 'title')),
                  const SizedBox(height: 6),
                  FilledButton.tonalIcon(
                    onPressed: () => run(
                      () => api.post(
                        '/api/company/intranet/home/' +
                            _IntranetPageState.idOf(row).toString() +
                            '/receipt',
                        body: {'acknowledge': true},
                      ),
                      'บันทึกการรับทราบแล้ว',
                    ),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('รับทราบ'),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );

  Widget reportsView(Map<String, dynamic> data) {
    final summaries = _IntranetPageState.rowsOf(data['summary']);
    final summary = summaries.isEmpty ? <String, dynamic>{} : summaries.first;
    final items = _IntranetPageState.rowsOf(data['items']);
    final history = _IntranetPageState.rowsOf(data['history']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        caption(),
        SizedBox(height: intranetUiTokens.sectionSpacing),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: intranetUiTokens.sectionSpacing,
                  runSpacing: intranetUiTokens.sectionSpacing,
                  children: [
                    metric(
                      'เนื้อหาทั้งหมด',
                      _IntranetPageState.intOf(summary['totalContent']),
                      Icons.article_outlined,
                    ),
                    metric(
                      'เผยแพร่แล้ว',
                      _IntranetPageState.intOf(summary['publishedContent']),
                      Icons.public_outlined,
                    ),
                    metric(
                      'รออนุมัติ',
                      _IntranetPageState.intOf(summary['pendingContent']),
                      Icons.hourglass_top_outlined,
                    ),
                    metric(
                      'ต้องรับทราบ',
                      _IntranetPageState.intOf(
                        summary['acknowledgementContent'],
                      ),
                      Icons.fact_check_outlined,
                    ),
                  ],
                ),
                SizedBox(height: intranetUiTokens.sectionSpacing),
                LaooSurfaceCard(
                  tokens: intranetUiTokens,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'สถิติการอ่านและรับทราบ',
                        style: intranetUiTokens.sectionStyle,
                      ),
                      const SizedBox(height: 12),
                      if (items.isEmpty)
                        const Text('ยังไม่มีข้อมูล')
                      else
                        ...items.map(
                          (row) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              _IntranetPageState.textOf(row, 'title'),
                            ),
                            subtitle: Text(
                              _IntranetPageState.textOf(row, 'code') +
                                  ' • ' +
                                  _IntranetPageState.statusLabel(
                                    _IntranetPageState.textOf(row, 'status'),
                                  ),
                            ),
                            trailing: Text(
                              'อ่าน ' +
                                  _IntranetPageState.intOf(
                                    row['readCount'],
                                  ).toString() +
                                  ' / รับทราบ ' +
                                  _IntranetPageState.intOf(
                                    row['acknowledgedCount'],
                                  ).toString(),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(height: intranetUiTokens.sectionSpacing),
                LaooSurfaceCard(
                  tokens: intranetUiTokens,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'ประวัติการอนุมัติ',
                        style: intranetUiTokens.sectionStyle,
                      ),
                      const SizedBox(height: 12),
                      if (history.isEmpty)
                        const Text('ยังไม่มีประวัติ')
                      else
                        ...history.map(
                          (row) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              Icons.history,
                              color: intranetUiTokens.primaryColor,
                            ),
                            title: Text(
                              _IntranetPageState.textOf(row, 'title'),
                            ),
                            subtitle: Text(
                              _IntranetPageState.textOf(row, 'action') +
                                  ' • ' +
                                  _IntranetPageState.dateOf(row['actionAt']) +
                                  '\n' +
                                  _IntranetPageState.textOf(row, 'reason', ''),
                            ),
                          ),
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

  Widget metric(String label, int value, IconData icon) => SizedBox(
    width: 230,
    child: LaooSurfaceCard(
      tokens: intranetUiTokens,
      child: Row(
        children: [
          Icon(icon, size: 32, color: intranetUiTokens.primaryColor),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value.toString(), style: intranetUiTokens.captionStyle),
              Text(label),
            ],
          ),
        ],
      ),
    ),
  );

  IconData typeIcon(String value) {
    if (value == 'ANNOUNCEMENT') return Icons.campaign_outlined;
    if (value == 'ACTIVITY') return Icons.event_outlined;
    if (value == 'DOCUMENT') return Icons.description_outlined;
    return Icons.newspaper_outlined;
  }
}
