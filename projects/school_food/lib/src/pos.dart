import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';
import 'host.dart';
import 'ui.dart';

class FoodPos extends StatefulWidget {
  const FoodPos({super.key, required this.shops, required this.canSell});
  final List<FoodRow> shops;
  final bool canSell;
  @override
  State<FoodPos> createState() => _FoodPosState();
}

class _FoodPosState extends State<FoodPos> {
  late final api = foodApi();
  final basketRevision = ValueNotifier<int>(0);
  void updateView(VoidCallback change) {
    if (!mounted) return;
    setState(change);
    basketRevision.value++;
  }

  final card = TextEditingController(), search = TextEditingController();
  final cart = <int, FoodRow>{};
  List<FoodRow> products = [];
  FoodRow? student;
  int? shop;
  String kind = 'CARD';
  int page = 1, total = 0;
  bool loading = true, busy = false, online = false;
  String? error, requestKey, lastPayload, identifiedValue, identifiedKind;
  int? identifiedShop;
  static const base = '/api/company/school-food';
  @override
  void initState() {
    super.initState();
    shop = widget.shops.isEmpty
        ? null
        : (widget.shops.first['id'] as num).toInt();
    load();
  }

  @override
  void dispose() {
    card.dispose();
    basketRevision.dispose();
    search.dispose();
    foodDispose(api);
    super.dispose();
  }

