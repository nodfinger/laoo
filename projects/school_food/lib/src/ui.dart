import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';
import 'host.dart';

typedef FoodRow = Map<String, dynamic>;
FoodRow foodMap(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : {};
List<FoodRow> foodRows(dynamic value) =>
    value is List ? value.map(foodMap).toList() : [];
String foodKey() {
  final r = Random.secure();
  final bytes = List.generate(16, (_) => r.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final h = bytes.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}

InputDecoration foodDecoration(String label) {
  final t = foodTokens();
  OutlineInputBorder border(Color c) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(t.radius),
    borderSide: BorderSide(color: c),
  );
  return InputDecoration(
    labelText: label,
    border: border(t.borderColor),
    enabledBorder: border(t.borderColor),
    disabledBorder: border(t.borderColor),
    focusedBorder: border(t.primaryColor),
  );
}

Widget foodButton(
  String text,
  IconData icon,
  VoidCallback? tap, {
  bool outlined = false,
}) {
  final t = foodTokens();
  final style = ButtonStyle(
    minimumSize: WidgetStatePropertyAll(Size(100, t.buttonHeight)),
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(t.radius)),
    ),
    textStyle: WidgetStatePropertyAll(t.buttonStyle),
  );
  return outlined
      ? OutlinedButton.icon(
          style: style,
          onPressed: tap,
          icon: Icon(icon),
          label: Text(text),
        )
      : FilledButton.icon(
          style: style,
          onPressed: tap,
          icon: Icon(icon),
          label: Text(text),
        );
}

Future<bool> foodConfirmDelete(
  BuildContext context, {
  required String value,
  String action = 'ลบ',
}) async {
  final danger = Theme.of(context).colorScheme.error;
  final deleting = action == 'ลบ';
  return await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          insetPadding: EdgeInsets.all(foodTokens().dialogInsetPadding),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(foodTokens().radius),
          ),
          title: Row(
            children: [
              Icon(
                deleting ? Icons.delete_outline : Icons.cancel_outlined,
                color: danger,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  deleting ? 'ยืนยันการลบข้อมูล' : 'ยืนยันการยกเลิกรายการ',
                  style: foodTokens().captionStyle.copyWith(color: danger),
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
                padding: foodTokens().cardPadding,
                color: danger.withValues(alpha: .1),
                child: Text(value, style: TextStyle(color: danger)),
              ),
              const SizedBox(height: 12),
              Text(
                deleting
                    ? 'ข้อมูลที่ลบแล้วไม่สามารถเรียกคืนได้'
                    : 'รายการที่ยกเลิกแล้วไม่สามารถนำกลับมาใช้งานได้',
              ),
              Divider(color: foodTokens().borderColor),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('ยกเลิก'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: danger,
                minimumSize: Size(100, foodTokens().buttonHeight),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(foodTokens().radius),
                ),
              ),
              onPressed: () => Navigator.pop(dialog, true),
              icon: Icon(
                deleting ? Icons.delete_outline : Icons.cancel_outlined,
              ),
              label: Text(action),
            ),
          ],
        ),
      ) ??
      false;
}

class FoodField {
  const FoodField(
    this.key,
    this.label, {
    this.numeric = false,
    this.secret = false,
    this.required = true,
    this.choices,
    this.initial = '',
    this.maxLength = 200,
    this.lookup,
  });
  final String key, label;
  final bool numeric, required, secret;
  final Map<String, String>? choices;
  final String initial;
  final int maxLength;
  final String? lookup;
}

