import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/api/visitor_api_client.dart';
import 'visitor_feature_host.dart';
import 'visitor_host_confirm_repository.dart';

class VisitorHostConfirmPage extends StatefulWidget {
  const VisitorHostConfirmPage({super.key});
  @override
  State<VisitorHostConfirmPage> createState() => _VisitorHostConfirmPageState();
}

class _VisitorHostConfirmPageState extends State<VisitorHostConfirmPage> {
  late final VisitorApiClient _api = VisitorApiClient();
  late final VisitorHostConfirmRepository _repository =
      VisitorHostConfirmRepository(_api);
  HostConfirmActions? _actions;
  List<HostConfirmVisit> _visits = const [];
  HostConfirmDetail? _detail;
  String? _error;
  bool _loading = true;
  int _selected = 0;
  String _result = 'MET';
  final _note = TextEditingController();
  final Map<int, Future<Uint8List>> _imageFutures = {};
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _note.dispose();
    _api.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final actions = await _repository.actions();
      if (!actions.canView) {
        throw const VisitorApiException(403, 'ไม่มีสิทธิ์ยืนยันการเข้าพบ');
      }
      final visits = await _repository.pending();
      final selected = visits.isEmpty
          ? 0
          : _selected.clamp(0, visits.length - 1);
      final detail = visits.isEmpty
          ? null
          : await _repository.detail(visits[selected].id);
      if (mounted) {
        setState(() {
          _actions = actions;
          _visits = visits;
          _selected = selected;
          _detail = detail;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _select(int value) async {
    setState(() {
      _selected = value;
      _detail = null;
      _result = 'MET';
      _note.clear();
      _imageFutures.clear();
    });
    try {
      final detail = await _repository.detail(_visits[value].id);
      if (mounted) setState(() => _detail = detail);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  Future<void> _confirm() async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันการเข้าพบ'),
        content: Text(
          _result == 'MET'
              ? 'ยืนยันว่าผู้มาติดต่อเข้าพบแล้ว'
              : 'ยืนยันว่าผู้มาติดต่อไม่ได้เข้าพบ',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ยืนยัน'),
          ),
        ],
      ),
    );
    if (accepted != true || !mounted) return;
    try {
      await _repository.confirm(
        _visits[_selected].id,
        _result,
        _note.text.trim().isEmpty ? null : _note.text.trim(),
      );
      _note.clear();
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) => buildVisitorWorkspaceShell(
    pageTitle: _actions?.caption ?? 'ยืนยันการเข้าพบ',
    activeMenu: '32003',
    child: SafeArea(
      child: Stack(
        children: [
          _body(),
          if (!_loading && _error == null && _visits.isNotEmpty)
            Align(
              alignment: Alignment.bottomCenter,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _actions?.canEdit == true ? _confirm : null,
                      child: Text(
                        _result == 'MET'
                            ? 'ยืนยันว่าเข้าพบแล้ว'
                            : 'ยืนยันว่าไม่ได้เข้าพบ',
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 8),
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                    label: const Text('ลองใหม่'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    if (_visits.isEmpty) {
      return const Center(child: Text('ไม่มีรายการรอเข้าพบ'));
    }
    final visit = _visits[_selected];
    final detail = _detail;
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 92),
      children: [
        Text(
          _actions?.caption ?? 'ยืนยันการเข้าพบ',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 4),
        Text(
          'รอการยืนยัน ${_visits.length} รายการ',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        if (_visits.length > 1)
          OutlinedButton(
            onPressed: () => _pick(),
            child: Text(
              'รอเข้าพบอีก: ${_visits.where((v) => v.id != visit.id).map((v) => v.visitorName).join(' | ')}',
            ),
          ),
        _section('ผู้มาติดต่อ', [
          Chip(
            avatar: const Icon(Icons.schedule_outlined, size: 18),
            label: const Text('รอยืนยันการเข้าพบ'),
          ),
          Text(visit.visitorName),
          'ผู้รับรอง: ${visit.hostName}',
          'จุดติดต่อ: ${visit.contactPointName}',
          'เวลาเข้า: ${visit.checkedInDate}',
          if (visit.purpose.isNotEmpty) 'วัตถุประสงค์: ${visit.purpose}',
        ]),
        _section(
          'หลักฐานจาก รปภ',
          detail == null
              ? [const Center(child: CircularProgressIndicator())]
              : detail.images.isEmpty
              ? [const Text('ไม่มีรูปหลักฐาน')]
              : [_evidenceGrid(detail.images)],
        ),
        _section('ผลการเข้าพบ', [
          RadioGroup<String>(
            groupValue: _result,
            onChanged: (value) {
              if (value != null && _actions?.canEdit == true) {
                setState(() => _result = value);
              }
            },
            child: Column(
              children: [
                RadioListTile<String>(
                  value: 'MET',
                  enabled: _actions?.canEdit == true,
                  title: const Text('เข้าพบแล้ว'),
                ),
                RadioListTile<String>(
                  value: 'NOT_MET',
                  enabled: _actions?.canEdit == true,
                  title: const Text('ไม่ได้เข้าพบ'),
                ),
              ],
            ),
          ),
          TextField(
            controller: _note,
            maxLength: 1000,
            enabled: _actions?.canEdit == true,
            decoration: const InputDecoration(labelText: 'หมายเหตุ (ถ้ามี)'),
          ),
        ]),
      ],
    );
  }

  Widget _section(String title, List<Object> children) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...children.map(
            (child) => child is Widget ? child : Text(child.toString()),
          ),
        ],
      ),
    ),
  );
  Widget _evidenceGrid(List<Map<String, dynamic>> images) => LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth < 420
          ? constraints.maxWidth
          : (constraints.maxWidth - 8) / 2;
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final image in images)
            SizedBox(
              width: width,
              child: InkWell(
                onTap: () => _preview(image),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _evidenceThumbnail(image),
                        Text(
                          _evidenceLabel(image),
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          image['originalFileName']?.toString() ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
  String _evidenceLabel(Map<String, dynamic> image) {
    final type = image['evidenceType']?.toString();
    final stage = image['captureStage'] == 'CHECKOUT' ? 'ขาออก' : 'ขาเข้า';
    return switch (type) {
      'DOCUMENT' => 'เอกสาร · $stage',
      'VEHICLE' => 'รูปรถ · $stage',
      _ => 'รูปอื่น · $stage',
    };
  }

  Widget _evidenceThumbnail(Map<String, dynamic> image) {
    final id = (image['visitorVisitImageId'] as num?)?.toInt();
    if (id == null) {
      return const AspectRatio(
        aspectRatio: 1.6,
        child: Center(child: Icon(Icons.image_outlined, size: 42)),
      );
    }
    return AspectRatio(
      aspectRatio: 1.6,
      child: FutureBuilder<Uint8List>(
        future: _imageBytes(id),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.memory(snapshot.data!, fit: BoxFit.cover),
            );
          }
          if (snapshot.hasError) {
            return const Center(child: Icon(Icons.broken_image_outlined));
          }
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }

  Future<Uint8List> _imageBytes(int imageId) => _imageFutures.putIfAbsent(
    imageId,
    () async => Uint8List.fromList(
      await _repository.imageBytes(_visits[_selected].id, imageId),
    ),
  );

  Future<void> _pick() => showModalBottomSheet<void>(
    context: context,
    builder: (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          for (var i = 0; i < _visits.length; i++)
            ListTile(
              title: Text(_visits[i].visitorName),
              subtitle: Text(_visits[i].contactPointName),
              selected: i == _selected,
              onTap: () {
                Navigator.pop(context);
                _select(i);
              },
            ),
        ],
      ),
    ),
  );
  void _preview(Map<String, dynamic> image) {
    final id = (image['visitorVisitImageId'] as num?)?.toInt();
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_evidenceLabel(image)),
        content: SizedBox(
          width: 520,
          child: AspectRatio(
            aspectRatio: 1,
            child: id == null
                ? const Center(
                    child: Icon(Icons.broken_image_outlined, size: 96),
                  )
                : FutureBuilder<Uint8List>(
                    future: _imageBytes(id),
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        return InteractiveViewer(
                          child: Image.memory(
                            snapshot.data!,
                            fit: BoxFit.contain,
                          ),
                        );
                      }
                      if (snapshot.hasError) {
                        return const Center(
                          child: Icon(Icons.broken_image_outlined, size: 96),
                        );
                      }
                      return const Center(child: CircularProgressIndicator());
                    },
                  ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ปิด'),
          ),
        ],
      ),
    );
  }
}
