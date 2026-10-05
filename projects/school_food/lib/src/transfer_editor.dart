import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';
import 'host.dart';
import 'ui.dart';

class FoodTransferEditor extends StatefulWidget {
  const FoodTransferEditor({
    super.key,
    required this.title,
    required this.shops,
    required this.warehouses,
    required this.actions,
    required this.close,
    this.id,
  });
  final String title;
  final List<FoodRow> shops, warehouses;
  final FoodRow actions;
  final int? id;
  final VoidCallback close;
  @override
  State<FoodTransferEditor> createState() => _FoodTransferEditorState();
}

class _FoodTransferEditorState extends State<FoodTransferEditor> {
  final api = foodApi(), reference = TextEditingController();
  final form = GlobalKey<FormState>();
  final quantities = <int, TextEditingController>{};
  List<FoodRow> items = [];
  int? id, shop, warehouse;
  String status = 'DRAFT';
  String? error, key, signature;
  bool busy = false, dirty = false;
  bool get editable =>
      status == 'DRAFT' &&
      widget.actions[id == null ? 'create' : 'edit'] == true;
  @override
  void initState() {
    super.initState();
    id = widget.id;
    if (id != null) load();
  }

  @override
  void dispose() {
    reference.dispose();
    for (final c in quantities.values) {
      c.dispose();
    }
    foodDispose(api);
    super.dispose();
  }