Future<void> foodForm(
  BuildContext context, {
  required String title,
  required List<FoodField> fields,
  required Future<void> Function(FoodRow) save,
  bool keepOpen = false,
}) async {
  final controllers = {
    for (final f in fields) f.key: TextEditingController(text: f.initial),
  };
  final labels = {
    for (final f in fields)
      if (f.lookup != null) f.key: TextEditingController(),
  };
  final form = GlobalKey<FormState>();
  var busy = false;
  String? failure;
  var key = foodKey();
  String? previousPayload;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialog) => StatefulBuilder(
      builder: (context, setLocal) => PopScope(
        canPop: !busy,
        child: LaooActionDialog(
          tokens: foodTokens(),
          icon: Icons.edit_note,
          title: title,
          content: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final f in fields)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: f.lookup != null
                        ? TextFormField(
                            controller: labels[f.key],
                            readOnly: true,
                            decoration: foodDecoration(
                              '${f.label} *',
                            ).copyWith(suffixIcon: const Icon(Icons.search)),
                            validator: (_) => controllers[f.key]!.text.isEmpty
                                ? 'กรุณาเลือก${f.label}'
                                : null,
                            onTap: busy
                                ? null
                                : () async {
                                    final picked = await showDialog<FoodRow>(
                                      context: context,
                                      builder: (_) => FoodLookup(
                                        path: f.lookup!,
                                        title: f.label,
                                      ),
                                    );
                                    if (picked != null) {
                                      controllers[f.key]!.text = picked['id']
                                          .toString();
                                      labels[f.key]!.text =
                                          '${picked['code']} · ${picked['name']}';
                                    }
                                  },
                          )
                        : f.key == 'isActive'
                        ? Row(
                            children: [
                              Text('สถานะ', style: foodTokens().inputStyle),
                              Switch(
                                value: controllers[f.key]!.text == 'true',
                                onChanged: busy
                                    ? null
                                    : (v) => setLocal(
                                        () => controllers[f.key]!.text = v
                                            .toString(),
                                      ),
                              ),
                            ],
                          )
                        : f.choices != null
                        ? DropdownButtonFormField<String>(
                            initialValue:
                                f.choices!.containsKey(controllers[f.key]!.text)
                                ? controllers[f.key]!.text
                                : null,
                            isExpanded: true,
                            style: foodTokens().inputStyle,
                            decoration: foodDecoration(
                              '${f.label}${f.required ? ' *' : ''}',
                            ),
                            items: f.choices!.entries
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e.key,
                                    child: Text(
                                      e.value,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: busy
                                ? null
                                : (v) => controllers[f.key]!.text = v ?? '',
                            validator: (v) =>
                                f.required && (v == null || v.isEmpty)
                                ? 'กรุณาเลือก${f.label}'
                                : null,
                          )
                        : TextFormField(
                            controller: controllers[f.key],
                            obscureText: f.secret,
                            enableSuggestions: !f.secret,
                            autocorrect: !f.secret,
                            enabled: !busy,
                            style: foodTokens().inputStyle,
                            keyboardType: f.numeric
                                ? const TextInputType.numberWithOptions(
                                    decimal: true,
                                    signed: true,
                                  )
                                : TextInputType.text,
                            maxLength: f.maxLength,
                            decoration: foodDecoration(
                              '${f.label}${f.required ? ' *' : ''}',
                            ),
                            validator: (v) {
                              if (f.secret &&
                                  ((v ?? '').length < 12 ||
                                      !RegExp('[A-Z]').hasMatch(v!) ||
                                      !RegExp('[a-z]').hasMatch(v) ||
                                      !RegExp('[0-9]').hasMatch(v) ||
                                      !RegExp('[^a-zA-Z0-9]').hasMatch(v))) {
                                return 'อย่างน้อย 12 ตัว มีตัวใหญ่ ตัวเล็ก ตัวเลข และอักขระพิเศษ';
                              }
                              if (f.required && (v ?? '').trim().isEmpty) {
                                return 'กรุณาระบุ${f.label}';
                              }
                              if (f.numeric &&
                                  (v ?? '').isNotEmpty &&
                                  num.tryParse(v!) == null) {
                                return 'กรุณากรอกตัวเลข';
                              }
                              return null;
                            },
                          ),
                  ),
                if (failure != null)
                  Text(
                    failure!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            OutlinedButton(
              onPressed: busy ? null : () => Navigator.pop(context),
              child: const Text('ยกเลิก'),
            ),
            FilledButton.icon(
              onPressed: busy
                  ? null
                  : () async {
                      if (!form.currentState!.validate()) return;
                      setLocal(() {
                        busy = true;
                        failure = null;
                      });
                      try {
                        final payload = {
                          for (final f in fields)
                            f.key: f.numeric
                                ? (controllers[f.key]!.text.isEmpty
                                      ? null
                                      : num.parse(controllers[f.key]!.text))
                                : controllers[f.key]!.text.trim(),
                        };
                        final signature = jsonEncode(payload);
                        if (previousPayload != null &&
                            previousPayload != signature) {
                          key = foodKey();
                        }
                        previousPayload = signature;
                        await save({'requestKey': key, ...payload});
                        if (!context.mounted) return;
                        if (!keepOpen) {
                          Navigator.pop(context);
                          return;
                        }
                        for (final f in fields) {
                          controllers[f.key]!.text = f.initial;
                        }
                        for (final c in labels.values) {
                          c.clear();
                        }
                        key = foodKey();
                        previousPayload = null;
                        form.currentState!.reset();
                        setLocal(() => busy = false);
                      } catch (e) {
                        if (context.mounted) {
                          setLocal(() {
                            busy = false;
                            failure =
                                'บันทึกไม่สำเร็จ\nรายละเอียดเพิ่มเติม: ${foodError(e)}';
                          });
                        }
                      }
                    },
              icon: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(busy ? 'กำลังบันทึก' : 'บันทึก'),
            ),
          ],
        ),
      ),
    ),
  );
  for (final c in controllers.values) {
    c.dispose();
  }
  for (final c in labels.values) {
    c.dispose();
  }
}

