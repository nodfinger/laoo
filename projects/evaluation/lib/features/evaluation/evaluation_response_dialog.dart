import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';

import 'evaluation_feature_host.dart';

class EvaluationResponseDialog extends StatefulWidget {
  const EvaluationResponseDialog({super.key, required this.roundId});
  final int roundId;

  @override
  State<EvaluationResponseDialog> createState() =>
      _EvaluationResponseDialogState();
}

class _EvaluationResponseDialogState extends State<EvaluationResponseDialog> {
  late final JsonApiClient _api;
  Map<String, dynamic>? _round;
  List<Map<String, dynamic>> _questions = [];
  final Map<String, dynamic> _answers = {};
  bool _loading = true;
  bool _saving = false;
  String? _error;

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
    try {
      final round = Map<String, dynamic>.from(
        await _api.get('/api/company/evaluations/mine/${widget.roundId}')
            as Map,
      );
      final saved = Map<String, dynamic>.from(
        await _api.get(
              '/api/company/evaluations/mine/${widget.roundId}/answers',
            )
            as Map,
      );
      final snapshot = jsonDecode(round['questionsJson'] as String) as Map;
      if (!mounted) return;
      setState(() {
        _round = round;
        _questions = (snapshot['questions'] as List? ?? [])
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
        _answers.clear();
        for (final item in saved['answers'] as List? ?? const []) {
          final answer = Map<String, dynamic>.from(item as Map);
          final questionId = answer['questionId']?.toString();
          if (questionId == null) continue;
          final question = _questions
              .where((x) => x['id'] == questionId)
              .firstOrNull;
          if (question == null) continue;
          switch (question['type']) {
            case 'RATING_5':
              _answers[questionId] = answer['ratingValue'];
            case 'TEXT':
              _answers[questionId] = answer['text'] ?? '';
            case 'SINGLE_CHOICE':
              final options = List<String>.from(
                answer['optionIds'] as List? ?? [],
              );
              _answers[questionId] = options.isEmpty ? null : options.first;
            default:
              _answers[questionId] = List<String>.from(
                answer['optionIds'] as List? ?? [],
              );
          }
        }
      });
    } catch (_) {
      _error =
          'ไม่สามารถเปิดแบบประเมินได้\nรายละเอียดเพิ่มเติม: งานอาจปิดแล้วหรือไม่ได้มอบหมายให้บัญชีนี้';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _complete() {
    for (final question in _questions) {
      if (question['required'] != true) continue;
      final value = _answers[question['id']];
      if (value == null ||
          (value is String && value.trim().isEmpty) ||
          (value is List && value.isEmpty)) {
        return false;
      }
    }
    return true;
  }

  Future<void> _save() async {
    if (!_complete()) {
      setState(
        () => _error =
            'ตอบข้อมูลไม่ครบ\nรายละเอียดเพิ่มเติม: กรุณาตอบทุกคำถามที่มีเครื่องหมายบังคับก่อนบันทึก',
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final answers = _questions.map((question) {
        final type = question['type'];
        final value = _answers[question['id']];
        return {
          'questionId': question['id'],
          'ratingValue': type == 'RATING_5' ? value : null,
          'text': type == 'TEXT' ? value : null,
          'optionIds': type == 'SINGLE_CHOICE'
              ? (value == null ? <String>[] : [value])
              : type == 'MULTIPLE_CHOICE'
              ? (value ?? <String>[])
              : <String>[],
        };
      }).toList();
      await _api.put(
        '/api/company/evaluations/mine/${widget.roundId}/answers',
        body: {'answers': answers},
      );
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'บันทึกคำตอบไม่สำเร็จ\nรายละเอียดเพิ่มเติม: กรุณาตรวจคำตอบและลองบันทึกใหม่อีกครั้ง',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Dialog(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760, maxHeight: 760),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _round == null
            ? Text(_error ?? 'ไม่พบแบบประเมิน')
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _round!['name'] as String,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if ((_round!['referenceTitle'] as String?)?.isNotEmpty ??
                      false)
                    Text(_round!['referenceTitle'] as String),
                  const SizedBox(height: 12),
                  if (_error != null) _ErrorText(text: _error!),
                  Expanded(
                    child: ListView.separated(
                      itemCount: _questions.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (_, index) => _QuestionCard(
                        index: index + 1,
                        question: _questions[index],
                        value: _answers[_questions[index]['id']],
                        onChanged: (value) => setState(
                          () => _answers[_questions[index]['id'] as String] =
                              value,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: _saving
                            ? null
                            : () => Navigator.pop(context),
                        child: const Text('ยกเลิก'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('บันทึกคำตอบ'),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    ),
  );
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.index,
    required this.question,
    required this.value,
    required this.onChanged,
  });
  final int index;
  final Map<String, dynamic> question;
  final dynamic value;
  final ValueChanged<dynamic> onChanged;

  @override
  Widget build(BuildContext context) {
    final type = question['type'] as String;
    final options = (question['options'] as List? ?? [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    Widget input;
    if (type == 'RATING_5') {
      input = Wrap(
        spacing: 8,
        children: List.generate(
          5,
          (index) => ChoiceChip(
            label: Text('${index + 1}'),
            selected: value == index + 1,
            onSelected: (_) => onChanged(index + 1),
          ),
        ),
      );
    } else if (type == 'TEXT') {
      input = TextFormField(
        initialValue: value as String?,
        maxLines: 3,
        onChanged: onChanged,
        decoration: const InputDecoration(labelText: 'ความคิดเห็น'),
      );
    } else if (type == 'SINGLE_CHOICE') {
      input = RadioGroup<String>(
        groupValue: value as String?,
        onChanged: onChanged,
        child: Column(
          children: options
              .map(
                (option) => RadioListTile<String>(
                  value: option['id'] as String,
                  title: Text(option['text'] as String),
                ),
              )
              .toList(),
        ),
      );
    } else {
      final selected = List<String>.from(value as List? ?? []);
      input = Column(
        children: options
            .map(
              (option) => CheckboxListTile(
                value: selected.contains(option['id']),
                onChanged: (checked) {
                  final next = [...selected];
                  checked == true
                      ? next.add(option['id'] as String)
                      : next.remove(option['id']);
                  onChanged(next);
                },
                title: Text(option['text'] as String),
              ),
            )
            .toList(),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$index. ${question['text']}${question['required'] == true ? ' *' : ''}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            input,
          ],
        ),
      ),
    );
  }
}

class _ErrorText extends StatelessWidget {
  const _ErrorText({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(10),
    color: Theme.of(context).colorScheme.errorContainer,
    child: Text(text),
  );
}
