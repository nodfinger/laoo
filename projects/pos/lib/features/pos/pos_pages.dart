import 'package:flutter/material.dart';

import 'pos_admin_views.dart';
import 'pos_api.dart';
import 'pos_feature_host.dart';
import 'pos_sales_view.dart';
import 'pos_ui.dart';

enum PosPageKind { settings, outlets, items, sales, shifts, returns, reports }

class PosPage extends StatefulWidget {
  const PosPage({
    super.key,
    required this.menuCode,
    required this.fallbackTitle,
    required this.kind,
  });
  final String menuCode;
  final String fallbackTitle;
  final PosPageKind kind;
  @override
  State<PosPage> createState() => _PosPageState();
}

class _PosPageState extends State<PosPage> {
  late final client = createPosApiClient();
  late final api = PosApi(client);
  String title = '';
  Map<String, dynamic> actions = const {};
  Map<String, dynamic> options = const {};
  Object? error;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    disposePosApiClient(client);
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await Future.wait([
        resolvePosMenuTitle(widget.menuCode, widget.fallbackTitle),
        api.actions(widget.menuCode),
        api.options(),
      ]);
      if (!mounted) return;
      setState(() {
        title = result[0] as String;
        actions = result[1] as Map<String, dynamic>;
        options = result[2] as Map<String, dynamic>;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e;
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => buildPosWorkspaceShell(
    pageTitle: title.isEmpty ? widget.fallbackTitle : title,
    activeMenu: widget.menuCode,
    child: ColoredBox(
      color: posUiTokens.backgroundColor,
      child: Padding(
        padding: posUiTokens.contentMargin,
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : error != null
            ? PosErrorState(message: '$error', retry: _load)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PosCaption(title: title, menuCode: widget.menuCode),
                  SizedBox(height: posUiTokens.sectionSpacing),
                  Expanded(child: _body()),
                ],
              ),
      ),
    ),
  );

  Widget _body() => switch (widget.kind) {
    PosPageKind.settings => PosSettingsView(
      api: api,
      canEdit: actions['edit'] == true,
    ),
    PosPageKind.outlets => PosOutletsView(
      api: api,
      actions: actions,
      options: options,
      title: title,
    ),
    PosPageKind.items => PosOutletItemsView(
      api: api,
      actions: actions,
      options: options,
      title: title,
    ),
    PosPageKind.sales => PosSalesView(api: api, actions: actions),
    PosPageKind.shifts => PosShiftView(api: api, actions: actions),
    PosPageKind.returns => PosReturnView(api: api, actions: actions),
    PosPageKind.reports => PosReportView(api: api),
  };
}