String foodError(Object error) {
  // The shared client sanitizes API messages. Do not surface unknown raw exceptions.
  try {
    final dynamic e = error;
    final String text = e.message.toString();
    if (text.isNotEmpty) return text;
  } catch (_) {}
  return 'ตรวจสอบข้อมูล สิทธิ์ และการเชื่อมต่อ แล้วลองอีกครั้ง';
}

class FoodLookup extends StatefulWidget {
  const FoodLookup({super.key, required this.path, required this.title});
  final String path, title;
  @override
  State<FoodLookup> createState() => _FoodLookupState();
}

class _FoodLookupState extends State<FoodLookup> {
  late final api = foodApi();
  final search = TextEditingController();
  List<FoodRow> rows = [];
  int page = 1, total = 0;
  bool busy = true;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    search.dispose();
    foodDispose(api);
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = foodMap(
        await api.get(
          widget.path,
          query: {'search': search.text, 'page': '$page'},
        ),
      );
      if (mounted) {
        setState(() {
          rows = foodRows(result['rows']);
          total = (result['total'] as num).toInt();
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

  @override
  Widget build(BuildContext context) => LaooActionDialog(
    tokens: foodTokens(),
    icon: Icons.search,
    title: widget.title,
    content: SizedBox(
      width: double.infinity,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: search,
            decoration: foodDecoration('ค้นหารหัสหรือชื่อ').copyWith(
              suffixIcon: IconButton(
                tooltip: 'ค้นหา',
                onPressed: busy
                    ? null
                    : () {
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
          if (busy)
            const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            )
          else if (error != null) ...[
            Text('โหลดไม่สำเร็จ\nรายละเอียดเพิ่มเติม: $error'),
            foodButton('ลองอีกครั้ง', Icons.replay, load),
          ] else if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('ไม่พบข้อมูลตามเงื่อนไข'),
            )
          else
            for (final row in rows)
              ListTile(
                title: Text('${row['name']}'),
                subtitle: Text('${row['code']}'),
                onTap: () => Navigator.pop(context, row),
              ),
          LaooPaginationCard(
            tokens: foodTokens(),
            page: page,
            pageCount: (total / 20).ceil().clamp(1, 100000),
            pageSize: 20,
            total: total,
            onPrevious: !busy && page > 1
                ? () {
                    page--;
                    load();
                  }
                : null,
            onNext: !busy && page * 20 < total
                ? () {
                    page++;
                    load();
                  }
                : null,
          ),
        ],
      ),
    ),
    actions: [
      OutlinedButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('ยกเลิก'),
      ),
    ],
  );
}
