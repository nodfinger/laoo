import 'package:flutter/material.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';
import 'host.dart';
import 'market_booking_dialog.dart';
import 'routes.dart';

typedef MarketRow = Map<String, dynamic>;
MarketRow marketMap(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
List<MarketRow> marketRows(dynamic value) =>
    value is List ? value.map(marketMap).toList() : <MarketRow>[];

class MarketMapPage extends StatefulWidget {
  const MarketMapPage({super.key});
  @override
  State<MarketMapPage> createState() => _MarketMapPageState();
}

class _MarketMapPageState extends State<MarketMapPage> {
  static const base = '/api/company/market';
  late final api = marketApi();
  MarketRow metadata = {}, actions = {}, traderActions = {};
  List<MarketRow> markets = [], stalls = [], traders = [], bookings = [];
  int? marketId;
  int page = 1;
  DateTime selectedDay = DateTime.now();
  bool loading = true;
  String? error;

  String get title => metadata['MenuName']?.toString() ?? 'ผังและล็อกขายของ';
  bool can(String action) =>
      metadata['ScreenType'] == 1 && actions[action] == true;
  String date(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    marketDispose(api);
    super.dispose();
  }

  Future<void> load() async {
    if (!mounted) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final access = marketMap(await api.get('$base/actions/59003'));
      metadata = marketMap(access['metadata']);
      actions = marketMap(access['actions']);
      if (actions['view'] != true) throw StateError('ไม่มีสิทธิ์ดูผังล็อก');
      try {
        traderActions = marketMap(
          marketMap(await api.get('$base/actions/59004'))['actions'],
        );
      } catch (_) {
        traderActions = {};
      }
      markets = marketRows(await api.get('$base/markets'));
      if (!markets.any((m) => m['id'] == marketId)) {
        marketId = markets.isEmpty
            ? null
            : (markets.first['id'] as num).toInt();
      }
      if (marketId == null) {
        stalls = [];
        traders = [];
        bookings = [];
      } else {
        final data = await Future.wait([
          api.get(
            '$base/markets/$marketId/map',
            query: {'on': date(selectedDay)},
          ),
          api.get('$base/markets/$marketId/bookings'),
          api.get('$base/traders'),
        ]);
        stalls = marketRows(data[0]);
        bookings = marketRows(data[1]);
        traders = marketRows(data[2]);
      }
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          error = marketErrorText(e, 'เปิดผังตลาด');
        });
      }
    }
  }

  Future<void> chooseDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: selectedDay,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (value == null) return;
    selectedDay = value;
    await load();
  }

  Future<void> reserve(MarketRow stall) async {
    if (!can('reserve')) return;
    final changed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => MarketBookingDialog(
        title: title,
        iconName: metadata['IconName']?.toString(),
        stall: stall,
        traders: traders,
        selectedDay: selectedDay,
        api: api,
        tokens: marketTokens(),
        onSaved: load,
      ),
    );
    if (!mounted) return;
    if (changed == true) {
      await load();
    }
  }

  Future<void> cancel(MarketRow booking) async {
    if (!can('cancel')) return;
    final reason = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => MarketCancelDialog(tokens: marketTokens()),
    );
    if (reason == null || !mounted) return;
    try {
      await api.post(
        '$base/bookings/${booking['id']}/cancel',
        body: {'reason': reason},
      );
      if (!mounted) return;
      marketMessage(context, message: 'ยกเลิกการจองแล้ว', error: false);
      await load();
    } catch (e) {
      if (mounted) {
        marketMessage(
          context,
          message: marketErrorText(e, 'ยกเลิกการจอง'),
          error: true,
        );
      }
    }
  }

  Color statusColor(String status, ColorScheme scheme, Color primary) =>
      switch (status) {
        'VACANT' => primary,
        'RESERVED' => scheme.tertiary,
        'OCCUPIED' => scheme.error,
        'RENOVATION' => scheme.secondary,
        _ => scheme.outline,
      };
  String statusText(String status) => switch (status) {
    'VACANT' => 'ว่าง',
    'RESERVED' => 'จอง',
    'OCCUPIED' => 'มีผู้เช่า',
    'CLOSED' => 'ปิด',
    'RENOVATION' => 'ปรับปรุง',
    _ => status,
  };

  Widget stallCard(MarketRow stall) {
    final t = marketTokens();
    final status = '${stall['status']}';
    final color = statusColor(
      status,
      Theme.of(context).colorScheme,
      t.primaryColor,
    );
    return Material(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(t.radius),
      child: InkWell(
        borderRadius: BorderRadius.circular(t.radius),
        onTap: status == 'VACANT' && can('reserve')
            ? () => reserve(stall)
            : null,
        child: Padding(
          padding: t.cardPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${stall['code']}',
                style: t.sectionStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.circle, size: 11, color: color),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      statusText(status),
                      style: t.tableStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (stall['trader'] != null)
                Text(
                  '${stall['trader']}',
                  style: t.tableStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget mapSection() {
    final t = marketTokens();
    if (stalls.isEmpty) {
      return LaooSurfaceCard(
        tokens: t,
        child: const Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'ยังไม่มีล็อกในตลาดนี้ ติดต่อผู้ดูแลเพื่อเพิ่มผังพื้นที่',
          ),
        ),
      );
    }
    return LaooSurfaceCard(
      tokens: t,
      child: LayoutBuilder(
        builder: (context, size) {
          final columns = size.maxWidth < 500
              ? 2
              : size.maxWidth < 900
              ? 4
              : 6;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ผังล็อกขายของ · ${date(selectedDay)}',
                style: t.sectionStyle,
              ),
              SizedBox(height: t.itemSpacing),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: stalls.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: t.itemSpacing,
                  crossAxisSpacing: t.itemSpacing,
                  mainAxisExtent: 104,
                ),
                itemBuilder: (context, index) => stallCard(stalls[index]),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget bookingsSection() {
    final t = marketTokens();
    const pageSize = 10;
    final pages = bookings.isEmpty ? 1 : (bookings.length / pageSize).ceil();
    if (page > pages) page = pages;
    final shown = bookings.skip((page - 1) * pageSize).take(pageSize).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LaooSurfaceCard(
          tokens: t,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('รายการจองล่าสุด', style: t.sectionStyle),
              if (shown.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text('ยังไม่มีการจองในตลาดนี้', style: t.tableStyle),
                ),
              ...shown.map(
                (booking) => Column(
                  children: [
                    const Divider(height: 1),
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: t.itemSpacing),
                      child: Wrap(
                        spacing: t.itemSpacing * 2,
                        runSpacing: t.itemSpacing,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          SizedBox(
                            width: 90,
                            child: Text(
                              '${booking['stall']}',
                              style: t.sectionStyle,
                            ),
                          ),
                          SizedBox(
                            width: 220,
                            child: Text(
                              '${booking['trader']}',
                              style: t.tableStyle,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${booking['startsOn']}'.split('T').first,
                            style: t.tableStyle,
                          ),
                          Text(
                            'ถึง ${booking['endsOn']}'.split('T').first,
                            style: t.tableStyle,
                          ),
                          Text(
                            statusText('${booking['status']}'),
                            style: t.tableStyle,
                          ),
                          if (booking['status'] == 'RESERVED' && can('cancel'))
                            TextButton.icon(
                              onPressed: () => cancel(booking),
                              icon: const Icon(Icons.close),
                              label: const Text('ยกเลิก'),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: t.sectionSpacing),
        LaooPaginationCard(
          tokens: t,
          page: page,
          pageCount: pages,
          pageSize: pageSize,
          total: bookings.length,
          onPrevious: page > 1 ? () => setState(() => page--) : null,
          onNext: page < pages ? () => setState(() => page++) : null,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = marketTokens();
    return marketShell(
      pageTitle: title,
      activeMenu: MarketRoutes.stalls,
      child: ColoredBox(
        color: t.backgroundColor,
        child: SingleChildScrollView(
          padding: t.contentMargin,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LaooCaptionCard(
                tokens: t,
                caption: title,
                favoriteKey: MarketRoutes.stalls,
                leading: Icon(
                  marketMenuIcon(metadata['IconName']?.toString()),
                  color: t.primaryColor,
                ),
              ),
              SizedBox(height: t.sectionSpacing),
              LaooFilterCard(
                tokens: t,
                child: Wrap(
                  spacing: t.itemSpacing,
                  runSpacing: t.itemSpacing,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 280,
                      child: DropdownButtonFormField<int>(
                        initialValue: marketId,
                        decoration: InputDecoration(
                          labelText: 'ตลาด',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(t.radius),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(t.radius),
                            borderSide: BorderSide(color: t.borderColor),
                          ),
                        ),
                        items: markets
                            .map(
                              (m) => DropdownMenuItem<int>(
                                value: (m['id'] as num).toInt(),
                                child: Text(
                                  '${m['name']}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (id) {
                          marketId = id;
                          page = 1;
                          load();
                        },
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: chooseDate,
                      icon: const Icon(Icons.calendar_month_outlined),
                      label: Text(date(selectedDay)),
                    ),
                  ],
                ),
              ),
              SizedBox(height: t.sectionSpacing),
              if (loading)
                LaooSurfaceCard(
                  tokens: t,
                  child: const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                )
              else if (error != null)
                LaooSurfaceCard(
                  tokens: t,
                  child: Column(
                    children: [
                      Text(error!, style: t.tableStyle),
                      TextButton.icon(
                        onPressed: load,
                        icon: const Icon(Icons.refresh),
                        label: const Text('ลองอีกครั้ง'),
                      ),
                    ],
                  ),
                )
              else ...[
                mapSection(),
                SizedBox(height: t.sectionSpacing),
                bookingsSection(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
