import 'package:flutter/material.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';

import 'pet_host.dart';

class PetReportsPage extends StatefulWidget {
  const PetReportsPage({super.key, required this.menuCode})
    : assert(menuCode == '62008' || menuCode == '62010');
  final String menuCode;
  @override
  State<PetReportsPage> createState() => _PetReportsPageState();
}

class _PetReportsPageState extends State<PetReportsPage> {
  late final api = petApi();
  Map<String, dynamic> metadata = {}, summary = {};
  List<Map<String, dynamic>> rows = [], services = [];
  int page = 1, total = 0;
  bool loading = true, cards = false;
  String? error;
  DateTimeRange? period;
  bool get history => widget.menuCode == '62008';
  LaooWorkspaceUiTokens get tokens => petTokens();
  String get title => metadata['MenuName']?.toString() ?? 'กำลังโหลด...';

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(covariant PetReportsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.menuCode != widget.menuCode) {
      page = 1;
      rows = [];
      load();
    }
  }

  @override
  void dispose() {
    petDispose(api);
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final access = Map<String, dynamic>.from(
        await api.get('/api/company/pet/actions/${widget.menuCode}') as Map,
      );
      metadata = Map<String, dynamic>.from(access['metadata'] as Map);
      final allowed = Map<String, dynamic>.from(access['actions'] as Map);
      if (allowed['view'] != true) throw StateError('ไม่มีสิทธิ์ดูข้อมูลนี้');
      if (history) {
        final data = Map<String, dynamic>.from(
          await api.get(
                '/api/company/pet/history',
                query: {'page': '$page', 'pageSize': '20'},
              )
              as Map,
        );
        rows = (data['items'] as List? ?? [])
            .map((value) => Map<String, dynamic>.from(value as Map))
            .toList();
        total = (data['total'] as num?)?.toInt() ?? 0;
      } else {
        final query = <String, String>{};
        if (period != null) {
          query['from'] = period!.start.toUtc().toIso8601String();
          query['to'] = period!.end
              .add(const Duration(days: 1))
              .toUtc()
              .toIso8601String();
        }
        final data = Map<String, dynamic>.from(
          await api.get('/api/company/pet/dashboard', query: query) as Map,
        );
        summary = Map<String, dynamic>.from(data['summary'] as Map);
        services = (data['services'] as List? ?? [])
            .map((value) => Map<String, dynamic>.from(value as Map))
            .toList();
      }
      if (mounted) setState(() => loading = false);
    } catch (exception) {
      if (mounted) {
        setState(() {
          loading = false;
          error = petErrorText(exception, 'โหลดรายงานสัตว์เลี้ยง');
        });
      }
    }
  }

  String showDate(Object? value) {
    final date = DateTime.tryParse('$value')?.toLocal();
    if (date == null) return '—';
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(date.day)}/${two(date.month)}/${date.year} ${two(date.hour)}:${two(date.minute)}';
  }

  Widget body(double width) {
    if (loading) {
      return LaooSurfaceCard(
        tokens: tokens,
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    if (error != null) {
      return LaooSurfaceCard(
        tokens: tokens,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(error!),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: load,
              icon: const Icon(Icons.refresh),
              label: const Text('ลองอีกครั้ง'),
            ),
          ],
        ),
      );
    }
    if (!history) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LaooSurfaceCard(
            tokens: tokens,
            child: Wrap(
              spacing: 24,
              runSpacing: 16,
              children: [
                for (final entry in const [
                  MapEntry('appointments', 'นัดหมาย'),
                  MapEntry('checkedIn', 'กำลังรับบริการ'),
                  MapEntry('completed', 'เสร็จสิ้น'),
                ])
                  SizedBox(
                    width: 190,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(entry.value),
                        Text(
                          '${summary[entry.key] ?? 0}',
                          style: tokens.sectionStyle,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: tokens.sectionSpacing),
          LaooSurfaceCard(
            tokens: tokens,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('บริการที่ใช้บ่อย', style: tokens.sectionStyle),
                const SizedBox(height: 12),
                if (services.isEmpty)
                  const Text('ยังไม่มีบริการในช่วงวันที่เลือก'),
                for (final service in services)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '${service['name']} · ${service['count']} ครั้ง',
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
    }
    if (rows.isEmpty) {
      return LaooSurfaceCard(
        tokens: tokens,
        child: const Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: Text('ยังไม่มีประวัติบริการ')),
        ),
      );
    }
    if (cards || width < tokens.compactBreakpoint) {
      return Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) SizedBox(height: tokens.itemSpacing),
            LaooSurfaceCard(
              tokens: tokens,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${rows[i]['bookingNo'] ?? ''} · ${rows[i]['petName'] ?? ''}',
                    style: tokens.sectionStyle,
                  ),
                  const SizedBox(height: 6),
                  Text('เริ่ม: ${showDate(rows[i]['startsAt'])}'),
                  Text('สถานะ: ${rows[i]['status'] ?? '—'}'),
                  Text('ยอด: ${rows[i]['amount'] ?? 0}'),
                ],
              ),
            ),
          ],
        ],
      );
    }
    return LaooSurfaceCard(
      tokens: tokens,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: width),
          child: DataTable(
            headingRowColor: WidgetStatePropertyAll(
              tokens.primaryColor.withValues(alpha: 0.1),
            ),
            columns: const [
              DataColumn(label: Text('ID')),
              DataColumn(label: Text('เลขที่จอง')),
              DataColumn(label: Text('สัตว์เลี้ยง')),
              DataColumn(label: Text('เริ่ม')),
              DataColumn(label: Text('สิ้นสุด')),
              DataColumn(label: Text('สถานะ')),
              DataColumn(label: Text('ยอด')),
            ],
            rows: [
              for (final row in rows)
                DataRow(
                  cells: [
                    DataCell(Text('${row['id']}')),
                    DataCell(Text('${row['bookingNo'] ?? '—'}')),
                    DataCell(Text('${row['petName'] ?? '—'}')),
                    DataCell(Text(showDate(row['startsAt']))),
                    DataCell(Text(showDate(row['endsAt']))),
                    DataCell(Text('${row['status'] ?? '—'}')),
                    DataCell(Text('${row['amount'] ?? 0}')),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> choosePeriod() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: period,
    );
    if (picked != null) {
      period = picked;
      await load();
    }
  }

  @override
  Widget build(BuildContext context) => petShell(
    pageTitle: title,
    activeMenu: history ? 'pet-history' : 'pet-dashboard',
    child: ColoredBox(
      color: tokens.backgroundColor,
      child: SingleChildScrollView(
        padding: tokens.contentMargin,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(
              builder: (context, constraints) => LaooCaptionCard(
                tokens: tokens,
                caption: title,
                favoriteKey: history ? 'pet-history' : 'pet-dashboard',
                leading: Icon(
                  petMenuIcon(metadata['IconName']?.toString()),
                  color: tokens.primaryColor,
                ),
                trailing:
                    history && constraints.maxWidth >= tokens.compactBreakpoint
                    ? LaooListCardToggle(
                        tokens: tokens,
                        cards: cards,
                        onChanged: (value) => setState(() => cards = value),
                      )
                    : null,
              ),
            ),
            if (!history) ...[
              SizedBox(height: tokens.sectionSpacing),
              LaooFilterCard(
                tokens: tokens,
                child: OutlinedButton.icon(
                  onPressed: choosePeriod,
                  icon: const Icon(Icons.date_range_outlined),
                  label: Text(
                    period == null
                        ? '30 วันล่าสุด'
                        : '${showDate(period!.start).split(' ').first} – ${showDate(period!.end).split(' ').first}',
                  ),
                ),
              ),
            ],
            SizedBox(height: tokens.sectionSpacing),
            LayoutBuilder(
              builder: (context, constraints) => body(constraints.maxWidth),
            ),
            if (history) ...[
              SizedBox(height: tokens.sectionSpacing),
              LaooPaginationCard(
                tokens: tokens,
                page: page,
                pageCount: total == 0 ? 1 : (total / 20).ceil(),
                pageSize: 20,
                total: total,
                onPrevious: page > 1
                    ? () {
                        page--;
                        load();
                      }
                    : null,
                onNext: page * 20 < total
                    ? () {
                        page++;
                        load();
                      }
                    : null,
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
