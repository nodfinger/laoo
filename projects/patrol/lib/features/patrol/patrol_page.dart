import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';
import 'patrol_feature_host.dart';

part 'patrol_forms.dart';
part 'patrol_views.dart';

class PatrolPage extends StatefulWidget {
  const PatrolPage({
    required this.menuCode,
    required this.title,
    required this.endpoint,
    super.key,
  });
  final String menuCode, title, endpoint;
  @override
  State<PatrolPage> createState() => _PatrolPageState();
}

class _PatrolPageState extends State<PatrolPage> {
  late final JsonApiClient api = createPatrolApi();
  late Future<Map<String, dynamic>> future;
  String title = '';
  bool cards = false;
  int page = 1;
  static const pageSize = 10;
  @override
  void initState() {
    super.initState();
    title = widget.title;
    future = _load();
    patrolTitle(widget.menuCode, title).then((v) {
      if (mounted) setState(() => title = v);
    });
  }

  Future<Map<String, dynamic>> _load() async {
    const base = '/api/company/patrol';
    final data = await api.get('$base/${widget.endpoint}');
    final actions = await api.get('$base/actions/${widget.menuCode}');
    dynamic options = <String, dynamic>{};
    if (const {
      '56002',
      '56003',
      '56004',
      '56006',
      '56007',
    }.contains(widget.menuCode)) {
      options = await api.get('$base/options?menuCode=${widget.menuCode}');
    }
    return {'data': data, 'actions': actions, 'options': options};
  }

  void reload() => setState(() {
    page = 1;
    future = _load();
  });
  void setCardMode(bool value) => setState(() => cards = value);
  void previousPage() => setState(() => page--);
  void nextPage() => setState(() => page++);
  @override
  void dispose() {
    disposePatrolApi(api);
    super.dispose();
  }

  Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
  List<Map<String, dynamic>> _rows(dynamic value) => value is List
      ? value.map((e) => Map<String, dynamic>.from(e as Map)).toList()
      : <Map<String, dynamic>>[];
  Map<String, bool> _actions(dynamic value) {
    final raw = _map(value)['actions'];
    return raw is Map
        ? raw.map((k, v) => MapEntry(k.toString(), v == true))
        : <String, bool>{};
  }

  InputDecoration input(String label) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(patrolTokens.radius),
      borderSide: BorderSide(color: patrolTokens.borderColor),
    );
    return InputDecoration(
      labelText: label,
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: BorderSide(color: patrolTokens.primaryColor, width: 1.5),
      ),
    );
  }

  Future<void> run(Future<dynamic> Function() action, String success) async {
    try {
      await action();
      if (!mounted) return;
      patrolMessage(context, message: success);
      reload();
    } catch (e) {
      if (!mounted) return;
      patrolMessage(context, message: e.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) => patrolShell(
    title: title,
    menu: widget.menuCode,
    child: Padding(
      padding: patrolTokens.contentMargin,
      child: FutureBuilder<Map<String, dynamic>>(
        future: future,
        builder: (context, s) {
          if (s.connectionState != ConnectionState.done) {
            return framed(state('กำลังโหลดข้อมูล...'));
          }
          if (s.hasError) {
            return framed(
              state(
                'โหลดข้อมูลไม่สำเร็จ กรุณาตรวจสอบสิทธิ์และลองอีกครั้ง',
                retry: true,
              ),
            );
          }
          final value = s.data!,
              actions = _actions(value['actions']),
              options = _map(value['options']);
          if (widget.menuCode == '56001') {
            return settings(_map(value['data']), actions);
          }
          if (widget.menuCode == '56012') return dashboard(_map(value['data']));
          return list(_rows(value['data']), actions, options);
        },
      ),
    ),
  );
  Widget caption({Widget? trailing}) => LaooCaptionCard(
    tokens: patrolTokens,
    caption: title,
    favoriteKey: widget.menuCode,
    leading: Icon(Icons.fact_check_outlined, color: patrolTokens.primaryColor),
    trailing: trailing,
  );
  Widget framed(Widget child) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      caption(),
      SizedBox(height: patrolTokens.sectionSpacing),
      Expanded(child: child),
    ],
  );
  Widget state(String text, {bool retry = false}) => LaooSurfaceCard(
    tokens: patrolTokens,
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.fact_check_outlined,
            size: 44,
            color: patrolTokens.primaryColor,
          ),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center),
          if (retry) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: reload,
              icon: const Icon(Icons.replay),
              label: const Text('ลองอีกครั้ง'),
            ),
          ],
        ],
      ),
    ),
  );
}
