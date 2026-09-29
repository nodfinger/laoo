import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';

import 'evaluation_feature_host.dart';
import 'evaluation_popup_theme.dart';

class EvaluationResultsDialog extends StatefulWidget {
  const EvaluationResultsDialog({super.key, required this.roundId});
  final int roundId;

  @override
  State<EvaluationResultsDialog> createState() =>
      _EvaluationResultsDialogState();
}

class _EvaluationResultsDialogState extends State<EvaluationResultsDialog> {
  late final JsonApiClient _api;
  Map<String, dynamic>? _result;
  List<Map<String, dynamic>> _distribution = const [];
  bool _loading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _api = createEvaluationApiClient();
    _load();
  }

  @override
  void dispose() {
    disposeEvaluationApiClient(_api);
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final raw = await _api.get(
        '/api/company/evaluations/rounds/${widget.roundId}/results',
      );
      final result = Map<String, dynamic>.from(raw as Map);
      List<Map<String, dynamic>> distribution = const [];
      if (result['isAnonymousThresholdMet'] == true) {
        final detail = Map<String, dynamic>.from(
          await _api.get(
                '/api/company/evaluations/rounds/${widget.roundId}/distribution',
              )
              as Map,
        );
        distribution = (detail['items'] as List? ?? const [])
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
      }
      if (mounted) {
        setState(() {
          _result = result;
          _distribution = distribution;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _result = null;
          _loadError =
              'ไม่สามารถโหลดผลประเมินได้\nรายละเอียดเพิ่มเติม: กรุณาตรวจสอบการเชื่อมต่อหรือสิทธิ์ แล้วลองอีกครั้ง';
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: evaluationPopupTheme(context),
    child: Dialog(
      backgroundColor: evaluationUiTokens.popupSurfaceColor,
      surfaceTintColor: evaluationUiTokens.popupSurfaceColor,
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(evaluationUiTokens.radius),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 700),
        child: Padding(
          padding: evaluationUiTokens.cardPadding,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _result == null
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.assessment_outlined,
                          color: evaluationUiTokens.primaryColor,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'ผลประเมิน',
                            style: evaluationUiTokens.captionStyle,
                          ),
                        ),
                      ],
                    ),
                    Divider(color: evaluationUiTokens.borderColor),
                    const SizedBox(height: 16),
                    Text(
                      _loadError ??
                          'ไม่พบผลประเมิน\nรายละเอียดเพิ่มเติม: กรุณาลองอีกครั้ง',
                    ),
                    const SizedBox(height: 16),
                    Divider(color: evaluationUiTokens.borderColor),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('ปิด'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: _load,
                          child: const Text('ลองอีกครั้ง'),
                        ),
                      ],
                    ),
                  ],
                )
              : _ResultBody(result: _result!, distribution: _distribution),
        ),
      ),
    ),
  );
}

class _ResultBody extends StatelessWidget {
  const _ResultBody({required this.result, required this.distribution});
  final Map<String, dynamic> result;
  final List<Map<String, dynamic>> distribution;

  @override
  Widget build(BuildContext context) {
    final assigned = (result['assigned'] as num?)?.toInt() ?? 0;
    final submitted = (result['submitted'] as num?)?.toInt() ?? 0;
    final threshold = result['isAnonymousThresholdMet'] == true;
    final labels = <String, String>{};
    final optionLabels = <String, String>{};
    final rawSnapshot = result['questionsJson'];
    if (rawSnapshot is String) {
      final snapshot = jsonDecode(rawSnapshot) as Map;
      for (final item in (snapshot['questions'] as List? ?? [])) {
        final question = Map<String, dynamic>.from(item as Map);
        labels[question['id'].toString()] = question['text'].toString();
        for (final option in question['options'] as List? ?? const []) {
          final value = Map<String, dynamic>.from(option as Map);
          optionLabels[value['id'].toString()] = value['text'].toString();
        }
      }
    }
    final questions = (result['questions'] as List? ?? [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    final comments = List<String>.from(result['comments'] as List? ?? []);
    final rate = assigned == 0 ? 0 : (submitted * 100 / assigned).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: evaluationUiTokens.popupHeaderMinHeight,
          ),
          child: Row(
            children: [
              Icon(
                Icons.bar_chart_outlined,
                color: evaluationUiTokens.primaryColor,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  result['name']?.toString() ?? '-',
                  style: evaluationUiTokens.captionStyle,
                ),
              ),
            ],
          ),
        ),
        if ((result['referenceTitle']?.toString() ?? '').isNotEmpty)
          Text(result['referenceTitle'].toString()),
        SizedBox(height: evaluationUiTokens.itemSpacing),
        Divider(color: evaluationUiTokens.borderColor, height: 1),
        SizedBox(height: evaluationUiTokens.popupFieldSpacing),
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 420;
            final width = compact
                ? constraints.maxWidth
                : (constraints.maxWidth - evaluationUiTokens.itemSpacing * 2) /
                      3;
            return Wrap(
              spacing: evaluationUiTokens.itemSpacing,
              runSpacing: evaluationUiTokens.itemSpacing,
              children: [
                SizedBox(
                  width: width,
                  child: _Metric(label: 'ผู้มีสิทธิ์ตอบ', value: '$assigned'),
                ),
                SizedBox(
                  width: width,
                  child: _Metric(label: 'ตอบแล้ว', value: '$submitted'),
                ),
                SizedBox(
                  width: width,
                  child: _Metric(label: 'อัตราตอบ', value: '$rate%'),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        if (!threshold)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'จะแสดงผลรายข้อและความคิดเห็นเมื่อมีผู้ตอบอย่างน้อย 5 คน เพื่อคงความเป็นนิรนาม',
              ),
            ),
          )
        else
          Expanded(
            child: ListView(
              children: [
                Text(
                  'คะแนนเฉลี่ยรายข้อ',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                ...questions.map(
                  (question) => Card(
                    child: ListTile(
                      title: Text(
                        labels[question['questionId'].toString()] ??
                            'คำถามประเมิน',
                      ),
                      subtitle: Text(
                        'จำนวนคำตอบ ${(question['responses'] as num?)?.toInt() ?? 0}',
                      ),
                      trailing: Text(
                        '${(question['average'] as num?)?.toStringAsFixed(2) ?? '-'} / 5',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ),
                ),
                if (distribution.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'การกระจายตัวเลือก',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  ...distribution.map(
                    (item) => Card(
                      child: ListTile(
                        title: Text(
                          labels[item['questionId'].toString()] ??
                              'คำถามประเมิน',
                        ),
                        subtitle: Text(
                          optionLabels[item['optionId'].toString()] ??
                              'ตัวเลือก',
                        ),
                        trailing: Text(
                          '${(item['responses'] as num?)?.toInt() ?? 0} คน',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ),
                  ),
                ],
                if (comments.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'ความคิดเห็น',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  ...comments.map(
                    (comment) => Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(comment),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        SizedBox(height: evaluationUiTokens.popupFieldSpacing),
        Divider(color: evaluationUiTokens.borderColor, height: 1),
        SizedBox(height: evaluationUiTokens.itemSpacing),
        Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            height: evaluationUiTokens.buttonHeight,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ปิด'),
            ),
          ),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Text(label),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    ),
  );
}
