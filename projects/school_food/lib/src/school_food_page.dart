import 'package:flutter/material.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';
import 'host.dart';
import 'ui.dart';
import 'pos.dart';
import 'transfer_editor.dart';
import 'food_paged_dialog.dart';

class SchoolFoodPage extends StatefulWidget {
  const SchoolFoodPage({super.key, required this.menuCode});
  final String menuCode;
  @override
  State<SchoolFoodPage> createState() => _SchoolFoodPageState();
}

class _SchoolFoodPageState extends State<SchoolFoodPage> {
  late final api = foodApi();
  final search = TextEditingController();
  final defaultRate = TextEditingController();
  final priceControllers = <int, TextEditingController>{};
  FoodRow actions = {}, metadata = {}, options = {}, settings = {};
  List<FoodRow> shops = [], rows = [];
  int? shop;
  int page = 1, total = 0;
  bool loading = true, saving = false, cards = false;
  String? error;
  String dimension = 'shop';
  String? pendingKey, pendingSignature;
  bool transferOpen = false;
  int? transferId;
  bool schoolUser = false;
  DateTime reportFrom = DateTime.now(), reportTo = DateTime.now();
  bool get reporting => {'53010', '53011', '53012'}.contains(code);
  static const base = '/api/company/school-food';
  String get code => widget.menuCode;
  String get title => metadata['MenuName']?.toString() ?? 'กำลังโหลด';
  bool can(String action) {
    final type = (metadata['ScreenType'] as num?)?.toInt();
    if (type == null || actions[action] != true) return false;
    if (action == 'create' || action == 'delete') return type == 1 || type == 4;
    if (action == 'edit') return type == 1 || type == 2 || type == 4;
    return true;
  }

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    search.dispose();
    defaultRate.dispose();
    for (final c in priceControllers.values) {
      c.dispose();
    }
    foodDispose(api);
    super.dispose();
  }

  Future<void> load() async {
    if (!mounted) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final access = foodMap(await api.get('$base/actions/$code'));
      actions = foodMap(access['actions']);
      schoolUser = access['schoolUser'] == true;
      metadata = foodMap(access['metadata']);
      if (!can('view')) throw StateError('ไม่มีสิทธิ์เปิดหน้าจอนี้');
      options = foodMap(await api.get('$base/options/$code'));
      shops = foodRows(await api.get('$base/shops', query: {'menu': code}));
      if (!shops.any((s) => s['id'] == shop)) {
        shop = reporting && schoolUser
            ? null
            : shops.isEmpty
            ? null
            : (shops.first['id'] as num).toInt();
      }
      final query = {'page': '$page', 'pageSize': '10', 'search': search.text};
      dynamic result;
      switch (code) {
        case '53001':
          settings = foodMap(await api.get('$base/settings'));
          defaultRate.text = '${settings['DefaultCommissionRate'] ?? 0}';
          break;
        case '53002':
          final filtered = shops
              .where(
                (s) => '${s['code']} ${s['name']}'.toLowerCase().contains(
                  search.text.toLowerCase(),
                ),
              )
              .toList();
          total = filtered.length;
          rows = filtered.skip((page - 1) * 10).take(10).toList();
          break;
        case '53003':
          result = shop == null
              ? null
              : await api.get('$base/shops/$shop/items', query: query);
          break;
        case '53004':
          result = shop == null
              ? []
              : await api.get('$base/shops/$shop/commission');
          break;
        case '53005':
          result = await api.get('$base/identifiers', query: query);
          break;
        case '53006':
          result = await api.get('$base/transfers', query: query);
          break;
        case '53007':
          result = await api.get('$base/wallets', query: query);
          break;
        case '53009':
          result = await api.get(
            '$base/sales',
            query: {...query, if (shop != null) 'shop': '$shop'},
          );
          break;
        case '53010':
        case '53011':
        case '53012':
          result = await api.get(
            '$base/reports/$code',
            query: {
              ...query,
              'dimension': dimension,
              'from': reportFrom.toIso8601String().split('T').first,
              'to': reportTo.toIso8601String().split('T').first,
              if (shop != null) 'shop': '$shop',
            },
          );
          break;
      }
      if (result != null) {
        if (result is List) {
          total = result.length;
          rows = foodRows(result).skip((page - 1) * 10).take(10).toList();
        } else {
          final data = foodMap(result);
          rows = foodRows(data['rows']);
          total = (data['total'] as num?)?.toInt() ?? 0;
        }
      } else if (code == '53003') {
        rows = [];
        total = 0;
      }
      for (final c in priceControllers.values) {
        c.dispose();
      }
      priceControllers.clear();
      if (code == '53003') {
        for (final row in rows) {
          priceControllers[(row['id'] as num).toInt()] = TextEditingController(
            text: '${row['price']}',
          );
        }
      }
      if (mounted) setState(() => loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          error = foodError(e);
        });
      }
    }
  }

  Future<void> write(String path, FoodRow data, {bool put = false}) async {
    if (put) {
      await api.put('$base/$path', body: data);
    } else {
      await api.post('$base/$path', body: data);
    }
    if (!mounted) return;
    foodMessage(context, message: 'บันทึกข้อมูลแล้ว', error: false);
    await load();
  }

  Future<void> deleteShop(FoodRow row) async {
    if (!can('delete')) return;
    final confirmed = await foodConfirmDelete(
      context,
      value: '${row['code']} · ${row['name']}',
    );
    if (!confirmed || !mounted) return;
    try {
      await api.delete(
        '$base/shops/${row['id']}',
        query: {'requestKey': foodKey()},
      );
      if (!mounted) return;
      foodMessage(context, message: 'ลบร้านค้าแล้ว', error: false);
      await load();
    } catch (e) {
      if (mounted) {
        foodMessage(
          context,
          message: 'ลบร้านค้าไม่สำเร็จ\nรายละเอียดเพิ่มเติม: ${foodError(e)}',
          error: true,
        );
      }
    }
  }

  Future<void> cancelTransfer(FoodRow row) async {
    if (!can('delete') || !{'DRAFT', 'SENT'}.contains(row['status'])) return;
    final confirmed = await foodConfirmDelete(
      context,
      value: '${row['code']} · ${row['name']}',
      action: 'ยกเลิก',
    );
    if (!confirmed || !mounted) return;
    try {
      await api.delete(
        '$base/transfers/${row['id']}',
        query: {'requestKey': foodKey()},
      );
      if (!mounted) return;
      foodMessage(context, message: 'ยกเลิกใบโอนแล้ว', error: false);
      await load();
    } catch (e) {
      if (mounted) {
        foodMessage(
          context,
          message: 'ยกเลิกใบโอนไม่สำเร็จ\nรายละเอียดเพิ่มเติม: ${foodError(e)}',
          error: true,
        );
      }
    }
  }

  Future<void> exportReport() async {
    final export = foodReportExport;
    if (!reporting || !can('export') || export == null || saving) return;
    setState(() => saving = true);
    try {
      final query = {
        'dimension': dimension,
        'from': reportFrom.toIso8601String().split('T').first,
        'to': reportTo.toIso8601String().split('T').first,
        if (shop != null) 'shop': '$shop',
      };
      await export(
        '$base/reports/$code/export',
        query,
        'school-food-$code-${DateTime.now().toIso8601String().split('T').first}.csv',
      );
    } catch (e) {
      if (mounted) {
        foodMessage(
          context,
          message:
              'ส่งออกรายงานไม่สำเร็จ\nรายละเอียดเพิ่มเติม: ${foodError(e)}',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> pickReportDate(bool start) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: start ? reportFrom : reportTo,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          datePickerTheme: DatePickerThemeData(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(foodTokens().radius),
            ),
          ),
        ),
        child: child!,
      ),
    );
    if (selected != null && mounted) {
      setState(() {
        if (start) {
          reportFrom = selected;
          if (reportTo.isBefore(reportFrom)) reportTo = reportFrom;
        } else {
          reportTo = selected;
          if (reportFrom.isAfter(reportTo)) reportFrom = reportTo;
        }
      });
    }
  }

  Future<void> saveSettings() async {
    final rate = double.tryParse(defaultRate.text);
    if (rate == null || rate < 0 || rate > 100) {
      foodMessage(
        context,
        message:
            'บันทึกไม่ได้\nรายละเอียดเพิ่มเติม: อัตราหักต้องเป็นตัวเลข 0–100',
        error: true,
      );
      return;
    }
    setState(() => saving = true);
    try {
      await write('settings', {
        'requestKey': pendingKey ??= foodKey(),
        'isEnabled': settings['IsEnabled'] == true,
        'commissionEnabled': settings['CommissionEnabled'] == true,
        'defaultCommissionRate': rate,
      }, put: true);
      pendingKey = null;
    } catch (e) {
      if (mounted) {
        foodMessage(
          context,
          message: 'บันทึกไม่สำเร็จ\nรายละเอียดเพิ่มเติม: ${foodError(e)}',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => foodShell(
    pageTitle: title,
    activeMenu: code,
    child: transferOpen
        ? FoodTransferEditor(
            title: title,
            shops: shops,
            warehouses: foodRows(options['warehouses']),
            actions: actions,
            id: transferId,
            close: () {
              setState(() => transferOpen = false);
              load();
            },
          )
        : LayoutBuilder(
            builder: (context, size) {
              final compact = size.maxWidth < foodTokens().compactBreakpoint;
              return Padding(
                padding: foodTokens().contentMargin,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LaooCaptionCard(
                      tokens: foodTokens(),
                      caption: title,
                      favoriteKey: code,
                      leading: Icon(_icon, color: foodTokens().primaryColor),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!compact && code != '53001' && code != '53008')
                            IconButton(
                              tooltip: cards ? 'แสดง List' : 'แสดง Card',
                              onPressed: () => setState(() => cards = !cards),
                              icon: Icon(
                                cards ? Icons.view_list : Icons.grid_view,
                              ),
                            ),
                          if (can('create') && code == '53002')
                            foodButton('เพิ่ม', Icons.add, () => shopForm()),
                          if (can('create') && code == '53005')
                            foodButton('เพิ่ม', Icons.add, identifierForm),
                          if (code == '53005' && can('manage_credential'))
                            IconButton(
                              tooltip: 'บัญชีนักเรียน',
                              icon: const Icon(Icons.manage_accounts_outlined),
                              onPressed: credentialForm,
                            ),
                          if (can('create') && code == '53006')
                            foodButton(
                              'เพิ่ม',
                              Icons.add,
                              () => setState(() {
                                transferId = null;
                                transferOpen = true;
                              }),
                            ),
                        ],
                      ),
                    ),
                    SizedBox(height: foodTokens().sectionSpacing),
                    if (loading)
                      const Expanded(
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (error != null)
                      Expanded(
                        child: LaooSurfaceCard(
                          tokens: foodTokens(),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('โหลดข้อมูลไม่สำเร็จ'),
                                Text('รายละเอียดเพิ่มเติม: $error'),
                                foodButton('ลองอีกครั้ง', Icons.replay, load),
                              ],
                            ),
                          ),
                        ),
                      )
                    else if (code == '53001')
                      Expanded(child: _settings())
                    else if (code == '53008')
                      Expanded(
                        child: FoodPos(shops: shops, canSell: can('sale')),
                      )
                    else ...[
                      LaooFilterCard(
                        tokens: foodTokens(),
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if ({
                              '53003',
                              '53004',
                              '53009',
                              '53010',
                              '53011',
                              '53012',
                            }.contains(code))
                              SizedBox(
                                width: compact ? size.maxWidth - 40 : 280,
                                child: DropdownButtonFormField<int>(
                                  initialValue: shop,
                                  isExpanded: true,
                                  decoration: foodDecoration('ร้านค้า'),
                                  style: foodTokens().inputStyle,
                                  items: [
                                    if (reporting && schoolUser)
                                      const DropdownMenuItem<int>(
                                        value: null,
                                        child: Text('ทุกร้านค้า'),
                                      ),
                                    ...shops.map(
                                      (s) => DropdownMenuItem(
                                        value: (s['id'] as num).toInt(),
                                        child: Text(
                                          '${s['name']}',
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                  ],
                                  onChanged: (v) {
                                    shop = v;
                                    page = 1;
                                    load();
                                  },
                                ),
                              ),
                            if ({'53002', '53003', '53007'}.contains(code))
                              SizedBox(
                                width: compact ? size.maxWidth - 40 : 420,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: search,
                                        style: foodTokens().inputStyle,
                                        decoration: foodDecoration(
                                          'ค้นหารหัสหรือชื่อ',
                                        ),
                                        onSubmitted: (_) {
                                          page = 1;
                                          load();
                                        },
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'ค้นหา',
                                      onPressed: () {
                                        page = 1;
                                        load();
                                      },
                                      icon: const Icon(Icons.search),
                                    ),
                                    IconButton(
                                      tooltip: 'ล้าง Filter',
                                      onPressed: () {
                                        search.clear();
                                        page = 1;
                                        load();
                                      },
                                      icon: const Icon(
                                        Icons.filter_alt_off_outlined,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (reporting) ...[
                              foodButton(
                                'จาก ${foodDateText(reportFrom)}',
                                Icons.calendar_today,
                                () => pickReportDate(true),
                                outlined: true,
                              ),
                              foodButton(
                                'ถึง ${foodDateText(reportTo)}',
                                Icons.calendar_today,
                                () => pickReportDate(false),
                                outlined: true,
                              ),
                              foodButton('ค้นหา', Icons.search, () {
                                page = 1;
                                load();
                              }),
                              if (can('export') && foodReportExport != null)
                                foodButton(
                                  'ส่งออก CSV',
                                  Icons.download_outlined,
                                  saving ? null : exportReport,
                                  outlined: true,
                                ),
                            ],
                            if (code == '53012')
                              SizedBox(
                                width: 180,
                                child: DropdownButtonFormField<String>(
                                  initialValue: dimension,
                                  isExpanded: true,
                                  decoration: foodDecoration('มิติรายงาน'),
                                  items:
                                      const {
                                            'shop': 'ร้านค้า',
                                            'category': 'ประเภทสินค้า',
                                            'item': 'สินค้า',
                                            'level': 'ชั้นปี',
                                            'classroom': 'ห้องเรียน',
                                            'student': 'นักเรียน',
                                            'day': 'วัน',
                                            'month': 'เดือน',
                                            'year': 'ปี',
                                          }.entries
                                          .map(
                                            (e) => DropdownMenuItem(
                                              value: e.key,
                                              child: Text(e.value),
                                            ),
                                          )
                                          .toList(),
                                  onChanged: (v) {
                                    dimension = v!;
                                    page = 1;
                                    load();
                                  },
                                ),
                              ),
                            if (code == '53003' && can('edit'))
                              foodButton(
                                'บันทึกหน้านี้',
                                Icons.save_outlined,
                                saving ? null : saveItems,
                              ),
                            if (code == '53004' && can('edit') && shop != null)
                              foodButton(
                                'อัตรารายสินค้า',
                                Icons.percent,
                                commissionForm,
                              ),
                            if (code == '53004' && can('edit') && shop != null)
                              foodButton(
                                'อัตราตามประเภท',
                                Icons.category_outlined,
                                commissionTypeForm,
                                outlined: true,
                              ),
                          ],
                        ),
                      ),
                      SizedBox(height: foodTokens().sectionSpacing),
                      Expanded(child: _list(compact || cards)),
                      SizedBox(height: foodTokens().sectionSpacing),
                      LaooPaginationCard(
                        tokens: foodTokens(),
                        page: page,
                        pageCount: (total / 10).ceil().clamp(1, 100000),
                        pageSize: 10,
                        total: total,
                        onPrevious: page > 1
                            ? () {
                                page--;
                                load();
                              }
                            : null,
                        onNext: page * 10 < total
                            ? () {
                                page++;
                                load();
                              }
                            : null,
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
  );
  IconData get _icon => switch (code) {
    '53001' => Icons.settings_outlined,
    '53002' => Icons.storefront_outlined,
    '53003' => Icons.inventory_2_outlined,
    '53004' => Icons.percent,
    '53005' => Icons.badge_outlined,
    '53006' => Icons.swap_horiz,
    '53007' => Icons.account_balance_wallet_outlined,
    '53008' => Icons.point_of_sale,
    '53009' => Icons.receipt_long_outlined,
    '53010' => Icons.history,
    '53011' => Icons.fact_check_outlined,
    _ => Icons.dashboard_outlined,
  };
  Widget _settings() => LaooSurfaceCard(
    tokens: foodTokens(),
    child: ListView(
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('เปิดใช้ระบบ'),
          value: settings['IsEnabled'] == true,
          onChanged: can('edit') && !saving
              ? (v) => setState(() {
                  settings['IsEnabled'] = v;
                  pendingKey = null;
                })
              : null,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('หักเปอร์เซ็นต์ยอดขาย'),
          value: settings['CommissionEnabled'] == true,
          onChanged: can('edit') && !saving
              ? (v) => setState(() {
                  settings['CommissionEnabled'] = v;
                  pendingKey = null;
                })
              : null,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: defaultRate,
          enabled: can('edit') && !saving,
          style: foodTokens().inputStyle,
          keyboardType: TextInputType.number,
          decoration: foodDecoration('อัตราเริ่มต้น (%)'),
          onChanged: (_) => pendingKey = null,
        ),
        const SizedBox(height: 16),
        const Text(
          'ลำดับอัตราที่ใช้: สินค้า → ประเภทสินค้า → ร้านค้า → ค่าเริ่มต้นระบบ',
        ),
        const SizedBox(height: 16),
        if (can('edit'))
          Align(
            alignment: Alignment.centerRight,
            child: foodButton(
              saving ? 'กำลังบันทึก' : 'บันทึก',
              Icons.save_outlined,
              saving ? null : saveSettings,
            ),
          ),
      ],
    ),
  );
  List<(String, String)> get columns => switch (code) {
    '53002' => [
      ('code', 'รหัส'),
      ('name', 'ร้านค้า'),
      ('TrackStock', 'เก็บสต๊อก'),
      ('IsActive', 'สถานะ'),
    ],
    '53003' => [
      ('code', 'รหัส'),
      ('name', 'สินค้า'),
      ('price', 'ราคาขาย'),
      ('selected', 'เปิดขาย'),
    ],
    '53004' => [
      ('ItemName', 'สินค้า'),
      ('ItemTypeCode', 'ประเภทสินค้า'),
      ('Rate', 'อัตรา (%)'),
    ],
    '53005' => [
      ('code', 'รหัสนักเรียน'),
      ('name', 'นักเรียน'),
      ('Kind', 'ประเภท'),
      ('DisplaySuffix', 'ท้ายบัตร'),
      ('IsActive', 'สถานะ'),
    ],
    '53006' => [
      ('code', 'เลขอ้างอิง'),
      ('name', 'ร้านค้า'),
      ('status', 'สถานะ'),
    ],
    '53007' => [
      ('code', 'รหัสนักเรียน'),
      ('name', 'นักเรียน'),
      ('balance', 'ยอด Wallet'),
    ],
    '53009' => [
      ('code', 'ใบขาย'),
      ('student', 'นักเรียน'),
      ('total', 'ยอดขาย'),
      ('refunded', 'คืนแล้ว'),
    ],
    _ => [
      ('name', 'รายการ'),
      ('gross', 'ยอดขาย'),
      ('refunds', 'คืนสินค้า'),
      ('commission', 'ค่าหัก'),
      ('payable', 'ยอดสุทธิ'),
    ],
  };
  Widget cell(FoodRow row, String key) {
    if (code == '53003' && key == 'price') {
      return SizedBox(
        width: 110,
        child: TextField(
          controller: priceControllers[(row['id'] as num).toInt()],
          enabled: can('edit') && !saving,
          style: foodTokens().inputStyle,
          keyboardType: TextInputType.number,
          decoration: foodDecoration('บาท'),
        ),
      );
    }
    if (code == '53003' && key == 'selected') {
      return Checkbox(
        value: row[key] == true,
        onChanged: can('edit') && !saving
            ? (v) => setState(() => row[key] = v)
            : null,
      );
    }
    final v = row[key];
    return Text(
      v == null
          ? '—'
          : v is bool
          ? (v ? 'ใช้งาน' : 'ไม่ใช้งาน')
          : v.toString(),
      style: foodTokens().tableStyle,
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget rowActions(FoodRow row) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (code == '53006' && can('view'))
        IconButton(
          tooltip: 'เปิดใบโอน',
          icon: const Icon(Icons.description_outlined),
          onPressed: () => setState(() {
            transferId = (row['id'] as num).toInt();
            transferOpen = true;
          }),
        ),
      if (code == '53006' &&
          can('delete') &&
          {'DRAFT', 'SENT'}.contains(row['status']))
        IconButton(
          tooltip: 'ยกเลิกใบโอน',
          onPressed: () => cancelTransfer(row),
          icon: Icon(
            Icons.cancel_outlined,
            color: Theme.of(context).colorScheme.error,
          ),
        ),
      if (code == '53002' && can('edit'))
        IconButton(
          tooltip: 'แก้ไขร้านค้า',
          onPressed: () => shopForm(row),
          icon: const Icon(Icons.edit_outlined),
        ),
      if (code == '53002' && can('view'))
        IconButton(
          tooltip: 'ผู้ใช้ร้านค้า',
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => FoodPagedDialog(
              kind: FoodPagedKind.shopUsers,
              id: (row['id'] as num).toInt(),
              title: '$title > ผู้ใช้ร้านค้า (${row['name']})',
              editable: can('edit'),
            ),
          ),
          icon: const Icon(Icons.people_outline),
        ),
      if (code == '53002' && can('delete'))
        IconButton(
          tooltip: 'ลบร้านค้า',
          onPressed: () => deleteShop(row),
          icon: Icon(
            Icons.delete_outline,
            color: Theme.of(context).colorScheme.error,
          ),
        ),
      if (code == '53005' && can('edit'))
        IconButton(
          tooltip: row['IsActive'] == true ? 'ระงับบัตร' : 'เปิดใช้บัตร',
          onPressed: () async {
            try {
              await write('identifiers/${row['id']}/status', {
                'requestKey': foodKey(),
                'isActive': row['IsActive'] != true,
              }, put: true);
            } catch (e) {
              if (mounted) {
                foodMessage(
                  context,
                  message:
                      'เปลี่ยนสถานะไม่สำเร็จ\nรายละเอียดเพิ่มเติม: ${foodError(e)}',
                  error: true,
                );
              }
            }
          },
          icon: const Icon(Icons.block),
        ),
      if (code == '53007' && can('topup'))
        IconButton(
          tooltip: 'เติมเงิน',
          onPressed: () => walletForm(row),
          icon: const Icon(Icons.add_card),
        ),
      if (code == '53007' && can('view'))
        IconButton(
          tooltip: 'ประวัติ Wallet',
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => FoodPagedDialog(
              kind: FoodPagedKind.wallet,
              id: (row['id'] as num).toInt(),
              title: '$title > ประวัติ (${row['name']})',
            ),
          ),
          icon: const Icon(Icons.history),
        ),
      if (code == '53007' && can('adjust'))
        IconButton(
          tooltip: 'ปรับยอด Wallet',
          icon: const Icon(Icons.tune),
          onPressed: () => walletForm(row, adjust: true),
        ),
      if (code == '53009')
        IconButton(
          tooltip: 'ดูใบขายและคืนสินค้า',
          onPressed: () => saleDetail(row),
          icon: const Icon(Icons.visibility_outlined),
        ),
    ],
  );
  Widget _list(bool cardMode) {
    if (rows.isEmpty) {
      return LaooSurfaceCard(
        tokens: foodTokens(),
        child: const Center(child: Text('ไม่พบข้อมูลตามเงื่อนไข')),
      );
    }
    if (cardMode) {
      return ListView.separated(
        itemCount: rows.length,
        separatorBuilder: (_, i) => SizedBox(height: foodTokens().itemSpacing),
        itemBuilder: (context, i) => LaooSurfaceCard(
          tokens: foodTokens(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'รายการ ${(page - 1) * 10 + i + 1}',
                      style: foodTokens().sectionStyle,
                    ),
                  ),
                  rowActions(rows[i]),
                ],
              ),
              for (final c in columns)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 100,
                        child: Text(c.$2, style: foodTokens().tableStyle),
                      ),
                      Expanded(child: cell(rows[i], c.$1)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );
    }
    return LaooTableCard(
      tokens: foodTokens(),
      child: LaooWorkspaceDataTable(
        tokens: foodTokens(),
        headingRowColor: WidgetStatePropertyAll(
          foodTokens().primaryColor.withValues(alpha: .1),
        ),
        columns: [
          const DataColumn(label: Text('ID')),
          const DataColumn(label: Text('Action')),
          for (final c in columns) DataColumn(label: Text(c.$2)),
        ],
        rows: [
          for (var i = 0; i < rows.length; i++)
            DataRow(
              cells: [
                DataCell(Text('${(page - 1) * 10 + i + 1}')),
                DataCell(rowActions(rows[i])),
                for (final c in columns)
                  DataCell(
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 340),
                      child: cell(rows[i], c.$1),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> shopForm([FoodRow? row]) => foodForm(
    context,
    title: '$title > ${row == null ? 'เพิ่ม' : 'แก้ไข'}',
    keepOpen: row == null,
    fields: [
      FoodField('isActive', 'สถานะ', initial: '${row?['IsActive'] ?? true}'),
      FoodField(
        'code',
        'รหัสร้าน',
        initial: '${row?['code'] ?? ''}',
        maxLength: 30,
      ),
      FoodField('name', 'ชื่อร้าน', initial: '${row?['name'] ?? ''}'),
      FoodField(
        'trackStock',
        'เก็บสต๊อก',
        choices: const {'true': 'เก็บสต๊อก', 'false': 'ไม่เก็บสต๊อก'},
        initial: '${row?['TrackStock'] ?? false}',
      ),
      FoodField(
        'warehouseID',
        'คลังร้าน',
        required: false,
        choices: {
          '': 'ไม่เลือก',
          for (final w in foodRows(options['warehouses']))
            '${w['id']}': '${w['name']}',
        },
        initial: '${row?['WarehouseID'] ?? ''}',
      ),
      FoodField(
        'commissionRate',
        'อัตราหักของร้าน (%)',
        numeric: true,
        required: false,
        initial: '${row?['CommissionRate'] ?? ''}',
      ),
    ],
    save: (data) => write(row == null ? 'shops' : 'shops/${row['id']}', {
      ...data,
      'isActive': data['isActive'] == 'true',
      'trackStock': data['trackStock'] == 'true',
      'warehouseID': int.tryParse(data['warehouseID'].toString()),
    }, put: row != null),
  );
  Future<void> credentialForm() => foodForm(
    context,
    title: '$title > กำหนดบัญชีนักเรียน',
    fields: [
      const FoodField('isActive', 'สถานะ', initial: 'true'),
      FoodField(
        'studentID',
        'นักเรียน',
        numeric: true,
        lookup: '$base/lookups/53005/students',
      ),
      const FoodField(
        'newPassword',
        'รหัสผ่านเริ่มต้น',
        secret: true,
        maxLength: 256,
      ),
    ],
    save: (data) => write('students/${data['studentID']}/credential', {
      'newPassword': data['newPassword'],
      'isActive': data['isActive'] == 'true',
    }, put: true),
  );
  Future<void> identifierForm() => foodForm(
    context,
    title: '$title > เพิ่ม',
    keepOpen: true,
    fields: [
      FoodField(
        'studentID',
        'นักเรียน',
        numeric: true,
        lookup: '$base/lookups/$code/students',
      ),
      const FoodField(
        'kind',
        'ประเภท',
        choices: {'CARD': 'บัตรนักเรียน', 'QR': 'QR / Barcode'},
        initial: 'CARD',
      ),
      const FoodField('value', 'รหัสจากเครื่องอ่าน', maxLength: 256),
    ],
    save: (data) => write('identifiers', data),
  );
  Future<void> walletForm(FoodRow row, {bool adjust = false}) => foodForm(
    context,
    title: '$title > ${adjust ? 'ปรับยอด' : 'เติมเงิน'}',
    fields: [
      const FoodField('amount', 'จำนวนเงิน', numeric: true),
      const FoodField('referenceNo', 'เลขอ้างอิง', maxLength: 100),
      const FoodField(
        'paymentMethod',
        'วิธีรับเงิน',
        choices: {'CASH': 'เงินสด', 'TRANSFER': 'โอนเงิน'},
        initial: 'CASH',
      ),
      FoodField(
        'reason',
        adjust ? 'เหตุผลการปรับยอด' : 'หมายเหตุ',
        required: adjust,
        maxLength: 500,
      ),
    ],
    save: (data) => write('wallets/${row['id']}/entries', {
      'kind': adjust ? 'ADJUST' : 'TOPUP',
      ...data,
    }),
  );
  Future<void> commissionForm() => foodForm(
    context,
    title: '$title > กำหนดรายสินค้า',
    fields: [
      FoodField(
        'itemID',
        'สินค้า',
        numeric: true,
        lookup: '$base/lookups/$code/items',
      ),
      const FoodField('rate', 'อัตราหัก (%)', numeric: true, required: false),
    ],
    save: (data) => write('shops/$shop/commission', {
      ...data,
      'itemTypeCode': null,
    }, put: true),
  );
  Future<void> commissionTypeForm() => foodForm(
    context,
    title: '$title > กำหนดตามประเภทสินค้า',
    fields: [
      FoodField(
        'itemTypeCode',
        'ประเภทสินค้า',
        lookup: '$base/lookups/$code/categories',
      ),
      const FoodField('rate', 'อัตราหัก (%)', numeric: true, required: false),
    ],
    save: (data) =>
        write('shops/$shop/commission', {...data, 'itemID': null}, put: true),
  );
  Future<void> saveItems() async {
    final items = <FoodRow>[];
    for (final row in rows) {
      final price = double.tryParse(
        priceControllers[(row['id'] as num).toInt()]!.text,
      );
      if (price == null || price <= 0) {
        foodMessage(
          context,
          message: 'ราคาขายไม่ถูกต้อง\nรายละเอียดเพิ่มเติม: กรอกจำนวนมากกว่า 0',
          error: true,
        );
        return;
      }
      items.add({
        'itemID': row['id'],
        'price': price,
        'selected': row['selected'] == true,
      });
    }
    setState(() => saving = true);
    try {
      await write('shops/$shop/items', {
        'requestKey': pendingKey ??= foodKey(),
        'items': items,
      }, put: true);
      pendingKey = null;
    } catch (e) {
      if (mounted) {
        foodMessage(
          context,
          message: 'บันทึกไม่สำเร็จ\nรายละเอียดเพิ่มเติม: ${foodError(e)}',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> saleDetail(FoodRow row) async {
    try {
      final data = foodMap(await api.get('$base/sales/${row['id']}'));
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialog) => LaooActionDialog(
          tokens: foodTokens(),
          icon: Icons.receipt_long,
          title: '$title > ${row['code']}',
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final item in foodRows(data['items']))
                ListTile(
                  title: Text('${item['name']}'),
                  subtitle: Text(
                    'ขาย ${item['Quantity']} · คืนแล้ว ${item['ReturnedQuantity']} · ${item['NetAmount']} บาท',
                  ),
                  trailing:
                      can('refund') &&
                          item['ReturnedQuantity'] < item['Quantity']
                      ? IconButton(
                          tooltip: 'คืนสินค้า',
                          icon: const Icon(Icons.undo),
                          onPressed: () async {
                            await foodForm(
                              dialog,
                              title: 'คืนสินค้า > ${item['name']}',
                              fields: [
                                const FoodField(
                                  'quantity',
                                  'จำนวนคืน',
                                  numeric: true,
                                ),
                                const FoodField(
                                  'reason',
                                  'เหตุผล',
                                  maxLength: 500,
                                ),
                              ],
                              save: (d) => write('sales/${row['id']}/refunds', {
                                'requestKey': d['requestKey'],
                                'reason': d['reason'],
                                'items': [
                                  {
                                    'saleItemID': item['id'],
                                    'quantity': d['quantity'],
                                  },
                                ],
                              }),
                            );
                            if (dialog.mounted) Navigator.pop(dialog);
                          },
                        )
                      : null,
                ),
            ],
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(dialog),
              child: const Text('ปิด'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        foodMessage(
          context,
          message: 'เปิดใบขายไม่สำเร็จ\nรายละเอียดเพิ่มเติม: ${foodError(e)}',
          error: true,
        );
      }
    }
  }
}
