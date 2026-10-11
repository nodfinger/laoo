import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'site_host.dart';

class SiteCustomerPortalPage extends StatefulWidget {
  const SiteCustomerPortalPage({super.key});
  @override
  State<SiteCustomerPortalPage> createState() => _SiteCustomerPortalPageState();
}

class _SiteCustomerPortalPageState extends State<SiteCustomerPortalPage> {
  final company = TextEditingController(),
      email = TextEditingController(),
      password = TextEditingController();
  final client = http.Client();
  String? token, notice;
  bool busy = false, noticeError = false;
  int alertSeconds = 3;
  Timer? timer;
  Map<String, dynamic> profile = {};
  List<Map<String, dynamic>> projects = [],
      reports = [],
      handovers = [],
      notifications = [];
  Map<String, dynamic>? selected;
  Color get accent => Theme.of(context).colorScheme.primary;

  @override
  void dispose() {
    timer?.cancel();
    company.dispose();
    email.dispose();
    password.dispose();
    client.close();
    super.dispose();
  }

  Uri uri(String path) => Uri.parse(sitePublicApiBaseUrl).resolve(path);
  Future<dynamic> request(String method, String path, {Object? body}) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null) headers['Authorization'] = 'Bearer $token';
    final response = switch (method) {
      'POST' => await client.post(
        uri(path),
        headers: headers,
        body: jsonEncode(body),
      ),
      _ => await client.get(uri(path), headers: headers),
    };
    if (response.statusCode < 200 || response.statusCode >= 300) {
      String detail = 'กรุณาลองอีกครั้ง';
      try {
        final json = jsonDecode(utf8.decode(response.bodyBytes));
        if (json is Map) {
          detail = '${json['message'] ?? detail} ${json['description'] ?? ''}';
        }
      } catch (_) {}
      throw StateError(detail);
    }
    if (response.bodyBytes.isEmpty) return null;
    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  void showNotice(String text, {bool error = false}) {
    timer?.cancel();
    setState(() {
      notice = text;
      noticeError = error;
    });
    timer = Timer(Duration(seconds: alertSeconds.clamp(1, 60)), () {
      if (mounted) setState(() => notice = null);
    });
  }

  Future<void> login() async {
    if (busy) return;
    if (company.text.trim().isEmpty ||
        email.text.trim().isEmpty ||
        password.text.isEmpty) {
      showNotice('กรอกรหัสบริษัท อีเมล และรหัสผ่าน', error: true);
      return;
    }
    setState(() => busy = true);
    try {
      final result = Map<String, dynamic>.from(
        await request(
              'POST',
              '/api/site/customer/login',
              body: {
                'companyCode': company.text.trim(),
                'email': email.text.trim(),
                'password': password.text,
              },
            )
            as Map,
      );
      token = result['accessToken']?.toString();
      password.clear();
      profile = Map<String, dynamic>.from(
        await request('GET', '/api/site/customer/portal/me') as Map,
      );
      alertSeconds = (profile['timeAlert'] as num?)?.toInt() ?? 3;
      final data =
          await request('GET', '/api/site/customer/portal/projects') as List;
      projects = data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      final noticeData =
          await request('GET', '/api/site/customer/portal/notifications')
              as List;
      notifications = noticeData
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (mounted) setState(() => busy = false);
      if (projects.isNotEmpty) await selectProject(projects.first);
    } catch (error) {
      token = null;
      if (mounted) showNotice(error.toString(), error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> selectProject(Map<String, dynamic> item) async {
    if (busy) return;
    setState(() {
      selected = item;
      busy = true;
      reports = [];
      handovers = [];
    });
    try {
      final id = item['id'];
      final reportData = Map<String, dynamic>.from(
        await request('GET', '/api/site/customer/portal/projects/$id/reports')
            as Map,
      );
      final handoverData =
          await request(
                'GET',
                '/api/site/customer/portal/projects/$id/handovers',
              )
              as List;
      reports = (reportData['items'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      handovers = handoverData
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) showNotice(error.toString(), error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> decide(Map<String, dynamic> handover, bool accept) async {
    final reason = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        title: Text(accept ? 'ยืนยันรับมอบ' : 'ส่งกลับงาน'),
        content: accept
            ? Text('ยืนยันรับมอบ ${handover['stageName']}?')
            : TextField(
                controller: reason,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'เหตุผล *',
                  border: OutlineInputBorder(),
                ),
              ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(accept ? 'ยืนยัน' : 'ส่งกลับ'),
          ),
        ],
      ),
    );
    final message = reason.text.trim();
    reason.dispose();
    if (confirmed != true) return;
    if (!accept && message.isEmpty) {
      showNotice('กรุณาระบุเหตุผล', error: true);
      return;
    }
    try {
      await request(
        'POST',
        '/api/site/customer/portal/projects/${selected!['id']}/handovers/${handover['id']}/decision',
        body: {'accept': accept, 'reason': accept ? null : message},
      );
      showNotice(accept ? 'รับมอบแล้ว' : 'ส่งกลับแล้ว');
      await selectProject(selected!);
    } catch (error) {
      showNotice(error.toString(), error: true);
    }
  }

  Future<void> previewPhoto(Map<String, dynamic> photo) async {
    try {
      final response = await client.get(
        uri(
          '/api/site/customer/portal/projects/${selected!['id']}/files/${photo['id']}',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode != 200) {
        throw StateError('ไม่สามารถเปิดภาพนี้ได้');
      }
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialog) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800, maxHeight: 700),
            child: InteractiveViewer(
              child: Image.memory(
                Uint8List.fromList(response.bodyBytes),
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      );
    } catch (error) {
      if (mounted) showNotice(error.toString(), error: true);
    }
  }

  Widget surface({required Widget child}) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(4),
    ),
    child: child,
  );
  Widget loginView() => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 440),
      child: surface(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.engineering_outlined, size: 42, color: accent),
            const SizedBox(height: 10),
            const Text(
              'ติดตามงานไซต์',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              'สำหรับลูกค้าของผู้รับเหมา',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextField(
              controller: company,
              decoration: const InputDecoration(
                labelText: 'รหัสบริษัท',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'อีเมล',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: password,
              obscureText: true,
              onSubmitted: (_) => login(),
              decoration: const InputDecoration(
                labelText: 'รหัสผ่าน',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: busy ? null : login,
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              child: Text(busy ? 'กำลังเข้าสู่ระบบ' : 'เข้าสู่ระบบ'),
            ),
          ],
        ),
      ),
    ),
  );
  Widget reportCard(Map<String, dynamic> entry) {
    final data = Map<String, dynamic>.from(entry['content'] as Map);
    final photos = (data['photos'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    final workers = (data['workers'] as List? ?? []),
        materials = (data['materials'] as List? ?? []);
    return surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'วันที่ ${data['workDate']?.toString().split('T').first ?? '—'}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text('${data['summary'] ?? ''}'),
          if (data['problem'] != null) ...[
            const SizedBox(height: 8),
            Text('ปัญหา: ${data['problem']}'),
          ],
          if (workers.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('คนงาน ${workers.length} รายการ'),
          ],
          if (materials.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('วัสดุ ${materials.length} รายการ'),
          ],
          if (photos.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final photo in photos)
                  OutlinedButton.icon(
                    onPressed: () => previewPhoto(photo),
                    icon: const Icon(Icons.image_outlined),
                    label: Text('${photo['fileName'] ?? 'ดูรูป'}'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget portalView() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (notifications.isNotEmpty) ...[
        Text('ข่าวแจ้งเตือน', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final item in notifications.where((e) => e['isRead'] != true))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: surface(
              child: Row(
                children: [
                  const Icon(Icons.notifications_outlined),
                  const SizedBox(width: 8),
                  Expanded(child: Text('${item['title'] ?? ''}')),
                  TextButton(
                    onPressed: () async {
                      try {
                        await request(
                          'POST',
                          '/api/site/customer/portal/notifications/${item['id']}/read',
                        );
                        if (mounted) setState(() => item['isRead'] = true);
                      } catch (error) {
                        if (mounted) showNotice(error.toString(), error: true);
                      }
                    },
                    child: const Text('รับทราบ'),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 16),
      ],
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final item in projects)
            OutlinedButton.icon(
              onPressed: busy ? null : () => selectProject(item),
              icon: const Icon(Icons.location_city_outlined),
              label: Text('${item['name'] ?? 'โครงการ'}'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
            ),
        ],
      ),
      const SizedBox(height: 16),
      if (selected == null)
        surface(child: const Text('ยังไม่มีโครงการที่ได้รับสิทธิ์'))
      else ...[
        surface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${selected!['name']}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text('${selected!['address'] ?? ''}'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'รายงานที่เผยแพร่',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (reports.isEmpty)
          surface(child: const Text('ยังไม่มีรายงานที่เผยแพร่'))
        else
          for (final report in reports)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: reportCard(report),
            ),
        const SizedBox(height: 16),
        const Text(
          'ส่งมอบงาน',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (handovers.isEmpty)
          surface(child: const Text('ยังไม่มีงานส่งมอบ'))
        else
          for (final handover in handovers)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: surface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${handover['stageName'] ?? ''}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text('${handover['detail'] ?? ''}'),
                    Text('สถานะ ${handover['status']}'),
                    if (handover['status'] == 'SUBMITTED')
                      Align(
                        alignment: Alignment.centerRight,
                        child: Wrap(
                          spacing: 8,
                          children: [
                            OutlinedButton(
                              onPressed: () => decide(handover, false),
                              child: const Text('ส่งกลับ'),
                            ),
                            FilledButton(
                              onPressed: () => decide(handover, true),
                              child: const Text('รับมอบ'),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
      ],
    ],
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
    appBar: AppBar(
      title: const Text('LAOO · ติดตามงานไซต์'),
      actions: token == null
          ? null
          : [
              TextButton(
                onPressed: () {
                  setState(() {
                    token = null;
                    projects = [];
                    reports = [];
                    handovers = [];
                    notifications = [];
                    selected = null;
                  });
                },
                child: const Text('ออกจากระบบ'),
              ),
            ],
    ),
    body: Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: token == null
              ? SizedBox(
                  height: MediaQuery.sizeOf(context).height - 120,
                  child: loginView(),
                )
              : portalView(),
        ),
        if (notice != null)
          Positioned(
            top: 12,
            right: 12,
            left: MediaQuery.sizeOf(context).width < 480 ? 12 : null,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(4),
              color:
                  (noticeError
                          ? Theme.of(context).colorScheme.errorContainer
                          : Colors.white)
                      .withValues(alpha: .95),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(child: Text(notice!)),
                    IconButton(
                      onPressed: () => setState(() => notice = null),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
