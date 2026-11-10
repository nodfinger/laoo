import 'package:flutter/material.dart';
import 'package:laoo_shared_admin_ui/laoo_shared_admin_ui.dart'
    show FilterHeightSync, filterActionHeightStyle;
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';

import '../../app/theme/laoo_design_tokens.dart';
import '../../core/api/api_client.dart';
import '../../core/navigation/navigation_menu_repository.dart';
import '../../core/widgets/timed_snack_bar.dart';
import '../company/ocr/business_card_ocr_ui.dart';
import '../support/presentation/widgets/support_workspace_shell.dart';

class TravelRouteRatesPage extends StatefulWidget {
  const TravelRouteRatesPage({super.key});
  @override
  State<TravelRouteRatesPage> createState() => _TravelRouteRatesPageState();
}

class _TravelRouteRatesPageState extends State<TravelRouteRatesPage> {
  final _api = ApiClient(), _search = TextEditingController();
  String _title = '', _query = '';
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true,
      _cards = false,
      _create = false,
      _edit = false,
      _delete = false;
  int _page = 1;
  static const _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _api.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final menu = await NavigationMenuRepository().findMenu(menuCode: '67002');
      final data = await _api.get('/api/company/travel-route-rates');
      if (!mounted) return;
      if (data is! Map || data['items'] is! List || data['vehicles'] is! List) {
        throw StateError('Invalid response');
      }
      setState(() {
        _title = menu?.name ?? '';
        _rows = (data['items'] as List)
            .whereType<Map>()
            .map((x) => Map<String, dynamic>.from(x))
            .toList();
        _create = data['create'] == true;
        _edit = data['edit'] == true;
        _delete = data['delete'] == true;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
        showTimedSnackBar(
          context,
          message:
              'โหลดค่าเดินทางระหว่างจุดไม่สำเร็จ กรุณาตรวจสอบสิทธิ์และลองใหม่',
          error: true,
        );
      }
    }
  }

  Future<void> _open([Map<String, dynamic>? row]) async {
    final origin = TextEditingController(
      text: row?['origin']?.toString() ?? '',
    );
    final destination = TextEditingController(
      text: row?['destination']?.toString() ?? '',
    );
    final distance = TextEditingController(
      text: row?['distance']?.toString() ?? '',
    );
    final form = GlobalKey<FormState>();
    bool saving = false;
    final t = businessCardOcrUi(context);
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialog) => StatefulBuilder(
        builder: (dialog, refresh) => LaooActionDialog(
          tokens: t,
          headerDividerGap: 10,
          icon: Icons.edit_outlined,
          title: '$_title > ${row == null ? 'เพิ่ม' : 'แก้ไข'}',
          content: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 2),
                TextFormField(
                  controller: origin,
                  maxLength: 200,
                  decoration: ocrInput(
                    context,
                    'สถานที่ต้นทาง *',
                  ).copyWith(counterText: ''),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'กรุณาระบุต้นทาง' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: destination,
                  maxLength: 200,
                  decoration: ocrInput(
                    context,
                    'สถานที่ปลายทาง *',
                  ).copyWith(counterText: ''),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'กรุณาระบุปลายทาง' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: distance,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: ocrInput(context, 'ระยะทาง (กม.) *'),
                  validator: _numberValidator,
                ),
                const SizedBox(height: 14),
              ],
            ),
          ),
          actions: [
            OutlinedButton(
              style: OutlinedButton.styleFrom(foregroundColor: t.primaryColor),
              onPressed: saving ? null : () => Navigator.pop(dialog),
              child: const Text('ยกเลิก'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: t.primaryColor,
                foregroundColor: Colors.white,
              ),
              onPressed: saving
                  ? null
                  : () async {
                      if (!form.currentState!.validate()) return;
                      refresh(() => saving = true);
                      final body = {
                        'origin': origin.text.trim(),
                        'destination': destination.text.trim(),
                        'distance': double.parse(distance.text),
                      };
                      try {
                        if (row == null) {
                          await _api.post(
                            '/api/company/travel-route-rates',
                            body: body,
                          );
                        } else {
                          await _api.put(
                            '/api/company/travel-route-rates/${row['id']}',
                            body: body,
                          );
                        }
                        if (!dialog.mounted) return;
                        Navigator.pop(dialog);
                        if (mounted) {
                          showTimedSnackBar(
                            context,
                            message: 'บันทึกค่าเดินทางเรียบร้อยแล้ว',
                          );
                          await _load();
                        }
                      } catch (_) {
                        if (dialog.mounted) {
                          refresh(() => saving = false);
                          showTimedSnackBar(
                            dialog,
                            message:
                                'บันทึกไม่สำเร็จ กรุณาตรวจสอบข้อมูลและสิทธิ์แล้วลองใหม่',
                            error: true,
                          );
                        }
                      }
                    },
              icon: const Icon(Icons.save_outlined),
              label: const Text('บันทึก'),
            ),
          ],
        ),
      ),
    );
    origin.dispose();
    destination.dispose();
    distance.dispose();
  }

  Future<void> _openVehicleRates(Map<String, dynamic> row) async {
    List<Map<String, dynamic>> rates;
    try {
      final result = await _api.get(
        '/api/company/travel-route-rates/${row['id']}/vehicle-rates',
      );
      rates = (result['items'] as List)
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } catch (_) {
      if (mounted) {
        showTimedSnackBar(
          context,
          message: 'โหลดอัตราประเภทรถไม่สำเร็จ กรุณาลองใหม่',
          error: true,
        );
      }
      return;
    }
    if (!mounted) return;
    final controllers = [
      for (final rate in rates)
        TextEditingController(text: rate['amount']?.toString() ?? ''),
    ];
    final form = GlobalKey<FormState>();
    final t = businessCardOcrUi(context);
    var saving = false;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialog) => StatefulBuilder(
        builder: (dialog, refresh) => LaooActionDialog(
          tokens: t,
          headerDividerGap: 10,
          icon: Icons.directions_car_outlined,
          title: 'ประเภทรถ > จำนวนเงินที่เบิกได้',
          content: Form(
            key: form,
            child: SizedBox(
              width: 560,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: t.primaryColor.withValues(alpha: .10),
                        borderRadius: BorderRadius.circular(LaooRadius.xs),
                      ),
                      child: Text(
                        '${row['origin']} → ${row['destination']}',
                        textAlign: TextAlign.left,
                        style: t.sectionStyle.copyWith(
                          color: t.primaryColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (rates.isEmpty) const Text('ไม่พบประเภทรถ'),
                    for (var i = 0; i < rates.length; i++) ...[
                      TextFormField(
                        controller: controllers[i],
                        enabled: _edit && !saving,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: ocrInput(
                          context,
                          '${rates[i]['name']} (บาท)',
                        ),
                        validator: (value) => (value?.trim().isEmpty ?? true)
                            ? null
                            : _numberValidator(value),
                      ),
                      const SizedBox(height: 14),
                    ],
                  ],
                ),
              ),
            ),
          ),
          actions: [
            OutlinedButton(
              style: OutlinedButton.styleFrom(foregroundColor: t.primaryColor),
              onPressed: saving ? null : () => Navigator.pop(dialog),
              child: const Text('ปิด'),
            ),
            if (_edit)
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: t.primaryColor,
                  foregroundColor: Colors.white,
                ),
                onPressed: saving || rates.isEmpty
                    ? null
                    : () async {
                        if (!form.currentState!.validate()) return;
                        refresh(() => saving = true);
                        try {
                          await _api.put(
                            '/api/company/travel-route-rates/${row['id']}/vehicle-rates',
                            body: {
                              'items': [
                                for (var i = 0; i < rates.length; i++)
                                  {
                                    'code': rates[i]['code'],
                                    'amount': controllers[i].text.trim().isEmpty
                                        ? null
                                        : double.parse(
                                            controllers[i].text.trim(),
                                          ),
                                  },
                              ],
                            },
                          );
                          if (!dialog.mounted) return;
                          Navigator.pop(dialog);
                          if (mounted) {
                            showTimedSnackBar(
                              context,
                              message: 'บันทึกอัตราประเภทรถเรียบร้อยแล้ว',
                            );
                          }
                        } catch (_) {
                          if (dialog.mounted) {
                            refresh(() => saving = false);
                            showTimedSnackBar(
                              dialog,
                              message:
                                  'บันทึกอัตราไม่สำเร็จ กรุณาตรวจสอบสิทธิ์และข้อมูลแล้วลองใหม่',
                              error: true,
                            );
                          }
                        }
                      },
                icon: const Icon(Icons.save_outlined),
                label: const Text('บันทึก'),
              ),
          ],
        ),
      ),
    );
    for (final controller in controllers) {
      controller.dispose();
    }
  }

  String? _numberValidator(String? text) {
    final s = text?.trim() ?? '';
    final n = double.tryParse(s);
    return n == null ||
            n < 0 ||
            n > 9999999999.99 ||
            !RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(s)
        ? 'กรุณาระบุตัวเลขไม่ติดลบ ทศนิยมไม่เกิน 2 ตำแหน่ง'
        : null;
  }

  Future<void> _remove(Map<String, dynamic> row) async {
    final danger = Theme.of(context).colorScheme.error;
    final yes = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(color: danger),
        ),
        title: Row(
          children: [
            Icon(Icons.delete_outline, color: danger),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'ยืนยันการลบข้อมูล',
                style: TextStyle(color: danger, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: danger.withValues(alpha: .1),
              child: Text('${row['origin']} → ${row['destination']}'),
            ),
            const SizedBox(height: 12),
            const Text(
              'อัตราประเภทรถของเส้นทางนี้จะถูกลบด้วย และไม่สามารถเรียกคืนได้',
            ),
            const SizedBox(height: 12),
            const Divider(thickness: .6),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: danger),
            onPressed: () => Navigator.pop(d, true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    try {
      await _api.delete('/api/company/travel-route-rates/${row['id']}');
      if (mounted) {
        showTimedSnackBar(context, message: 'ลบข้อมูลเรียบร้อยแล้ว');
        await _load();
      }
    } catch (_) {
      if (mounted) {
        showTimedSnackBar(
          context,
          message: 'ลบข้อมูลไม่สำเร็จ กรุณาตรวจสอบสิทธิ์และลองใหม่',
          error: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = businessCardOcrUi(context);
    final filtered = _rows
        .where(
          (r) => '${r['origin']} ${r['destination']}'.toLowerCase().contains(
            _query.toLowerCase(),
          ),
        )
        .toList();
    final pages = filtered.isEmpty ? 1 : (filtered.length / _pageSize).ceil();
    final page = _page.clamp(1, pages);
    final start = (page - 1) * _pageSize;
    final visible = filtered.skip(start).take(_pageSize).toList();
    Widget actions(Map<String, dynamic> row) => Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        TextButton.icon(
          style: TextButton.styleFrom(foregroundColor: t.primaryColor),
          onPressed: () => _openVehicleRates(row),
          icon: Icon(Icons.directions_car_outlined, color: t.primaryColor),
          label: const Text('ประเภทรถ'),
        ),
        if (_edit)
          IconButton(
            tooltip: 'แก้ไข',
            onPressed: () => _open(row),
            icon: Icon(Icons.edit_outlined, color: t.primaryColor),
          ),
        if (_delete)
          IconButton(
            tooltip: 'ลบ',
            onPressed: () => _remove(row),
            icon: Icon(
              Icons.delete_outline,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
      ],
    );
    return SupportWorkspaceShell(
      pageTitle: _title,
      activeMenu: 'travelRouteRates',
      menuScope: WorkspaceMenuScope.company,
      child: LayoutBuilder(
        builder: (context, box) => ColoredBox(
          color: t.backgroundColor,
          child: LaooListWorkspace(
            tokens: t,
            caption: LaooCaptionCard(
              tokens: t,
              caption: _title,
              favoriteKey: '67002',
              leading: Icon(Icons.route_outlined, color: t.primaryColor),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LaooListCardToggle(
                    tokens: t,
                    cards: _cards,
                    onChanged: (v) => setState(() => _cards = v),
                  ),
                  if (_create) const SizedBox(width: 8),
                  if (_create)
                    SizedBox(
                      height: t.buttonHeight,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: t.primaryColor,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => _open(),
                        icon: const Icon(Icons.add),
                        label: const Text('เพิ่ม'),
                      ),
                    ),
                ],
              ),
            ),
            filter: FilterHeightSync(
              builder: (context, key, height) => Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: box.maxWidth < 450 ? box.maxWidth - 45 : 340,
                    child: TextField(
                      key: key,
                      controller: _search,
                      style: t.inputStyle,
                      decoration: ocrInput(
                        context,
                        'ค้นหาต้นทาง หรือปลายทาง',
                        icon: Icons.search,
                      ),
                      onSubmitted: (_) => setState(() {
                        _query = _search.text.trim();
                        _page = 1;
                      }),
                    ),
                  ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: t.primaryColor,
                      foregroundColor: Colors.white,
                    ).merge(filterActionHeightStyle(height)),
                    onPressed: () => setState(() {
                      _query = _search.text.trim();
                      _page = 1;
                    }),
                    icon: const Icon(Icons.search),
                    label: const Text('ค้นหา'),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: t.primaryColor,
                    ).merge(filterActionHeightStyle(height)),
                    onPressed: () => setState(() {
                      _search.clear();
                      _query = '';
                      _page = 1;
                    }),
                    icon: const Icon(Icons.filter_alt_off_outlined),
                    label: const Text('ล้าง Filter'),
                  ),
                ],
              ),
            ),
            table: _loading
                ? const Center(child: CircularProgressIndicator())
                : visible.isEmpty
                ? const Center(child: Text('ไม่พบข้อมูล'))
                : _cards
                ? ColoredBox(
                    color: t.backgroundColor,
                    child: ListView.separated(
                      itemCount: visible.length,
                      separatorBuilder: (_, index) =>
                          SizedBox(height: t.sectionSpacing),
                      itemBuilder: (context, i) {
                        final r = visible[i];
                        return Card(
                          margin: EdgeInsets.zero,
                          elevation: 0,
                          color: t.surfaceColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(LaooRadius.xs),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ListTile(
                                title: Text(
                                  '${r['origin']} → ${r['destination']}',
                                ),
                                subtitle: Text('ระยะทาง ${r['distance']} กม.'),
                              ),
                              actions(r),
                            ],
                          ),
                        );
                      },
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(LaooLayout.cardPadding),
                    child: LayoutBuilder(
                      builder: (context, constraints) => SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minWidth: constraints.maxWidth,
                          ),
                          child: SingleChildScrollView(
                            child: DataTable(
                              headingTextStyle: t.tableStyle.copyWith(
                                color: t.primaryColor,
                                fontWeight: FontWeight.w700,
                              ),
                              dataTextStyle: t.tableStyle,
                              headingRowColor: WidgetStatePropertyAll(
                                t.primaryColor.withValues(alpha: .12),
                              ),
                              columns: const [
                                DataColumn(label: Text('ID')),
                                DataColumn(label: Text('Action')),
                                DataColumn(label: Text('สถานที่ต้นทาง')),
                                DataColumn(label: Text('สถานที่ปลายทาง')),
                                DataColumn(label: Text('ระยะทาง (กม.)')),
                              ],
                              rows: [
                                for (var i = 0; i < visible.length; i++)
                                  DataRow(
                                    cells: [
                                      DataCell(Text('${start + i + 1}')),
                                      DataCell(actions(visible[i])),
                                      DataCell(Text('${visible[i]['origin']}')),
                                      DataCell(
                                        Text('${visible[i]['destination']}'),
                                      ),
                                      DataCell(
                                        Text('${visible[i]['distance']}'),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
            pagination: LaooPaginationCard(
              tokens: t,
              borderless: true,
              page: page,
              pageCount: pages,
              pageSize: _pageSize,
              total: filtered.length,
              onPrevious: page > 1
                  ? () => setState(() => _page = page - 1)
                  : null,
              onNext: page < pages
                  ? () => setState(() => _page = page + 1)
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
