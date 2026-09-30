import 'package:flutter/material.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';

import 'survey_feature_host.dart';

part 'survey_dialogs.dart';
part 'survey_views.dart';
part 'survey_workflow_dialogs.dart';

class SurveyPage extends StatefulWidget {
  const SurveyPage({
    required this.menuCode,
    required this.title,
    required this.endpoint,
    super.key,
  });

  final String menuCode;
  final String title;
  final String endpoint;

  @override
  State<SurveyPage> createState() => _SurveyPageState();
}

class _SurveyPageState extends State<SurveyPage> {
  late final JsonApiClient api = createSurveyApiClient();
  late Future<Map<String, dynamic>> future;
  final search = TextEditingController();
  String title = '';
  String appliedSearch = '';
  String status = '';
  int page = 1;
  bool cards = false;

  static const pageSize = 10;
  bool get isSettings => widget.endpoint == 'settings';
  bool get isReports => widget.endpoint == 'reports';

  @override
  void initState() {
    super.initState();
    title = widget.title;
    future = _load();
    resolveSurveyMenuTitle(widget.menuCode, title).then((value) {
      if (mounted) setState(() => title = value);
    });
  }

  Future<Map<String, dynamic>> _load() async {
    final base = '/api/company/surveys';
    final data = await api.get(
      widget.endpoint.isEmpty ? base : '$base/${widget.endpoint}',
    );
    final actions = await api.get('$base/actions/${widget.menuCode}');
    dynamic options = const <String, dynamic>{};
    if (!isReports) options = await api.get('$base/options');
    return {'data': data, 'actions': actions, 'options': options};
  }

  void reload() => setState(() => future = _load());
  void mutate(VoidCallback callback) => setState(callback);

  @override
  void dispose() {
    search.dispose();
    disposeSurveyApiClient(api);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => buildSurveyWorkspaceShell(
    pageTitle: title,
    activeMenu: widget.menuCode,
    child: Padding(
      padding: surveyUiTokens.contentMargin,
      child: FutureBuilder<Map<String, dynamic>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return _framed(_state('กำลังโหลดข้อมูล...'));
          }
          if (snapshot.hasError) {
            return _framed(_state('โหลดข้อมูลไม่สำเร็จ', retry: true));
          }
          final value = snapshot.data!;
          final data = value['data'];
          final actions = _map(value['actions']);
          final options = _map(value['options']);
          if (isSettings) return _settings(_map(data), actions, options);
          if (isReports) return _reports(_map(data));
          return _list(_rows(data), actions, options);
        },
      ),
    ),
  );

  Widget _caption({Widget? trailing}) => LaooCaptionCard(
    tokens: surveyUiTokens,
    leading: Icon(Icons.quiz_outlined, color: surveyUiTokens.primaryColor),
    caption: title,
    trailing: trailing,
  );

  Widget _framed(Widget child) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _caption(),
      SizedBox(height: surveyUiTokens.sectionSpacing),
      Expanded(child: child),
    ],
  );

  Widget _state(String text, {bool retry = false}) => LaooSurfaceCard(
    tokens: surveyUiTokens,
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 42,
            color: surveyUiTokens.primaryColor,
          ),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center),
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

  InputDecoration _input(String label, {IconData? icon}) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(4),
      borderSide: BorderSide(color: surveyUiTokens.borderColor),
    );
    return InputDecoration(
      labelText: label,
      prefixIcon: icon == null ? null : Icon(icon),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: BorderSide(color: surveyUiTokens.primaryColor, width: 1.5),
      ),
    );
  }

  Future<void> _run(Future<dynamic> Function() action, String success) async {
    try {
      await action();
      if (!mounted) return;
      showSurveyMessage(context, message: success);
      reload();
    } catch (error) {
      if (!mounted) return;
      showSurveyMessage(context, message: '$error', error: true);
    }
  }

  static Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
  static List<Map<String, dynamic>> _rows(dynamic value) => value is List
      ? value.map((item) => Map<String, dynamic>.from(item as Map)).toList()
      : <Map<String, dynamic>>[];
  static String _text(Map row, String key, [String fallback = '-']) =>
      '${row[key] ?? fallback}';
  static int _id(Map row) => (row['id'] as num).toInt();
  static String _date(dynamic value) {
    final text = '${value ?? '-'}';
    return text.length >= 16
        ? text.substring(0, 16).replaceFirst('T', ' ')
        : text;
  }
}

class _QuestionDraft {
  _QuestionDraft({
    String text = '',
    this.type = 'SINGLE',
    this.required = true,
    String options = 'ตัวเลือก 1\nตัวเลือก 2',
    String min = '1',
    String max = '5',
  }) : text = TextEditingController(text: text),
       options = TextEditingController(text: options),
       min = TextEditingController(text: min),
       max = TextEditingController(text: max);

  final TextEditingController text;
  final TextEditingController options;
  final TextEditingController min;
  final TextEditingController max;
  String type;
  bool required;

  void dispose() {
    text.dispose();
    options.dispose();
    min.dispose();
    max.dispose();
  }

  Map<String, dynamic> toJson() => {
    'text': text.text.trim(),
    'type': type,
    'required': required,
    'minValue': type == 'SCALE' ? int.tryParse(min.text) : null,
    'maxValue': type == 'SCALE' ? int.tryParse(max.text) : null,
    'options': type == 'SINGLE' || type == 'MULTI'
        ? options.text
              .split('\n')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList()
        : <String>[],
  };
}
