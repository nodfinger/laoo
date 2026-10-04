import 'package:flutter/material.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';
import 'host.dart';
import 'ui.dart';

enum FoodPagedKind { wallet, shopUsers }

class FoodPagedDialog extends StatefulWidget {
  const FoodPagedDialog({
    super.key,
    required this.kind,
    required this.id,
    required this.title,
    this.editable = false,
  });
  final FoodPagedKind kind;
  final int id;
  final String title;
  final bool editable;
  @override
  State<FoodPagedDialog> createState() => _FoodPagedDialogState();
}

class _FoodPagedDialogState extends State<FoodPagedDialog> {
  late final api = foodApi();
  List<FoodRow> rows = [];
  int page = 1, total = 0;
  bool busy = true;
  String? error;
  String get path => widget.kind == FoodPagedKind.wallet
      ? '/api/company/school-food/wallets/${widget.id}/entries'
      : '/api/company/school-food/shops/${widget.id}/users';
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    foodDispose(api);
    super.dispose();
  }

  Future<void> load() async {
    if (mounted) {
      setState(() {
        busy = true;
        error = null;
      });
    }
    try {
      final data = foodMap(
        await api.get(path, query: {'page': '$page', 'pageSize': '20'}),
      );
      if (mounted) {
        setState(() {
          rows = foodRows(data['rows']);
          total = (data['total'] as num?)?.toInt() ?? 0;
          busy = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          error = foodError(e);
        });
      }
    }
  }

  Future<void> assign(FoodRow row) async {
    if (busy || !widget.editable) return;
    final current = (row['shopId'] as num?)?.toInt();
    final active = row['selected'] == true;
    if (current != null && current != widget.id && active) {
      final yes = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(foodTokens().radius),
          ),
          title: const Text('ย้ายสิทธิ์ร้านค้า'),
          content: Text(
            'ผู้ใช้ ${row['name']} อยู่ร้านอื่น การผูกกับร้านนี้จะเปลี่ยนร้านที่เข้าถึงได้',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('ยกเลิก'),
            ),
            foodButton(
              'ย้ายร้าน',
              Icons.swap_horiz,
              () => Navigator.pop(dialog, true),
            ),
          ],
        ),
      );
      if (yes != true || !mounted) return;
    }
    setState(() => busy = true);
    try {
      await api.put(
        '/api/company/school-food/shops/${widget.id}/users/${row['id']}',
        body: {
          'requestKey': foodKey(),
          'isActive': !(current == widget.id && active),
        },
      );
      if (mounted) {
        foodMessage(context, message: 'ปรับสิทธิ์ร้านค้าแล้ว', error: false);
      }
      await load();
    } catch (e) {
      if (mounted) {
        setState(() => busy = false);
        foodMessage(
          context,
          message:
              'เปลี่ยนสิทธิ์ไม่สำเร็จ\nรายละเอียดเพิ่มเติม: ${foodError(e)}',
          error: true,
        );
      }
    }
  }

  Widget line(FoodRow row) {
    if (widget.kind == FoodPagedKind.wallet) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${row['kind']} · ${row['amount']} บาท',
              style: foodTokens().sectionStyle,
            ),
            Text(
              'ยอดหลังรายการ ${row['balance']} บาท · ${row['referenceNo']}',
              style: foodTokens().tableStyle,
            ),
            if ((row['reason']?.toString() ?? '').isNotEmpty)
              Text('${row['reason']}', style: foodTokens().tableStyle),
            Divider(color: foodTokens().borderColor),
          ],
        ),
      );
    }
    final current = (row['shopId'] as num?)?.toInt();
    final selected = current == widget.id && row['selected'] == true;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        '${row['name']}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${row['code']}${current != null && current != widget.id ? ' · ผูกร้านอื่น' : ''}',
      ),
      trailing: Checkbox(
        value: selected,
        onChanged: widget.editable && !busy ? (_) => assign(row) : null,
      ),
      onTap: widget.editable && !busy ? () => assign(row) : null,
    );
  }

  @override
  Widget build(BuildContext context) => LaooActionDialog(
    tokens: foodTokens(),
    icon: widget.kind == FoodPagedKind.wallet
        ? Icons.account_balance_wallet_outlined
        : Icons.people_outline,
    title: widget.title,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (busy)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          )
        else if (error != null) ...[
          Text('โหลดข้อมูลไม่สำเร็จ\nรายละเอียดเพิ่มเติม: $error'),
          foodButton('ลองอีกครั้ง', Icons.refresh, load),
        ] else if (rows.isEmpty)
          const Text('ไม่มีรายการ')
        else
          for (final row in rows) line(row),
        const SizedBox(height: 10),
        LaooPaginationCard(
          tokens: foodTokens(),
          page: page,
          pageCount: (total / 20).ceil().clamp(1, 100000),
          pageSize: 20,
          total: total,
          onPrevious: busy || page <= 1
              ? null
              : () {
                  page--;
                  load();
                },
          onNext: busy || page * 20 >= total
              ? null
              : () {
                  page++;
                  load();
                },
        ),
      ],
    ),
    actions: [
      OutlinedButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: const Text('ปิด'),
      ),
    ],
  );
}
