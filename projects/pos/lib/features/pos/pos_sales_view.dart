import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pos_api.dart';
import 'pos_feature_host.dart';
import 'pos_ui.dart';

class PosSalesView extends StatefulWidget {
  const PosSalesView({super.key, required this.api, required this.actions});
  final PosApi api;
  final Map<String, dynamic> actions;
  @override
  State<PosSalesView> createState() => _SalesState();
}

class _SalesState extends State<PosSalesView> {
  final search = TextEditingController();
  final memberCode = TextEditingController();
  Map<String, dynamic>? sportMember;
  bool findingMember = false;
  String? activation;
  Map<String, dynamic>? terminal;
  List<Map<String, dynamic>> products = [];
  final cart = <int, Map<String, dynamic>>{};
  bool loading = true, paying = false;
  String? pendingSaleKey, pendingSignature;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    search.dispose();
    memberCode.dispose();
    super.dispose();
  }

  Future<void> _findMember() async {
    if (activation == null || memberCode.text.trim().isEmpty || findingMember) {
      return;
    }
    setState(() => findingMember = true);
    try {
      final found = await widget.api.sportMember(memberCode.text.trim());
      final next = await widget.api.products(
        activation!,
        sportMemberId: (found['id'] as num).toInt(),
      );
      if (!mounted) return;
      setState(() {
        sportMember = found;
        products = next;
        cart.clear();
      });
    } catch (e) {
      if (mounted) {
        memberCode.text = sportMember?['code']?.toString() ?? '';
        showPosMessage(
          context,
          message: 'ตรวจสมาชิกไม่สำเร็จ: $e',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => findingMember = false);
    }
  }

  Future<void> _clearMember() async {
    if (activation == null) return;
    final next = await widget.api.products(activation!);
    if (!mounted) return;
    setState(() {
      sportMember = null;
      memberCode.clear();
      products = next;
      cart.clear();
    });
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    activation = p.getString('laoo.pos.activation_id');
    if (activation == null) {
      if (mounted) setState(() => loading = false);
      return;
    }
    try {
      terminal = await widget.api.bootstrap(activation!);
      products = await widget.api.products(
        activation!,
        sportMemberId: (sportMember?['id'] as num?)?.toInt(),
      );
      if (mounted) setState(() => loading = false);
    } catch (_) {
      if (mounted) {
        setState(() {
          activation = null;
          loading = false;
        });
      }
    }
  }

  Future<void> _activate() async {
    final c = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (dc) => PosDialog(
        title: 'ขายหน้าร้าน > เปิดใช้งานเครื่อง',
        icon: Icons.devices_outlined,
        content: TextField(
          controller: c,
          decoration: posInput('Terminal Activation ID *'),
        ),
        onSave: () => Navigator.pop(dc, c.text.trim()),
      ),
    );
    c.dispose();
    if (value == null || value.isEmpty) return;
    final p = await SharedPreferences.getInstance();
    await p.setString('laoo.pos.activation_id', value);
    setState(() {
      loading = true;
      activation = value;
    });
    await _load();
  }

  void _add(Map<String, dynamic> x) {
    final id = x['id'] as int,
        stock = (x['stock'] as num?)?.toDouble() ?? 0,
        price = (x['price'] as num?)?.toDouble() ?? 0;
    if (price <= 0 || stock <= 0) return;
    setState(() {
      final row = cart[id];
      if (row == null) {
        cart[id] = {...x, 'quantity': 1.0};
      } else {
        row['quantity'] = (row['quantity'] as double) + 1;
      }
    });
  }

  double get total => cart.values.fold(
    0,
    (v, x) => v + ((x['price'] as num).toDouble() * (x['quantity'] as double)),
  );
  double get payable {
    final taxRate = (terminal?['taxPercent'] as num?)?.toDouble() ?? 0;
    final tax = (total * taxRate).round() / 100;
    return total + tax;
  }

  Future<void> _pay() async {
    if (cart.isEmpty || activation == null) return;
    setState(() => paying = true);
    try {
      final ordered = cart.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key));
      final itemsSignature = ordered
          .map((entry) => "${entry.key}:${entry.value['quantity']}")
          .join('|');
      final signature = "${sportMember?['id'] ?? '-'}|$itemsSignature";
      if (pendingSignature != signature) {
        pendingSignature = signature;
        pendingSaleKey = _requestId();
      }
      final result = await widget.api.finalize({
        'activationID': activation,
        'idempotencyKey': pendingSaleKey,
        'items': cart.values
            .map((x) => {'itemID': x['id'], 'quantity': x['quantity']})
            .toList(),
        'discountAmount': 0,
        'paymentCode': 'CASH',
        'receivedAmount': payable,
        'paymentReference': null,
        'customerID': null,
        'sportMemberID': sportMember?['id'],
      });
      if (mounted) {
        pendingSaleKey = null;
        pendingSignature = null;
        showPosMessage(
          context,
          message: 'ชำระเงินแล้ว · ${result['receipt'] ?? ''}',
        );
        setState(() {
          cart.clear();
          sportMember = null;
          memberCode.clear();
        });
        try {
          final next = await widget.api.products(activation!);
          if (mounted) setState(() => products = next);
        } catch (_) {
          if (mounted) {
            showPosMessage(
              context,
              message: 'ขายสำเร็จแล้ว แต่โหลดสต๊อกล่าสุดไม่สำเร็จ',
              error: true,
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        showPosMessage(context, message: 'ชำระเงินไม่สำเร็จ: $e', error: true);
      }
    } finally {
      if (mounted) setState(() => paying = false);
    }
  }

  String _requestId() {
    final value = DateTime.now().microsecondsSinceEpoch
        .toRadixString(16)
        .padLeft(12, '0');
    return '00000000-0000-4000-8000-${value.substring(value.length - 12)}';
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (activation == null || terminal == null) {
      return Center(
        child: posCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.devices_outlined, size: 48),
              const SizedBox(height: 12),
              Text(
                'เครื่องนี้ยังไม่ได้เปิดใช้งาน',
                style: posUiTokens.sectionStyle,
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                style: posFilledStyle(),
                onPressed: _activate,
                icon: const Icon(Icons.power_settings_new),
                label: const Text('เปิดใช้งานเครื่องนี้'),
              ),
            ],
          ),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, c) {
        final compact = c.maxWidth < 900;
        final catalog = _catalog();
        final basket = _basket();
        return Column(
          children: [
            posCard(
              child: Wrap(
                spacing: 24,
                runSpacing: 8,
                children: [
                  Text('สาขา ${terminal!['branchNameTH'] ?? ''}'),
                  Text('จุดขาย ${terminal!['outletName'] ?? ''}'),
                  Text('เครื่อง ${terminal!['terminalCode'] ?? ''}'),
                  Text(
                    terminal!['shiftId'] == null
                        ? 'ยังไม่เปิดกะ'
                        : 'กะเปิดอยู่',
                    style: TextStyle(
                      color: terminal!['shiftId'] == null
                          ? Colors.red
                          : posUiTokens.primaryColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: posUiTokens.sectionSpacing),
            posCard(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: [
                  SizedBox(
                    width: compact
                        ? (c.maxWidth - 32).clamp(180.0, 320.0)
                        : 280,
                    child: TextField(
                      controller: memberCode,
                      onSubmitted: (_) => _findMember(),
                      decoration: posInput(
                        'รหัสสมาชิกกีฬา',
                        icon: Icons.card_membership_outlined,
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    style: posFilledStyle(),
                    onPressed: findingMember ? null : _findMember,
                    icon: const Icon(Icons.person_search_outlined),
                    label: Text(findingMember ? 'กำลังตรวจ' : 'ตรวจสมาชิก'),
                  ),
                  if (sportMember != null) ...[
                    Text(
                      "${sportMember!['name']} · ${sportMember!['level']}",
                      style: TextStyle(
                        color: posUiTokens.primaryColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    OutlinedButton.icon(
                      style: posOutlinedStyle(),
                      onPressed: _clearMember,
                      icon: const Icon(Icons.close),
                      label: const Text('ขายราคาปกติ'),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(height: posUiTokens.sectionSpacing),
            Expanded(
              child: compact
                  ? DefaultTabController(
                      length: 2,
                      child: Column(
                        children: [
                          TabBar(
                            labelColor: posUiTokens.primaryColor,
                            tabs: const [
                              Tab(text: 'สินค้า'),
                              Tab(text: 'ตะกร้า'),
                            ],
                          ),
                          Expanded(
                            child: TabBarView(children: [catalog, basket]),
                          ),
                        ],
                      ),
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(flex: 3, child: catalog),
                        SizedBox(width: posUiTokens.sectionSpacing),
                        Expanded(flex: 2, child: basket),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _catalog() => posCard(
    child: Column(
      children: [
        TextField(
          controller: search,
          onSubmitted: (_) async {
            products = await widget.api.products(
              activation!,
              search: search.text,
              sportMemberId: (sportMember?['id'] as num?)?.toInt(),
            );
            setState(() {});
          },
          decoration: posInput(
            'สแกนบาร์โค้ด หรือค้นหาสินค้า',
            icon: Icons.search,
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 280,
              mainAxisExtent: 150,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
            ),
            itemCount: products.length,
            itemBuilder: (_, i) {
              final x = products[i],
                  price = (x['price'] as num?)?.toDouble() ?? 0,
                  stock = (x['stock'] as num?)?.toDouble() ?? 0,
                  disabled = price <= 0 || stock <= 0;
              return InkWell(
                onTap: disabled ? null : () => _add(x),
                child: Container(
                  padding: posUiTokens.cardPadding,
                  decoration: BoxDecoration(
                    color: disabled ? Colors.grey.shade100 : Colors.white,
                    border: Border.all(color: posUiTokens.borderColor),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (x['code'] ?? '').toString(),
                        style: const TextStyle(fontSize: 12),
                      ),
                      Expanded(
                        child: Text(
                          (x['name'] ?? '').toString(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text(
                        price <= 0
                            ? 'ยังไม่มีราคา'
                            : '฿${price.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: disabled
                              ? Colors.black54
                              : posUiTokens.primaryColor,
                        ),
                      ),
                      Text(
                        stock <= 0
                            ? 'สินค้าหมด'
                            : 'คงเหลือ ${stock.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: stock <= 0 ? Colors.red : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
  Widget _basket() => posCard(
    child: Column(
      children: [
        Row(
          children: [
            Expanded(child: Text('รายการขาย', style: posUiTokens.sectionStyle)),
            TextButton(
              onPressed: () => setState(() => cart.clear()),
              child: const Text('ล้างตะกร้า'),
            ),
          ],
        ),
        Expanded(
          child: cart.isEmpty
              ? const Center(child: Text('สแกนหรือแตะสินค้าเพื่อเริ่มขาย'))
              : ListView(
                  children: cart.values
                      .map(
                        (x) => ListTile(
                          title: Text((x['name'] ?? '').toString()),
                          subtitle: Text('จำนวน ${x['quantity']}'),
                          trailing: Text(
                            '฿${((x['price'] as num).toDouble() * (x['quantity'] as double)).toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
        ),
        Row(
          children: [
            const Text(
              'ยอดสินค้า',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            Text(
              '฿${total.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w700,
                color: posUiTokens.primaryColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 64,
          child: FilledButton.icon(
            style: posFilledStyle(),
            onPressed: widget.actions['finalize'] == true && !paying
                ? _pay
                : null,
            icon: const Icon(Icons.payments_outlined),
            label: Text(paying ? 'กำลังชำระ' : 'ชำระเงิน'),
          ),
        ),
      ],
    ),
  );
}

class PosShiftView extends StatefulWidget {
  const PosShiftView({super.key, required this.api, required this.actions});
  final PosApi api;
  final Map<String, dynamic> actions;
  @override
  State<PosShiftView> createState() => _PosShiftViewState();
}

class _PosShiftViewState extends State<PosShiftView> {
  List<Map<String, dynamic>> rows = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    rows = await widget.api.list('shifts');
    if (mounted) setState(() => loading = false);
  }

  Future<void> _open() async {
    final prefs = await SharedPreferences.getInstance();
    final activation = prefs.getString('laoo.pos.activation_id');
    if (activation == null) {
      if (mounted) {
        showPosMessage(
          context,
          message: 'กรุณาเปิดใช้งานเครื่องที่หน้าขายหน้าร้านก่อน',
          error: true,
        );
      }
      return;
    }
    final cash = TextEditingController(text: '0');
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => PosDialog(
        title: 'กะขายหน้าร้าน > เปิดกะ',
        icon: Icons.lock_open_outlined,
        content: TextField(
          controller: cash,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: posInput('เงินสดเริ่มต้น *'),
        ),
        onSave: () async {
          try {
            await widget.api.action(
              'shifts/open',
              body: {
                'activationID': activation,
                'openingCash': double.tryParse(cash.text) ?? 0,
              },
            );
            if (dialogContext.mounted) Navigator.pop(dialogContext);
            await _load();
            if (mounted) showPosMessage(context, message: 'เปิดกะแล้ว');
          } catch (e) {
            if (mounted) {
              showPosMessage(
                context,
                message: 'เปิดกะไม่สำเร็จ: $e',
                error: true,
              );
            }
          }
        },
      ),
    );
    cash.dispose();
  }

  Future<void> _close(Map<String, dynamic> row) async {
    final counted = TextEditingController(
      text: (row['expectedCash'] ?? row['openingCash'] ?? 0).toString(),
    );
    final remark = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => PosDialog(
        title: 'กะขายหน้าร้าน > ปิดกะ',
        icon: Icons.lock_outline,
        content: Column(
          children: [
            TextField(
              controller: counted,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: posInput('ยอดเงินสดที่นับได้ *'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: remark,
              maxLines: 3,
              decoration: posInput('หมายเหตุ'),
            ),
          ],
        ),
        onSave: () async {
          try {
            await widget.api.action(
              'shifts/${row['id']}/close',
              body: {
                'countedCash': double.tryParse(counted.text) ?? 0,
                'remark': remark.text.trim(),
              },
            );
            if (dialogContext.mounted) Navigator.pop(dialogContext);
            await _load();
            if (mounted) showPosMessage(context, message: 'ปิดกะแล้ว');
          } catch (e) {
            if (mounted) {
              showPosMessage(
                context,
                message: 'ปิดกะไม่สำเร็จ: $e',
                error: true,
              );
            }
          }
        },
      ),
    );
    counted.dispose();
    remark.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    return posCard(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text('กะเงินสด', style: posUiTokens.sectionStyle),
              ),
              if (widget.actions['create'] == true)
                FilledButton.icon(
                  style: posFilledStyle(),
                  onPressed: _open,
                  icon: const Icon(Icons.lock_open_outlined),
                  label: const Text('เปิดกะ'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: rows.isEmpty
                ? const Center(child: Text('ยังไม่มีกะขายหน้าร้าน'))
                : ListView.separated(
                    itemCount: rows.length,
                    separatorBuilder: (_, _) =>
                        Divider(color: posUiTokens.borderColor),
                    itemBuilder: (_, index) {
                      final row = rows[index];
                      final details = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (row['code'] ?? '').toString(),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            '${row['outlet'] ?? ''} · ${row['terminal'] ?? ''}',
                          ),
                        ],
                      );
                      final actions = Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        children: [
                          Text(
                            (row['status'] ?? '').toString(),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          if (row['status'] == 'OPEN' &&
                              widget.actions['finalize'] == true)
                            OutlinedButton(
                              style: posOutlinedStyle(),
                              onPressed: () => _close(row),
                              child: const Text('ปิดกะ'),
                            ),
                        ],
                      );
                      return LayoutBuilder(
                        builder: (context, constraints) {
                          final compact = constraints.maxWidth < 560;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: compact
                                ? Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      details,
                                      const SizedBox(height: 8),
                                      actions,
                                    ],
                                  )
                                : Row(
                                    children: [
                                      Expanded(child: details),
                                      actions,
                                    ],
                                  ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class PosReturnView extends StatefulWidget {
  const PosReturnView({super.key, required this.api, required this.actions});
  final PosApi api;
  final Map<String, dynamic> actions;
  @override
  State<PosReturnView> createState() => _PosReturnViewState();
}

class _PosReturnViewState extends State<PosReturnView> {
  List<Map<String, dynamic>> rows = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    rows = await widget.api.list('sales');
    if (mounted) setState(() => loading = false);
  }

  Future<String?> _reason(String title) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => PosDialog(
        title: title,
        icon: Icons.assignment_return_outlined,
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: posInput('เหตุผล *'),
        ),
        onSave: () {
          if (controller.text.trim().isNotEmpty) {
            Navigator.pop(dialogContext, controller.text.trim());
          }
        },
      ),
    );
    controller.dispose();
    return value;
  }

  Future<void> _returnAll(Map<String, dynamic> row) async {
    final detail = await widget.api.sale(row['id']);
    final lines = (detail['items'] as List? ?? const [])
        .whereType<Map>()
        .map(Map<String, dynamic>.from)
        .where(
          (x) =>
              ((x['quantity'] as num?)?.toDouble() ?? 0) >
              ((x['returnedQuantity'] as num?)?.toDouble() ?? 0),
        )
        .toList();
    if (lines.isEmpty) {
      if (mounted) {
        showPosMessage(
          context,
          message: 'ไม่มีสินค้าคงเหลือให้คืน',
          error: true,
        );
      }
      return;
    }
    final reason = await _reason('คืนสินค้า > คืนคงเหลือทั้งใบ');
    if (reason == null) return;
    try {
      await widget.api.create('returns', {
        'saleID': row['id'],
        'items': lines
            .map(
              (x) => {
                'saleItemID': x['id'],
                'quantity':
                    ((x['quantity'] as num).toDouble() -
                    ((x['returnedQuantity'] as num?)?.toDouble() ?? 0)),
              },
            )
            .toList(),
        'paymentCode': 'CASH',
        'reason': reason,
      });
      await _load();
      if (mounted) {
        showPosMessage(context, message: 'คืนสินค้าและปรับสต็อกแล้ว');
      }
    } catch (e) {
      if (mounted) {
        showPosMessage(context, message: 'คืนสินค้าไม่สำเร็จ: $e', error: true);
      }
    }
  }

  Future<void> _cancel(Map<String, dynamic> row) async {
    final reason = await _reason('ยกเลิกใบขาย');
    if (reason == null) return;
    try {
      await widget.api.action(
        'sales/${row['id']}/cancel',
        body: {'reason': reason},
      );
      await _load();
      if (mounted) {
        showPosMessage(context, message: 'ยกเลิกใบขายและคืนสต็อกแล้ว');
      }
    } catch (e) {
      if (mounted) {
        showPosMessage(context, message: 'ยกเลิกไม่สำเร็จ: $e', error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    return posCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ใบขายสำหรับคืนหรือยกเลิก', style: posUiTokens.sectionStyle),
          const SizedBox(height: 8),
          Expanded(
            child: rows.isEmpty
                ? const Center(child: Text('ยังไม่มีใบขาย'))
                : ListView.separated(
                    itemCount: rows.length,
                    separatorBuilder: (_, _) =>
                        Divider(color: posUiTokens.borderColor),
                    itemBuilder: (_, index) {
                      final row = rows[index];
                      final completed =
                          row['status'] == 'COMPLETED' ||
                          row['status'] == 'PARTIAL_RETURN';
                      final details = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (row['receipt'] ?? '').toString(),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          Text(
                            '${row['branch'] ?? ''} · ${row['outlet'] ?? ''} · ${row['status'] ?? ''}',
                          ),
                        ],
                      );
                      final actions = Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            '฿${((row['net'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          if (completed && widget.actions['create'] == true)
                            OutlinedButton(
                              style: posOutlinedStyle(),
                              onPressed: () => _returnAll(row),
                              child: const Text('คืนทั้งใบ'),
                            ),
                          if (row['status'] == 'COMPLETED' &&
                              widget.actions['cancel'] == true)
                            IconButton(
                              tooltip: 'ยกเลิกใบขาย',
                              onPressed: () => _cancel(row),
                              icon: const Icon(
                                Icons.cancel_outlined,
                                color: Colors.red,
                              ),
                            ),
                        ],
                      );
                      return LayoutBuilder(
                        builder: (context, constraints) {
                          final compact = constraints.maxWidth < 680;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: compact
                                ? Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      details,
                                      const SizedBox(height: 8),
                                      actions,
                                    ],
                                  )
                                : Row(
                                    children: [
                                      Expanded(child: details),
                                      actions,
                                    ],
                                  ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class PosReportView extends StatelessWidget {
  const PosReportView({super.key, required this.api});
  final PosApi api;
  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: api.report(),
    builder: (context, s) {
      if (!s.hasData) return const Center(child: CircularProgressIndicator());
      final rows = s.data!['summary'] as List?;
      final x = rows?.isNotEmpty == true
          ? Map<String, dynamic>.from(rows!.first as Map)
          : <String, dynamic>{};
      final branches = (s.data!['branches'] as List? ?? const [])
          .whereType<Map>()
          .map(Map<String, dynamic>.from)
          .toList();
      final daily = (s.data!['daily'] as List? ?? const [])
          .whereType<Map>()
          .map(Map<String, dynamic>.from)
          .toList();
      return posCard(
        child: ListView(
          children: [
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _metric('จำนวนใบเสร็จ', x['receiptCount']),
                _metric('ยอดขายสุทธิ', x['netSales']),
                _metric('ยอดคืนสินค้า', x['refundAmount']),
                _metric('ยกเลิก', x['cancelledCount']),
              ],
            ),
            const SizedBox(height: 24),
            Text('ยอดขายแยกตามสาขา', style: posUiTokens.sectionStyle),
            const SizedBox(height: 8),
            if (branches.isEmpty)
              const Text('ยังไม่มียอดขายในช่วงเวลา')
            else
              ...branches.map(
                (row) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text((row['branch'] ?? '').toString()),
                  subtitle: Text('จำนวนใบเสร็จ ${row['receiptCount'] ?? 0}'),
                  trailing: Text(
                    '฿${((row['amount'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 24),
            Text('ยอดขายรายวัน', style: posUiTokens.sectionStyle),
            const SizedBox(height: 8),
            if (daily.isEmpty)
              const Text('ยังไม่มียอดขายรายวัน')
            else
              ...daily.map(
                (row) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    (row['saleDate'] ?? '').toString().split('T').first,
                  ),
                  trailing: Text(
                    '฿${((row['amount'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
          ],
        ),
      );
    },
  );
  Widget _metric(String n, dynamic v) => SizedBox(
    width: 220,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(n),
        Text(
          (v ?? 0).toString(),
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w700,
            color: posUiTokens.primaryColor,
          ),
        ),
      ],
    ),
  );
}
