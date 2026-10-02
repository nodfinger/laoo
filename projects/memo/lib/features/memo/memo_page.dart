// ignore_for_file: curly_braces_in_flow_control_structures, unnecessary_underscores

import 'package:flutter/material.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';
import 'memo_feature_host.dart';
import 'memo_settings_view.dart';
import 'memo_master_view.dart';
import 'memo_documents_view.dart';
import 'memo_read_view.dart';

class MemoPage extends StatefulWidget {
  const MemoPage({
    super.key,
    required this.menuCode,
    required this.fallbackTitle,
  });
  final String menuCode;
  final String fallbackTitle;
  @override
  State<MemoPage> createState() => _MemoPageState();
}

class _MemoPageState extends State<MemoPage> {
  late final JsonApiClient api = memoApi();
  String title = '';
  bool loading = true;
  Object? error;
  Map<String, dynamic> actions = {};
  dynamic data;
  Map<String, dynamic> options = {};
  bool cards = false;
  @override
  void initState() {
    super.initState();
    title = widget.fallbackTitle;
    memoTitle(widget.menuCode, title).then((v) {
      if (mounted) setState(() => title = v);
    });
    load();
  }

  @override
  void dispose() {
    disposeMemoApi(api);
    super.dispose();
  }

  String get endpoint => switch (widget.menuCode) {
    '50001' => 'settings',
    '50002' => 'types',
    '50003' => 'routes',
    '50004' => 'templates',
    '50005' => 'documents',
    '50006' => 'approvals',
    '50007' => 'inbox',
    '50008' => 'history',
    _ => 'reports',
  };
  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final values = await Future.wait([
        api.get('/api/company/memo/actions/${widget.menuCode}'),
        api.get('/api/company/memo/$endpoint'),
        api.get('/api/company/memo/options'),
      ]);
      if (mounted)
        setState(() {
          actions = _map(values[0]);
          data = values[1];
          options = _map(values[2]);
          loading = false;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          error = e;
          loading = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) => memoShell(
    title: title,
    menu: title,
    child: Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) => LaooCaptionCard(
              tokens: memoTokens,
              caption: title,
              leading: Icon(
                Icons.description_outlined,
                color: memoTokens.primaryColor,
              ),
              favoriteKey: widget.menuCode,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_supportsListCard &&
                      constraints.maxWidth >= memoTokens.compactBreakpoint)
                    LaooListCardToggle(
                      tokens: memoTokens,
                      cards: cards,
                      onChanged: (value) => setState(() => cards = value),
                    ),
                  if (widget.menuCode == '50005' &&
                      actions['create'] == true) ...[
                    SizedBox(width: memoTokens.itemSpacing),
                    FilledButton.icon(
                      onPressed: () => setState(() => data = {'editor': true}),
                      icon: const Icon(Icons.add),
                      label: const Text('เพิ่ม'),
                    ),
                  ],
                ],
              ),
            ),
          ),
          SizedBox(height: memoTokens.sectionSpacing),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : error != null
                ? _error()
                : _content(),
          ),
        ],
      ),
    ),
  );
  bool get _supportsListCard => const {
    '50002',
    '50003',
    '50004',
    '50005',
    '50006',
    '50007',
    '50008',
  }.contains(widget.menuCode);
  Widget _error() => Center(
    child: OutlinedButton.icon(
      onPressed: load,
      icon: const Icon(Icons.refresh),
      label: const Text('โหลดไม่สำเร็จ ลองอีกครั้ง'),
    ),
  );
  Widget _content() => switch (widget.menuCode) {
    '50001' => MemoSettingsView(
      api: api,
      value: _map(data),
      canEdit: actions['edit'] == true,
      onSaved: load,
    ),
    '50002' || '50003' || '50004' => MemoMasterView(
      api: api,
      menuCode: widget.menuCode,
      items: _list(data),
      options: options,
      actions: actions,
      cards: cards,
      onChanged: load,
    ),
    '50005' => MemoDocumentsView(
      api: api,
      value: data,
      options: options,
      actions: actions,
      cards: cards,
      onChanged: load,
    ),
    _ => MemoReadView(
      api: api,
      menuCode: widget.menuCode,
      value: data,
      actions: actions,
      cards: cards,
      onChanged: load,
    ),
  };
}

Map<String, dynamic> _map(dynamic value) => value is Map<String, dynamic>
    ? value
    : value is Map
    ? value.map((k, v) => MapEntry('$k', v))
    : <String, dynamic>{};
List<dynamic> _list(dynamic value) => value is List ? value : <dynamic>[];