  Future<void> load() async {
    if (shop == null) {
      updateView(() {
        loading = false;
        online = false;
      });
      return;
    }
    updateView(() => loading = true);
    try {
      final data = foodMap(
        await api.get(
          '$base/shops/$shop/products',
          query: {'page': '$page', 'pageSize': '12', 'search': search.text},
        ),
      );
      if (mounted) {
        updateView(() {
          products = foodRows(data['rows']);
          total = (data['total'] as num).toInt();
          online = true;
          error = null;
          loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        updateView(() {
          loading = false;
          online = false;
          error = foodError(e);
        });
      }
    }
  }

  Future<void> identify() async {
    if (busy || shop == null || !widget.canSell) return;
    final value = card.text.trim();
    if (value.isEmpty) {
      updateView(() {
        student = null;
        identifiedValue = null;
        error = 'กรอกเลขบัตรนักเรียน แล้วกด Enter เพื่อตรวจสอบ';
      });
      return;
    }
    final selectedKind = kind;
    final selectedShop = shop!;
    updateView(() {
      busy = true;
      student = null;
      identifiedValue = null;
      identifiedKind = null;
      identifiedShop = null;
      error = null;
    });
    try {
      final data = foodMap(
        await api.post(
          '$base/identify',
          body: {'shopID': selectedShop, 'kind': selectedKind, 'value': value},
        ),
      );
      if (mounted) {
        if (card.text.trim() != value ||
            kind != selectedKind ||
            shop != selectedShop) {
          return;
        }
        updateView(() {
          student = data;
          identifiedValue = value;
          identifiedKind = selectedKind;
          identifiedShop = selectedShop;
          online = true;
          error = null;
        });
      }
    } catch (e) {
      if (mounted &&
          card.text.trim() == value &&
          kind == selectedKind &&
          shop == selectedShop) {
        updateView(() => error = foodError(e));
      }
    } finally {
      if (mounted) updateView(() => busy = false);
    }
  }

  double get amount => cart.values.fold(
    0,
    (sum, row) =>
        sum +
        (row['price'] as num).toDouble() * (row['quantity'] as num).toInt(),
  );
  bool get canCheckout =>
      widget.canSell &&
      online &&
      !busy &&
      student != null &&
      cart.isNotEmpty &&
      identifiedValue == card.text.trim() &&
      identifiedKind == kind &&
      identifiedShop == shop;
  Future<void> checkout() async {
    if (!canCheckout) return;
    updateView(() => busy = true);
    final payload = {
      'shopID': shop,
      'identifierKind': kind,
      'identifier': identifiedValue,
      'items': cart.values
          .map(
            (r) => {
              'itemID': r['id'],
              'quantity': r['quantity'],
              'discountAmount': 0,
            },
          )
          .toList(),
    };
    final signature = jsonEncode(payload);
    if (lastPayload != signature) {
      requestKey = foodKey();
      lastPayload = signature;
    }
    try {
      final result = foodMap(
        await api.post(
          '$base/sales',
          body: {...payload, 'requestKey': requestKey},
        ),
      );
      if (!mounted) return;
      foodMessage(
        context,
        message:
            'ขายสำเร็จ ${result['receipt']} · คงเหลือ ${result['balance']} บาท',
        error: false,
      );
      updateView(() {
        cart.clear();
        student = null;
        card.clear();
        identifiedValue = null;
        identifiedKind = null;
        identifiedShop = null;
        requestKey = null;
        lastPayload = null;
      });
      await load();
    } catch (e) {
      if (!mounted) return;
      updateView(() {
        online = false;
        error = foodError(e);
      });
      foodMessage(
        context,
        message:
            'ยังยืนยันการขายไม่ได้\nรายละเอียดเพิ่มเติม: ${foodError(e)} ตรวจสอบการเชื่อมต่อแล้วลองรายการเดิมอีกครั้ง',
        error: true,
      );
    } finally {
      if (mounted) updateView(() => busy = false);
    }
  }

  void change(FoodRow item, int delta) {
    if (busy || student == null) return;
    updateView(() {
      final id = (item['id'] as num).toInt();
      final quantity = (cart[id]?['quantity'] as int? ?? 0) + delta;
      if (quantity <= 0) {
        cart.remove(id);
      } else if (quantity <= 1000) {
        cart[id] = {...item, 'quantity': quantity};
      }
    });
  }

  Widget basket() => LaooSurfaceCard(
    tokens: foodTokens(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('ตะกร้าสินค้า', style: foodTokens().sectionStyle),
        if (student != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              '${student!['name']}\n${student!['classroom']} · Wallet ${student!['balance']} บาท',
            ),
          ),
        Expanded(
          child: cart.isEmpty
              ? const Center(child: Text('แตะสินค้าเพื่อเพิ่มรายการ'))
              : ListView(
                  children: [
                    for (final item in cart.values)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              '${item['name']}',
                              style: foodTokens().tableStyle,
                            ),
                            Row(
                              children: [
                                IconButton(
                                  tooltip: 'ลดจำนวน',
                                  onPressed: busy
                                      ? null
                                      : () => change(item, -1),
                                  icon: const Icon(Icons.remove_circle_outline),
                                ),
                                Text(
                                  '${item['quantity']}',
                                  style: foodTokens().sectionStyle,
                                ),
                                IconButton(
                                  tooltip: 'เพิ่มจำนวน',
                                  onPressed: busy
                                      ? null
                                      : () => change(item, 1),
                                  icon: const Icon(Icons.add_circle_outline),
                                ),
                                Expanded(
                                  child: Text(
                                    ((item['price'] as num) *
                                            (item['quantity'] as num))
                                        .toStringAsFixed(2),
                                    textAlign: TextAlign.end,
                                  ),
                                ),
                              ],
                            ),
                            Divider(color: foodTokens().borderColor, height: 1),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
        Text('ยอดชำระ', style: foodTokens().tableStyle),
        Text(
          '${amount.toStringAsFixed(2)} บาท',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        foodButton(
          busy ? 'กำลังยืนยัน' : 'ยืนยันหัก Wallet',
          Icons.payments_outlined,
          canCheckout ? checkout : null,
        ),
        if (!widget.canSell) const Text('บัญชีนี้ไม่มีสิทธิ์ขาย'),
        if (!online) const Text('หยุดรับชำระจนกว่าจะเชื่อมต่อสำเร็จ'),
      ],
    ),
  );
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, size) {
      final narrow = size.maxWidth < 900;
      final panel = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LaooSurfaceCard(
            tokens: foodTokens(),
            child: Column(
              children: [
                DropdownButtonFormField<int>(
                  initialValue: shop,
                  isExpanded: true,
                  decoration: foodDecoration('ร้านค้า'),
                  items: widget.shops
                      .map(
                        (s) => DropdownMenuItem(
                          value: (s['id'] as num).toInt(),
                          child: Text(
                            '${s['name']}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: busy || cart.isNotEmpty
                      ? null
                      : (v) {
                          shop = v;
                          student = null;
                          identifiedValue = null;
                          identifiedKind = null;
                          identifiedShop = null;
                          card.clear();
                          page = 1;
                          load();
                        },
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    SizedBox(
                      width: 100,
                      child: DropdownButtonFormField<String>(
                        initialValue: kind,
                        isExpanded: true,
                        decoration: foodDecoration('อ่านรหัส'),
                        items: const [
                          DropdownMenuItem(value: 'CARD', child: Text('บัตร')),
                          DropdownMenuItem(value: 'QR', child: Text('QR')),
                        ],
                        onChanged: busy || !widget.canSell
                            ? null
                            : (v) => updateView(() {
                                kind = v!;
                                student = null;
                                identifiedValue = null;
                                identifiedKind = null;
                                identifiedShop = null;
                                cart.clear();
                                requestKey = null;
                                lastPayload = null;
                              }),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: card,
                        enabled: !busy && widget.canSell,
                        decoration: foodDecoration(
                          'เลขบัตรนักเรียน (จำลอง) · กด Enter',
                        ),
                        textInputAction: TextInputAction.search,
                        onChanged: (_) => updateView(() {
                          student = null;
                          identifiedValue = null;
                          identifiedKind = null;
                          identifiedShop = null;
                          error = null;
                          cart.clear();
                          requestKey = null;
                          lastPayload = null;
                        }),
                        onSubmitted: (_) => identify(),
                      ),
                    ),
                    IconButton(
                      tooltip: 'ตรวจสอบนักเรียน',
                      onPressed: busy || !widget.canSell ? null : identify,
                      icon: const Icon(Icons.person_search_outlined),
                    ),
                  ],
                ),
                if (student != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        '${student!['name']} · คงเหลือ ${student!['balance']} บาท',
                        style: foodTokens().sectionStyle,
                      ),
                    ),
                  ),
                if (student == null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        'กรอกเลขบัตรแล้วกด Enter เพื่อตรวจสอบนักเรียนก่อนเลือกสินค้า',
                        style: foodTokens().tableStyle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: foodTokens().sectionSpacing),
          if (error != null)
            LaooSurfaceCard(
              tokens: foodTokens(),
              child: Column(
                children: [
                  Text('ทำรายการไม่สำเร็จ\nรายละเอียดเพิ่มเติม: $error'),
                  foodButton(
                    'ตรวจการเชื่อมต่ออีกครั้ง',
                    Icons.replay,
                    busy ? null : load,
                  ),
                ],
              ),
            ),
          LaooFilterCard(
            tokens: foodTokens(),
            child: TextField(
              controller: search,
              enabled: !busy,
              decoration: foodDecoration('ค้นหาสินค้า').copyWith(
                suffixIcon: IconButton(
                  tooltip: 'ค้นหา',
                  onPressed: () {
                    page = 1;
                    load();
                  },
                  icon: const Icon(Icons.search),
                ),
              ),
              onSubmitted: (_) {
                page = 1;
                load();
              },
            ),
          ),
          SizedBox(height: foodTokens().sectionSpacing),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : products.isEmpty
                ? const Center(child: Text('ยังไม่มีสินค้าที่เปิดขายในร้านนี้'))
                : GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: narrow ? 2 : 3,
                      mainAxisExtent: 150,
                      crossAxisSpacing: foodTokens().itemSpacing,
                      mainAxisSpacing: foodTokens().itemSpacing,
                    ),
                    itemCount: products.length,
                    itemBuilder: (context, i) {
                      final p = products[i];
                      return LaooSurfaceCard(
                        tokens: foodTokens(),
                        child: InkWell(
                          onTap:
                              widget.canSell &&
                                  !busy &&
                                  online &&
                                  student != null
                              ? () => change(p, 1)
                              : null,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(
                                child: Text(
                                  '${p['name']}',
                                  style: foodTokens().sectionStyle,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '${p['price']} บาท',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: foodTokens().primaryColor,
                                    ),
                              ),
                              Text(
                                p['trackStock'] == true
                                    ? 'คงเหลือ ${p['stock']}'
                                    : 'ไม่เก็บสต๊อก',
                                style: foodTokens().tableStyle,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SizedBox(height: foodTokens().sectionSpacing),
          LaooPaginationCard(
            tokens: foodTokens(),
            page: page,
            pageCount: (total / 12).ceil().clamp(1, 100000),
            pageSize: 12,
            total: total,
            onPrevious: page > 1 && !loading
                ? () {
                    page--;
                    load();
                  }
                : null,
            onNext: page * 12 < total && !loading
                ? () {
                    page++;
                    load();
                  }
                : null,
          ),
          if (narrow) ...[
            SizedBox(height: foodTokens().sectionSpacing),
            foodButton(
              'ตะกร้า ${cart.length} รายการ · ${amount.toStringAsFixed(2)} บาท',
              Icons.shopping_cart_outlined,
              () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(foodTokens().radius),
                ),
                builder: (sheet) => SizedBox(
                  height: MediaQuery.sizeOf(sheet).height * .85,
                  child: ValueListenableBuilder<int>(
                    valueListenable: basketRevision,
                    builder: (sheet, revision, child) => basket(),
                  ),
                ),
              ),
            ),
          ],
        ],
      );
      return narrow
          ? panel
          : Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: panel),
                SizedBox(width: foodTokens().sectionSpacing),
                SizedBox(width: 340, child: basket()),
              ],
            );
    },
  );
}
