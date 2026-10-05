import 'package:flutter/material.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';
import 'host.dart';
import 'ui.dart';

/// Portal session stays in memory and never replaces the company user's JWT.
class FoodPortalPage extends StatefulWidget {
  const FoodPortalPage({super.key, this.guardian = false, this.initialToken});
  final bool guardian;
  final String? initialToken;
  @override
  State<FoodPortalPage> createState() => _FoodPortalPageState();
}

class _FoodPortalPageState extends State<FoodPortalPage> {
  final company = TextEditingController(),
      identity = TextEditingController(),
      password = TextEditingController(),
      newPassword = TextEditingController(),
      confirmation = TextEditingController();
  final form = GlobalKey<FormState>();
  String? token, error;
  bool busy = false, mustChange = false;
  FoodRow data = {};
  List<FoodRow> children = [];
  int? child;
  int page = 1;
  DateTime from = DateTime.now().subtract(const Duration(days: 30)),
      to = DateTime.now();
  String get title => widget.guardian
      ? 'อาหารและ Wallet ของบุตรหลาน'
      : 'อาหารและ Wallet นักเรียน';
  @override
  void initState() {
    super.initState();
    token = widget.initialToken;
    if (token != null) load();
  }

  @override
  void dispose() {
    for (final c in [company, identity, password, newPassword, confirmation]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<dynamic> request(String path, {FoodRow? body}) async {
    final transport = foodPortalRequest;
    if (transport == null) throw StateError('Portal transport unavailable');
    return transport(path, body: body, token: token);
  }

  void failure(Object e) {
    if (!mounted) return;
    error = foodError(e);
    foodMessage(
      context,
      message: 'เปิดข้อมูลไม่สำเร็จ\nรายละเอียดเพิ่มเติม: ${error!}',
      error: true,
    );
  }

  Future<void> login() async {
    if (busy || !form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final result = foodMap(
        await request(
          '/api/school/${widget.guardian ? 'guardian' : 'student'}/login',
          body: {
            'companyCode': company.text.trim(),
            if (widget.guardian)
              'email': identity.text.trim()
            else
              'studentCode': identity.text.trim(),
            'password': password.text,
          },
        ),
      );
      token = result['accessToken'] as String?;
      if (token == null) throw StateError('No session returned');
      mustChange = result['mustChangePassword'] == true;
      password.clear();
      if (!mustChange) await fetch();
    } catch (e) {
      failure(e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> changePassword() async {
    if (busy || !form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await request(
        '/api/school/student/change-password',
        body: {
          'currentPassword': password.text,
          'newPassword': newPassword.text,
        },
      );
      logout();
      if (mounted) {
        foodMessage(
          context,
          message: 'เปลี่ยนรหัสผ่านแล้ว กรุณาเข้าสู่ระบบใหม่',
          error: false,
        );
      }
    } catch (e) {
      failure(e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void logout() {
    setState(() {
      token = null;
      data = {};
      children = [];
      child = null;
      mustChange = false;
      error = null;
      page = 1;
      password.clear();
      newPassword.clear();
      confirmation.clear();
    });
  }

  Future<void> fetch() async {
    if (widget.guardian && children.isEmpty) {
      final result = foodMap(
        await request('/api/school/guardian/food/children'),
      );
      children = foodRows(result['children']);
      child = children.isEmpty ? null : (children.first['id'] as num).toInt();
    }
    if (widget.guardian && child == null) {
      data = {};
      return;
    }
    final path = widget.guardian
        ? '/api/school/guardian/food/students/$child'
        : '/api/school/student/food';
    final query = Uri(
      queryParameters: {
        'from': iso(from),
        'to': iso(to),
        'page': '$page',
        'pageSize': '20',
      },
    ).query;
    final result = foodMap(await request('$path?$query'));
    if (mounted) data = result;
  }

  Future<void> load() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await fetch();
    } catch (e) {
      failure(e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String iso(DateTime d) => d.toIso8601String().split('T').first;
  String date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  Future<void> pick(bool start) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: start ? from : to,
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
          from = selected;
          if (to.isBefore(from)) to = from;
        } else {
          to = selected;
          if (from.isAfter(to)) from = to;
        }
      });
    }
  }

  Widget panel(Widget child) => Container(
    width: double.infinity,
    padding: foodTokens().cardPadding,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(foodTokens().radius),
    ),
    child: child,
  );
  Widget field(
    TextEditingController c,
    String label, {
    bool secret = false,
    String? Function(String?)? validate,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: c,
      enabled: !busy,
      obscureText: secret,
      autocorrect: !secret,
      enableSuggestions: !secret,
      style: foodTokens().inputStyle,
      decoration: foodDecoration('$label *'),
      validator:
          validate ??
          (v) => (v ?? '').trim().isEmpty ? 'กรุณาระบุ$label' : null,
    ),
  );
  Widget credentials() => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: panel(
          Form(
            key: form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  mustChange ? 'เปลี่ยนรหัสผ่านเริ่มต้น' : 'เข้าสู่ระบบ',
                  style: foodTokens().captionStyle,
                ),
                const SizedBox(height: 16),
                if (!mustChange) ...[
                  field(company, 'รหัสโรงเรียน'),
                  field(
                    identity,
                    widget.guardian ? 'Email ผู้ปกครอง' : 'รหัสนักเรียน',
                  ),
                ],
                field(
                  password,
                  mustChange ? 'รหัสผ่านปัจจุบัน' : 'รหัสผ่าน',
                  secret: true,
                ),
                if (mustChange) ...[
                  field(
                    newPassword,
                    'รหัสผ่านใหม่',
                    secret: true,
                    validate: (v) {
                      final p = v ?? '';
                      return p.length >= 12 &&
                              p.length <= 256 &&
                              RegExp('[A-Z]').hasMatch(p) &&
                              RegExp('[a-z]').hasMatch(p) &&
                              RegExp('[0-9]').hasMatch(p) &&
                              RegExp('[^a-zA-Z0-9]').hasMatch(p)
                          ? null
                          : 'อย่างน้อย 12 ตัว มีตัวใหญ่ ตัวเล็ก ตัวเลข และอักขระพิเศษ';
                    },
                  ),
                  field(
                    confirmation,
                    'ยืนยันรหัสผ่านใหม่',
                    secret: true,
                    validate: (v) =>
                        v == newPassword.text ? null : 'รหัสผ่านไม่ตรงกัน',
                  ),
                ],
                if (error != null)
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                foodButton(
                  busy
                      ? 'กำลังดำเนินการ'
                      : mustChange
                      ? 'เปลี่ยนรหัสผ่าน'
                      : 'เข้าสู่ระบบ',
                  Icons.login,
                  busy
                      ? null
                      : mustChange
                      ? changePassword
                      : login,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  Widget dashboard() {
    final rows = foodRows(data['rows']), summary = foodRows(data['summary']);
    final total = (data['total'] as num?)?.toInt() ?? 0;
    return ListView(
      padding: foodTokens().cardPadding,
      children: [
        panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.guardian && children.isNotEmpty)
                DropdownButtonFormField<int>(
                  initialValue: child,
                  isExpanded: true,
                  decoration: foodDecoration('บุตรหลาน'),
                  items: [
                    for (final c in children)
                      DropdownMenuItem(
                        value: (c['id'] as num).toInt(),
                        child: Text(
                          '${c['name']}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: busy
                      ? null
                      : (v) {
                          child = v;
                          page = 1;
                          data = {};
                          load();
                        },
                ),
              if (widget.guardian && children.isEmpty && !busy)
                const Text(
                  'ยังไม่มีบุตรหลานที่ได้รับสิทธิ์ดูข้อมูลอาหาร กรุณาติดต่อโรงเรียน',
                ),
              const Text('ยอด Wallet คงเหลือ'),
              Text(
                '${((data['balance'] as num?) ?? 0).toStringAsFixed(2)} บาท',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const Text('ยอดปัจจุบัน • ประวัติด้านล่างกรองตามวันที่ซื้อ'),
            ],
          ),
        ),
        SizedBox(height: foodTokens().sectionSpacing),
        panel(
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              foodButton(
                'จาก ${date(from)}',
                Icons.calendar_today,
                busy ? null : () => pick(true),
                outlined: true,
              ),
              foodButton(
                'ถึง ${date(to)}',
                Icons.calendar_today,
                busy ? null : () => pick(false),
                outlined: true,
              ),
              foodButton(
                'ค้นหา',
                Icons.search,
                busy
                    ? null
                    : () {
                        page = 1;
                        load();
                      },
              ),
            ],
          ),
        ),
        SizedBox(height: foodTokens().sectionSpacing),
        if (busy)
          panel(const Center(child: CircularProgressIndicator()))
        else if (error != null)
          panel(
            Column(
              children: [
                Text(error!),
                foodButton('ลองใหม่', Icons.refresh, load, outlined: true),
              ],
            ),
          )
        else ...[
          panel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('สรุปตามประเภทสินค้า', style: foodTokens().captionStyle),
                if (summary.isEmpty)
                  const Text('ไม่มีการซื้อในช่วงวันที่เลือก'),
                for (final s in summary)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      '${s['category']} · ${s['quantity']} ชิ้น · ${s['net']} บาท',
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: foodTokens().sectionSpacing),
          panel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ประวัติการซื้อ', style: foodTokens().captionStyle),
                if (rows.isEmpty) const Text('ไม่มีรายการในช่วงวันที่เลือก'),
                for (final row in rows) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${row['item']}', style: foodTokens().inputStyle),
                        Text('${row['shop']} · ${row['receipt']}'),
                        Text(
                          'ซื้อ ${row['quantity']} · คืน ${row['returned']} · สุทธิ ${row['net']} บาท',
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: foodTokens().borderColor),
                ],
              ],
            ),
          ),
        ],
        SizedBox(height: foodTokens().sectionSpacing),
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
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      backgroundColor: Colors.white,
      title: Text(title, style: foodTokens().captionStyle),
      actions: [
        if (token != null)
          IconButton(
            tooltip: 'ออกจากระบบ',
            onPressed: busy ? null : logout,
            icon: const Icon(Icons.logout),
          ),
      ],
    ),
    body: SafeArea(
      child: token == null || mustChange ? credentials() : dashboard(),
    ),
  );
}
