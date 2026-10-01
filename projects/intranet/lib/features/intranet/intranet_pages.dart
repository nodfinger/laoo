// ignore_for_file: prefer_interpolation_to_compose_strings, curly_braces_in_flow_control_structures

import 'package:flutter/material.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';

import 'intranet_feature_host.dart';

part 'intranet_content_view.dart';
part 'intranet_home_views.dart';

class IntranetPage extends StatefulWidget {
  const IntranetPage({required this.menuCode, required this.title, super.key});
  final String menuCode;
  final String title;

  @override
  State<IntranetPage> createState() => _IntranetPageState();
}

class _IntranetPageState extends State<IntranetPage> {
  late final JsonApiClient api = createIntranetApiClient();
  late Future<Map<String, dynamic>> future;
  final search = TextEditingController();
  final days = TextEditingController();
  String title = '';
  String status = '';
  String type = '';
  int page = 1;
  bool cards = false;
  bool settingsReady = false;
  bool enabled = true;
  bool requireApproval = true;
  bool allowSelfApproval = false;
  int? defaultApprover;
  static const pageSize = 10;

  @override
  void initState() {
    super.initState();
    title = widget.title;
    future = _load();
    resolveIntranetMenuTitle(widget.menuCode, title).then((value) {
      if (mounted) setState(() => title = value);
    });
  }

  Future<Map<String, dynamic>> _load() async {
    const base = '/api/company/intranet';
    final actions = widget.menuCode == '43004'
        ? const <String, dynamic>{}
        : await api.get(base + '/actions/' + widget.menuCode);
    final options = widget.menuCode == '43001' || widget.menuCode == '43002'
        ? await api.get(base + '/options')
        : const <String, dynamic>{};
    dynamic data;
    if (widget.menuCode == '43001') {
      data = await api.get(base + '/settings');
    } else if (widget.menuCode == '43002') {
      final query = Uri(
        queryParameters: {
          if (search.text.trim().isNotEmpty) 'search': search.text.trim(),
          if (status.isNotEmpty) 'status': status,
          'page': page.toString(),
          'pageSize': pageSize.toString(),
        },
      ).query;
      data = await api.get(base + '/contents?' + query);
    } else if (widget.menuCode == '43003') {
      data = await api.get(base + '/approvals');
    } else if (widget.menuCode == '43004') {
      final query = Uri(
        queryParameters: {
          if (search.text.trim().isNotEmpty) 'search': search.text.trim(),
          if (type.isNotEmpty) 'type': type,
        },
      ).query;
      data = await api.get(base + '/home?' + query);
    } else {
      data = await api.get(base + '/reports');
    }
    return {'data': data, 'actions': actions, 'options': options};
  }

  void reload() => setState(() => future = _load());

  Future<void> run(Future<dynamic> Function() action, String message) async {
    try {
      await action();
      if (!mounted) return;
      showIntranetMessage(context, message: message);
      reload();
    } catch (error) {
      if (!mounted) return;
      showIntranetMessage(context, message: error.toString(), error: true);
    }
  }

  @override
  void dispose() {
    search.dispose();
    days.dispose();
    disposeIntranetApiClient(api);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => buildIntranetWorkspaceShell(
    pageTitle: title,
    activeMenu: widget.menuCode,
    child: Padding(
      padding: intranetUiTokens.contentMargin,
      child: FutureBuilder<Map<String, dynamic>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return frame(stateCard('กำลังโหลดข้อมูล...'));
          }
          if (snapshot.hasError) {
            return frame(stateCard('โหลดข้อมูลไม่สำเร็จ', retry: true));
          }
          final result = snapshot.data!;
          final data = mapOf(result['data']);
          final actions = mapOf(result['actions']);
          final options = mapOf(result['options']);
          if (widget.menuCode == '43001')
            return settingsView(data, actions, options);
          if (widget.menuCode == '43002')
            return contentsView(data, actions, options);
          if (widget.menuCode == '43003')
            return approvalsView(rowsOf(result['data']), actions);
          if (widget.menuCode == '43004') return homeView(data);
          return reportsView(data);
        },
      ),
    ),
  );

  Widget caption({Widget? trailing}) => LaooCaptionCard(
    tokens: intranetUiTokens,
    leading: Icon(
      Icons.campaign_outlined,
      color: intranetUiTokens.primaryColor,
    ),
    caption: title,
    trailing: trailing,
  );

  Widget frame(Widget child) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      caption(),
      SizedBox(height: intranetUiTokens.sectionSpacing),
      Expanded(child: child),
    ],
  );

  Widget stateCard(String text, {bool retry = false}) => LaooSurfaceCard(
    tokens: intranetUiTokens,
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.dynamic_feed_outlined,
            size: 44,
            color: intranetUiTokens.primaryColor,
          ),
          const SizedBox(height: 12),
          Text(text),
          if (retry) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: reload,
              icon: const Icon(Icons.replay_outlined),
              label: const Text('ลองอีกครั้ง'),
            ),
          ],
        ],
      ),
    ),
  );

  InputDecoration input(String label, {IconData? icon}) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(4),
      borderSide: BorderSide(color: intranetUiTokens.borderColor),
    );
    return InputDecoration(
      labelText: label,
      prefixIcon: icon == null ? null : Icon(icon),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: BorderSide(
          color: intranetUiTokens.primaryColor,
          width: 1.5,
        ),
      ),
    );
  }

  static Map<String, dynamic> mapOf(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
  static List<Map<String, dynamic>> rowsOf(dynamic value) => value is List
      ? value.map((item) => Map<String, dynamic>.from(item as Map)).toList()
      : <Map<String, dynamic>>[];
  static String textOf(Map row, String key, [String fallback = '-']) =>
      (row[key] ?? fallback).toString();
  static int intOf(dynamic value) =>
      value is num ? value.toInt() : int.tryParse(value.toString()) ?? 0;
  static int idOf(Map row) => intOf(row['id']);
  static String dateOf(dynamic value) {
    final text = (value ?? '-').toString();
    return text.length >= 16
        ? text.substring(0, 16).replaceFirst('T', ' ')
        : text;
  }

  static String statusLabel(String value) =>
      const {
        'DRAFT': 'ฉบับร่าง',
        'PENDING_APPROVAL': 'รออนุมัติ',
        'PUBLISHED': 'เผยแพร่',
        'RETURNED': 'ส่งกลับแก้ไข',
      }[value] ??
      value;
  static String typeLabel(String value) =>
      const {
        'NEWS': 'ข่าว',
        'ANNOUNCEMENT': 'ประกาศ',
        'ACTIVITY': 'กิจกรรม',
        'DOCUMENT': 'เอกสาร',
      }[value] ??
      value;
}
