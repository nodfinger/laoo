import 'package:flutter/material.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';

import 'pos_api.dart';
import 'pos_feature_host.dart';
import 'pos_ui.dart';

class PosSettingsView extends StatefulWidget {
  const PosSettingsView({super.key, required this.api, required this.canEdit});
  final PosApi api;
  final bool canEdit;
  @override
  State<PosSettingsView> createState() => _SettingsState();
}

class _SettingsState extends State<PosSettingsView> {
  bool loading = true,
      saving = false,
      enabled = true,
      shift = true,
      negative = false;
  String payment = 'CASH';
  final tax = TextEditingController(), prefix = TextEditingController();
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    tax.dispose();
    prefix.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final x = await widget.api.settings();
    if (mounted) {
      setState(() {
        enabled = x['isEnabled'] != false;
        shift = x['requireOpenShift'] != false;
        negative = x['allowNegativeStock'] == true;
        tax.text = (x['taxPercent'] ?? 7).toString();
        prefix.text = (x['receiptPrefix'] ?? 'POS').toString();
        payment = (x['defaultPaymentCode'] ?? 'CASH').toString();
        loading = false;
      });
    }
  }

  Future<void> _save() async {
    setState(() => saving = true);
    try {
      await widget.api.saveSettings({
        'isEnabled': enabled,
        'requireOpenShift': shift,
        'allowNegativeStock': negative,
        'taxPercent': double.tryParse(tax.text) ?? 0,
        'receiptPrefix': prefix.text,
        'defaultPaymentCode': payment,
      });
      if (mounted) {
        showPosMessage(context, message: 'บันทึกการตั้งค่า POS แล้ว');
      }
    } catch (e) {
      if (mounted) {
        showPosMessage(context, message: 'บันทึกไม่สำเร็จ: $e', error: true);
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => loading
      ? const Center(child: CircularProgressIndicator())
      : SingleChildScrollView(
          child: posCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ค่าการทำงานปัจจุบัน', style: posUiTokens.sectionStyle),
                _sw('เปิดใช้งานระบบ POS', enabled, (v) => enabled = v),
                _sw('บังคับเปิดกะก่อนขาย', shift, (v) => shift = v),
                _sw('อนุญาตสต็อกติดลบ', negative, (v) => negative = v),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 16,
                  children: [
                    SizedBox(
                      width: 220,
                      child: TextField(
                        controller: tax,
                        enabled: widget.canEdit,
                        decoration: posInput('ภาษีมูลค่าเพิ่ม (%)'),
                      ),
                    ),
                    SizedBox(
                      width: 220,
                      child: TextField(
                        controller: prefix,
                        enabled: widget.canEdit,
                        decoration: posInput('คำนำหน้าใบเสร็จ'),
                      ),
                    ),
                    SizedBox(
                      width: 240,
                      child: DropdownButtonFormField<String>(
                        initialValue: payment,
                        decoration: posInput('วิธีชำระเริ่มต้น'),
                        items: const [
                          DropdownMenuItem(
                            value: 'CASH',
                            child: Text('เงินสด'),
                          ),
                          DropdownMenuItem(value: 'CARD', child: Text('บัตร')),
                          DropdownMenuItem(
                            value: 'TRANSFER',
                            child: Text('โอนเงิน'),
                          ),
                        ],
                        onChanged: widget.canEdit
                            ? (v) => setState(() => payment = v!)
                            : null,
                      ),
                    ),
                  ],
                ),
                if (widget.canEdit) ...[
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      style: posFilledStyle(),
                      onPressed: saving ? null : _save,
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('บันทึก'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
  Widget _sw(String label, bool value, ValueChanged<bool> save) =>
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        value: value,
        onChanged: widget.canEdit ? (v) => setState(() => save(v)) : null,
        activeThumbColor: posUiTokens.primaryColor,
      );
}

class PosOutletsView extends StatelessWidget {
  const PosOutletsView({
    super.key,
    required this.api,
    required this.actions,
    required this.options,
    required this.title,
  });
  final PosApi api;
  final Map<String, dynamic> actions, options;
  final String title;
  @override
  Widget build(BuildContext context) => _PosSimpleCrud(
    api: api,
    actions: actions,
    options: options,
    title: title,
    endpoints: const ['outlets', 'terminals'],
  );
}

class PosOutletItemsView extends StatelessWidget {
  const PosOutletItemsView({
    super.key,
    required this.api,
    required this.actions,
    required this.options,
    required this.title,
  });
  final PosApi api;
  final Map<String, dynamic> actions, options;
  final String title;
  @override
  Widget build(BuildContext context) => _PosSimpleCrud(
    api: api,
    actions: actions,
    options: options,
    title: title,
    endpoints: const ['outlet-items'],
  );
}

class _PosSimpleCrud extends StatefulWidget {
  const _PosSimpleCrud({
    required this.api,
    required this.actions,
    required this.options,
    required this.title,
    required this.endpoints,
  });
  final PosApi api;
  final Map<String, dynamic> actions;
  final Map<String, dynamic> options;
  final String title;
  final List<String> endpoints;
  @override
  State<_PosSimpleCrud> createState() => _CrudState();
}

class _CrudState extends State<_PosSimpleCrud> {
  bool loading = true;
  final data = <String, List<Map<String, dynamic>>>{};
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    for (final e in widget.endpoints) {
      data[e] = await widget.api.list(e);
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) => loading
      ? const Center(child: CircularProgressIndicator())
      : ListView.separated(
          itemCount: widget.endpoints.length,
          separatorBuilder: (_, _) =>
              SizedBox(height: posUiTokens.sectionSpacing),
          itemBuilder: (_, index) {
            final endpoint = widget.endpoints[index],
                rows = data[endpoint] ?? [];
            return Column(
              children: [
                posCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _label(endpoint),
                          style: posUiTokens.sectionStyle,
                        ),
                      ),
                      if (widget.actions['create'] == true)
                        FilledButton.icon(
                          style: posFilledStyle(),
                          onPressed: () => _openForm(endpoint),
                          icon: const Icon(Icons.add),
                          label: const Text('เพิ่ม'),
                        ),
                    ],
                  ),
                ),
                SizedBox(height: posUiTokens.sectionSpacing),
                LaooTableCard(
                  tokens: posUiTokens,
                  child: rows.isEmpty
                      ? const Center(child: Text('ยังไม่มีข้อมูล'))
                      : LaooWorkspaceDataTable(
                          tokens: posUiTokens,
                          columns: const [
                            LaooWorkspaceTableColumns.id,
                            DataColumn(
                              label: Center(child: Text('Action')),
                              columnWidth: FixedColumnWidth(100),
                            ),
                            DataColumn(label: Text('รหัส')),
                            DataColumn(label: Text('ชื่อ')),
                            DataColumn(label: Text('สาขา/จุดขาย')),
                            DataColumn(label: Text('สถานะ')),
                          ],
                          rows: List<DataRow>.generate(rows.length, (i) {
                            final row = rows[i];
                            return DataRow(
                              cells: [
                                DataCell(Text('${i + 1}')),
                                DataCell(
                                  Center(
                                    child: Wrap(
                                      spacing: 2,
                                      children: [
                                        if (widget.actions['edit'] == true)
                                          IconButton(
                                            tooltip: 'แก้ไข',
                                            onPressed: () =>
                                                _openForm(endpoint, row),
                                            icon: Icon(
                                              Icons.edit_outlined,
                                              color: posUiTokens.primaryColor,
                                            ),
                                          ),
                                        if (widget.actions['delete'] == true)
                                          IconButton(
                                            tooltip: 'ลบ',
                                            onPressed: () =>
                                                _delete(endpoint, row),
                                            icon: Icon(
                                              Icons.delete_outline,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.error,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                                DataCell(Text('${row['code'] ?? '-'}')),
                                DataCell(Text('${row['name'] ?? '-'}')),
                                DataCell(
                                  Text(
                                    '${row['branch'] ?? row['outlet'] ?? '-'}',
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    row['active'] == false ||
                                            row['isActive'] == false
                                        ? 'ปิดใช้งาน'
                                        : 'ใช้งาน',
                                  ),
                                ),
                              ],
                            );
                          }),
                        ),
                ),
                SizedBox(height: posUiTokens.sectionSpacing),
                LaooPaginationCard(
                  tokens: posUiTokens,
                  page: 1,
                  pageCount: 1,
                  pageSize: rows.isEmpty ? 20 : rows.length,
                  total: rows.length,
                  onPrevious: null,
                  onNext: null,
                ),
              ],
            );
          },
        );
  List<Map<String, dynamic>> _option(String key) {
    final value = widget.options[key];
    return value is List
        ? value.whereType<Map>().map(Map<String, dynamic>.from).toList()
        : <Map<String, dynamic>>[];
  }

  Future<void> _openForm(
    String endpoint, [
    Map<String, dynamic>? current,
  ]) async {
    final code = TextEditingController(text: current?['code']?.toString());
    final name = TextEditingController(text: current?['name']?.toString());
    final barcode = TextEditingController(
      text: current?['barcode']?.toString(),
    );
    final price = TextEditingController(text: current?['price']?.toString());
    var active = current?['active'] != false;
    var sellable = current?['sellable'] != false;
    var showStock = current?['showStock'] != false;
    int? branchId = current?['branchID'] as int?;
    int? warehouseId = current?['warehouseID'] as int?;
    int? outletId = current?['outletID'] as int?;
    int? itemId = current?['itemID'] as int?;
    String? priceLevel = current?['priceLevel']?.toString();
    final branches = _option('branches');
    final warehouses = _option('warehouses');
    final items = _option('items');
    final outlets = data['outlets'] ?? await widget.api.list('outlets');
    var saving = false;
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          final branchWarehouses = warehouses
              .where((x) => branchId == null || x['branchId'] == branchId)
              .toList();
          return PosDialog(
            title: '${widget.title} > ${current == null ? 'เพิ่ม' : 'แก้ไข'}',
            icon: current == null
                ? Icons.add_circle_outline
                : Icons.edit_outlined,
            saving: saving,
            content: Column(
              children: [
                if (endpoint == 'outlets') ...[
                  TextField(
                    controller: code,
                    decoration: posInput('รหัสจุดขาย *'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: name,
                    decoration: posInput('ชื่อจุดขาย *'),
                  ),
                  const SizedBox(height: 16),
                  _dropdown(
                    'สาขา *',
                    branchId,
                    branches,
                    (v) => setDialogState(() {
                      branchId = v;
                      warehouseId = null;
                    }),
                  ),
                  const SizedBox(height: 16),
                  _dropdown(
                    'คลังสินค้า *',
                    warehouseId,
                    branchWarehouses,
                    (v) => setDialogState(() => warehouseId = v),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String?>(
                    initialValue: priceLevel,
                    decoration: posInput('ระดับราคา'),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('ราคามาตรฐาน'),
                      ),
                      ..._option('priceLevels').map(
                        (x) => DropdownMenuItem(
                          value: x['code']?.toString(),
                          child: Text(x['code']?.toString() ?? ''),
                        ),
                      ),
                    ],
                    onChanged: (v) => priceLevel = v,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('เปิดใช้งาน'),
                    value: active,
                    onChanged: (v) => setDialogState(() => active = v),
                  ),
                ] else if (endpoint == 'terminals') ...[
                  TextField(
                    controller: code,
                    decoration: posInput('รหัสเครื่องขาย *'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: name,
                    decoration: posInput('ชื่อเครื่องขาย *'),
                  ),
                  const SizedBox(height: 16),
                  _dropdown(
                    'จุดขาย *',
                    outletId,
                    outlets,
                    (v) => setDialogState(() => outletId = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('เปิดใช้งาน'),
                    value: active,
                    onChanged: (v) => setDialogState(() => active = v),
                  ),
                ] else ...[
                  _dropdown(
                    'จุดขาย *',
                    outletId,
                    outlets,
                    (v) => setDialogState(() => outletId = v),
                  ),
                  const SizedBox(height: 16),
                  _dropdown(
                    'สินค้า *',
                    itemId,
                    items,
                    (v) => setDialogState(() => itemId = v),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: barcode,
                    decoration: posInput('บาร์โค้ด'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: price,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: posInput('ราคาขายเฉพาะจุดขาย'),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('พร้อมขาย'),
                    value: sellable,
                    onChanged: (v) => setDialogState(() => sellable = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('แสดงสต็อก'),
                    value: showStock,
                    onChanged: (v) => setDialogState(() => showStock = v),
                  ),
                ],
              ],
            ),
            onSave: () async {
              if (saving) return;
              Object body;
              if (endpoint == 'outlets') {
                if (code.text.trim().isEmpty ||
                    name.text.trim().isEmpty ||
                    branchId == null ||
                    warehouseId == null) {
                  showPosMessage(
                    context,
                    message: 'กรอกข้อมูลบังคับให้ครบ',
                    error: true,
                  );
                  return;
                }
                body = {
                  'code': code.text.trim(),
                  'name': name.text.trim(),
                  'branchID': branchId,
                  'warehouseID': warehouseId,
                  'priceLevelCode': priceLevel,
                  'isActive': active,
                };
              } else if (endpoint == 'terminals') {
                if (code.text.trim().isEmpty ||
                    name.text.trim().isEmpty ||
                    outletId == null) {
                  showPosMessage(
                    context,
                    message: 'กรอกข้อมูลบังคับให้ครบ',
                    error: true,
                  );
                  return;
                }
                body = {
                  'code': code.text.trim(),
                  'name': name.text.trim(),
                  'outletID': outletId,
                  'isActive': active,
                };
              } else {
                if (outletId == null || itemId == null) {
                  showPosMessage(
                    context,
                    message: 'เลือกจุดขายและสินค้า',
                    error: true,
                  );
                  return;
                }
                body = {
                  'outletID': outletId,
                  'itemID': itemId,
                  'barcode': barcode.text.trim().isEmpty
                      ? null
                      : barcode.text.trim(),
                  'salePriceOverride': price.text.trim().isEmpty
                      ? null
                      : double.tryParse(price.text.trim()),
                  'isSellable': sellable,
                  'showStock': showStock,
                };
              }
              setDialogState(() => saving = true);
              try {
                if (current == null) {
                  await widget.api.create(endpoint, body);
                } else {
                  await widget.api.update(endpoint, current['id'], body);
                }
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                await _load();
                if (mounted) {
                  showPosMessage(this.context, message: 'บันทึกข้อมูลแล้ว');
                }
              } catch (e) {
                setDialogState(() => saving = false);
                if (mounted) {
                  showPosMessage(
                    this.context,
                    message: 'บันทึกไม่สำเร็จ: $e',
                    error: true,
                  );
                }
              }
            },
          );
        },
      ),
    );
    code.dispose();
    name.dispose();
    barcode.dispose();
    price.dispose();
  }

  Widget _dropdown(
    String label,
    int? value,
    List<Map<String, dynamic>> rows,
    ValueChanged<int?> changed,
  ) {
    final ids = rows.map((x) => x['id']).whereType<int>().toSet();
    return DropdownButtonFormField<int>(
      initialValue: ids.contains(value) ? value : null,
      isExpanded: true,
      decoration: posInput(label),
      items: rows
          .map(
            (x) => DropdownMenuItem<int>(
              value: x['id'] as int,
              child: Text(
                ('${x['code'] ?? ''} · ${x['name'] ?? ''}'),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: changed,
    );
  }

  Future<void> _delete(String endpoint, Map<String, dynamic> row) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 32),
        title: const Text('ยืนยันการลบ', style: TextStyle(color: Colors.red)),
        content: Text('${row['code'] ?? ''} · ${row['name'] ?? ''}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('ลบ'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.api.remove(endpoint, row['id']);
      await _load();
      if (mounted) showPosMessage(context, message: 'ลบข้อมูลแล้ว');
    } catch (e) {
      if (mounted) {
        showPosMessage(context, message: 'ลบไม่สำเร็จ: $e', error: true);
      }
    }
  }

  String _label(String e) => e == 'outlets'
      ? 'จุดขาย'
      : e == 'terminals'
      ? 'เครื่องขายและ Activation ID'
      : 'สินค้าพร้อมขายตามจุดขาย';
}