  Future<void> load() async {
    setState(() => busy = true);
    try {
      final result = foodMap(
        await api.get('/api/company/school-food/transfers/$id'),
      );
      if (!mounted) return;
      final header = foodMap(result['header']);
      shop = (header['ShopID'] as num).toInt();
      warehouse = (header['SourceWarehouseID'] as num).toInt();
      reference.text = '${header['ReferenceNo']}';
      status = '${header['StatusCode']}';
      for (final c in quantities.values) {
        c.dispose();
      }
      quantities.clear();
      items = foodRows(result['items']);
      for (final item in items) {
        quantities[(item['ItemID'] as num).toInt()] = TextEditingController(
          text: '${item['Quantity']}',
        );
      }
      error = null;
      dirty = false;
    } catch (e) {
      error = foodError(e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> add() async {
    final item = await showDialog<FoodRow>(
      context: context,
      builder: (_) => const FoodLookup(
        path: '/api/company/school-food/lookups/53006/items',
        title: 'เลือกสินค้าโอน',
      ),
    );
    if (item == null || !mounted) return;
    final itemId = (item['id'] as num).toInt();
    if (quantities.containsKey(itemId)) return;
    setState(() {
      items.add({...item, 'ItemID': itemId});
      dirty = true;
      quantities[itemId] = TextEditingController(text: '1');
    });
  }

  Future<void> save() async {
    if (busy || !form.currentState!.validate()) return;
    if (items.isEmpty) {
      foodMessage(
        context,
        message:
            'บันทึกไม่ได้\nรายละเอียดเพิ่มเติม: เพิ่มสินค้าอย่างน้อย 1 รายการ',
        error: true,
      );
      return;
    }
    final body = <String, dynamic>{
      'shopID': shop,
      'sourceWarehouseID': warehouse,
      'referenceNo': reference.text.trim(),
      'items': [
        for (final item in items)
          {
            'itemID': item['ItemID'],
            'quantity': double.parse(
              quantities[(item['ItemID'] as num).toInt()]!.text,
            ),
          },
      ],
    };
    final next = jsonEncode({'id': id, 'body': body});
    if (signature != next) {
      signature = next;
      key = foodKey();
    }
    body['requestKey'] = key;
    setState(() => busy = true);
    try {
      final result = foodMap(
        id == null
            ? await api.post('/api/company/school-food/transfers', body: body)
            : await api.put(
                '/api/company/school-food/transfers/$id',
                body: body,
              ),
      );
      if (!mounted) return;
      id = (result['id'] as num).toInt();
      key = null;
      signature = null;
      foodMessage(context, message: 'บันทึกใบโอนแล้ว', error: false);
      await load();
    } catch (e) {
      if (mounted) {
        foodMessage(
          context,
          message: 'บันทึกไม่สำเร็จ\nรายละเอียดเพิ่มเติม: ${foodError(e)}',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> action(String action) async {
    if (busy || id == null || dirty) return;
    final next = '$id:$action';
    if (signature != next) {
      signature = next;
      key = foodKey();
    }
    setState(() => busy = true);
    try {
      await api.post(
        '/api/company/school-food/transfers/$id/$action',
        body: {'requestKey': key},
      );
      if (!mounted) return;
      key = null;
      signature = null;
      foodMessage(
        context,
        message: action == 'send' ? 'ส่งใบโอนแล้ว' : 'รับสินค้าเข้าร้านแล้ว',
        error: false,
      );
      await load();
    } catch (e) {
      if (mounted) {
        foodMessage(
          context,
          message: 'ทำรายการไม่สำเร็จ\nรายละเอียดเพิ่มเติม: ${foodError(e)}',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget choice(
    String label,
    int? value,
    List<FoodRow> source,
    ValueChanged<int?> change,
  ) {
    final known = source.any((r) => r['id'] == value);
    return DropdownButtonFormField<int>(
      initialValue: known ? value : null,
      isExpanded: true,
      decoration: foodDecoration('$label *'),
      style: foodTokens().inputStyle,
      items: [
        for (final r in source)
          DropdownMenuItem(
            value: (r['id'] as num).toInt(),
            child: Text('${r['name']}', overflow: TextOverflow.ellipsis),
          ),
      ],
      validator: (v) => v == null ? 'กรุณาเลือก$label' : null,
      onChanged: editable && !busy ? change : null,
    );
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: foodTokens().contentMargin,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LaooCaptionCard(
          tokens: foodTokens(),
          caption: '${widget.title} > ${id == null ? 'เพิ่ม' : 'เอกสาร $id'}',
          favoriteKey: '53006',
          leading: Icon(Icons.swap_horiz, color: foodTokens().primaryColor),
        ),
        SizedBox(height: foodTokens().sectionSpacing),
        Expanded(
          child: busy
              ? const Center(child: CircularProgressIndicator())
              : error != null
              ? LaooSurfaceCard(
                  tokens: foodTokens(),
                  child: Column(
                    children: [
                      Text(error!),
                      foodButton('ลองใหม่', Icons.refresh, load),
                    ],
                  ),
                )
              : Form(
                  key: form,
                  onChanged: () {
                    if (!dirty) setState(() => dirty = true);
                  },
                  child: ListView(
                    children: [
                      LaooSurfaceCard(
                        tokens: foodTokens(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'ข้อมูลหลัก · $status',
                              style: foodTokens().sectionStyle,
                            ),
                            const SizedBox(height: 16),
                            choice(
                              'ร้านปลายทาง',
                              shop,
                              widget.shops
                                  .where((s) => s['TrackStock'] == true)
                                  .toList(),
                              (v) => setState(() => shop = v),
                            ),
                            const SizedBox(height: 16),
                            choice(
                              'คลังต้นทาง',
                              warehouse,
                              widget.warehouses,
                              (v) => setState(() => warehouse = v),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: reference,
                              enabled: editable,
                              style: foodTokens().inputStyle,
                              decoration: foodDecoration('เลขอ้างอิง *'),
                              maxLength: 100,
                              validator: (v) => (v ?? '').trim().isEmpty
                                  ? 'ระบุเลขอ้างอิง'
                                  : null,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: foodTokens().sectionSpacing),
                      LaooSurfaceCard(
                        tokens: foodTokens(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'รายการสินค้า',
                              style: foodTokens().sectionStyle,
                            ),
                            if (editable)
                              Align(
                                alignment: Alignment.centerRight,
                                child: foodButton(
                                  'เพิ่มรายการ',
                                  Icons.add,
                                  items.length < 100 ? add : null,
                                  outlined: true,
                                ),
                              ),
                            for (final item in items)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text('${item['code']} · ${item['name']}'),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextFormField(
                                            controller:
                                                quantities[(item['ItemID']
                                                        as num)
                                                    .toInt()],
                                            enabled: editable,
                                            keyboardType:
                                                const TextInputType.numberWithOptions(
                                                  decimal: true,
                                                ),
                                            style: foodTokens().inputStyle,
                                            decoration: foodDecoration(
                                              'จำนวน *',
                                            ),
                                            validator: (v) {
                                              final qty = double.tryParse(
                                                v ?? '',
                                              );
                                              return qty == null ||
                                                      !qty.isFinite ||
                                                      qty <= 0 ||
                                                      qty > 1000000
                                                  ? 'ระบุจำนวนมากกว่า 0 และไม่เกิน 1,000,000'
                                                  : null;
                                            },
                                          ),
                                        ),
                                        if (editable)
                                          IconButton(
                                            tooltip: 'นำรายการออก',
                                            icon: Icon(
                                              Icons.remove_circle_outline,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.error,
                                            ),
                                            onPressed: () => setState(() {
                                              items.remove(item);
                                              dirty = true;
                                              quantities
                                                  .remove(
                                                    (item['ItemID'] as num)
                                                        .toInt(),
                                                  )
                                                  ?.dispose();
                                            }),
                                          ),
                                      ],
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
        ),
        SizedBox(height: foodTokens().sectionSpacing),
        LaooSurfaceCard(
          tokens: foodTokens(),
          child: Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              foodButton(
                'กลับรายการ',
                Icons.list,
                busy ? null : widget.close,
                outlined: true,
              ),
              if (editable)
                foodButton('บันทึก', Icons.save_outlined, busy ? null : save),
              if (id != null &&
                  status == 'DRAFT' &&
                  widget.actions['transfer'] == true)
                foodButton(
                  'ส่งใบโอน',
                  Icons.send,
                  busy || dirty ? null : () => action('send'),
                ),
              if (id != null &&
                  status == 'SENT' &&
                  widget.actions['receive'] == true)
                foodButton(
                  'รับเข้าร้าน',
                  Icons.inventory_2_outlined,
                  busy ? null : () => action('receive'),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}
