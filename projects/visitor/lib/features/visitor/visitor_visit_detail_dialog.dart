import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import 'visitor_inside_repository.dart';

class VisitorVisitDetailDialog extends StatefulWidget {
  const VisitorVisitDetailDialog({
    super.key,
    required this.repository,
    required this.visitId,
    required this.visitorName,
    required this.canEdit,
  });

  final VisitorInsideRepository repository;
  final int visitId;
  final String visitorName;
  final bool canEdit;

  @override
  State<VisitorVisitDetailDialog> createState() =>
      _VisitorVisitDetailDialogState();
}

class _VisitorVisitDetailDialogState extends State<VisitorVisitDetailDialog> {
  late Future<VisitorVisitDetail> _future;
  late Future<List<Map<String, dynamic>>> _auditFuture;
  final _note = TextEditingController();
  Uint8List? _preview;
  final Map<int, Future<Uint8List>> _evidenceFutures = {};
  String _evidenceType = 'VEHICLE';
  String _captureStage = 'CHECKOUT';
  bool _working = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _reload() {
    _future = widget.repository.detail(widget.visitId);
    _auditFuture = widget.repository.audit(widget.visitId);
  }

  Future<void> _saveNote() async {
    final text = _note.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      await widget.repository.addNote(
        widget.visitId,
        text,
        stage: _captureStage,
      );
      _note.clear();
      setState(_reload);
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final source = await picked.readAsBytes();
    final decoded = img.decodeImage(source);
    if (decoded == null) return;
    var quality = 85;
    Uint8List output = Uint8List.fromList(
      img.encodeJpg(decoded, quality: quality),
    );
    while (output.length > 1000000 && quality >= 35) {
      quality -= 10;
      final resized = img.copyResize(
        decoded,
        width: decoded.width > 1600 ? 1600 : decoded.width,
      );
      output = Uint8List.fromList(img.encodeJpg(resized, quality: quality));
    }
    if (output.length > 1000000) {
      setState(() => _error = 'รูปภาพมีขนาดเกิน 1 MB หลังลดขนาด');
      return;
    }
    setState(() {
      _preview = output;
      _error = null;
    });
  }

  Future<void> _upload() async {
    final bytes = _preview;
    if (bytes == null) return;
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      await widget.repository.uploadEvidence(
        widget.visitId,
        bytes: bytes,
        fileName: 'visitor-evidence.jpg',
        evidenceType: _evidenceType,
        captureStage: _captureStage,
      );
      setState(() {
        _preview = null;
        _reload();
      });
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _retryNotification() async {
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      await widget.repository.retryNotification(widget.visitId);
      setState(_reload);
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  String _notificationStatus(Map<String, dynamic> notification) {
    switch (notification['statusCode']?.toString()) {
      case 'SENT':
        return 'ส่งแจ้งเตือนแล้ว';
      case 'FAILED':
        return 'ส่งไม่สำเร็จ';
      case 'NO_CHANNEL':
        return 'ผู้รับรองไม่ได้เปิดรับการแจ้งเตือน';
      default:
        return 'กำลังรอส่ง';
    }
  }

  String _notificationDescription(Map<String, dynamic> notification) {
    final channel = notification['channelCode']?.toString() ?? '-';
    final attempts = notification['attemptCount']?.toString() ?? '0';
    final error = notification['lastErrorMessage']?.toString();
    return error == null || error.isEmpty
        ? 'ช่องทาง: $channel\nลองส่ง $attempts ครั้ง'
        : 'ช่องทาง: $channel\nลองส่ง $attempts ครั้ง\nรายละเอียด: $error';
  }

  String _auditDescription(Map<String, dynamic> item) {
    final occurred = item['occurredDate']?.toString() ?? '-';
    final actor =
        item['actorNameSnapshot']?.toString() ??
        item['actorUserId']?.toString() ??
        '-';
    final note = item['noteText']?.toString();
    return note == null || note.isEmpty
        ? '$occurred โดย $actor'
        : '$occurred โดย $actor\n$note';
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final width = (size.width - 32).clamp(280.0, 680.0).toDouble();
    final height = (size.height * .72).clamp(300.0, 720.0).toDouble();
    return AlertDialog(
      insetPadding: const EdgeInsets.all(16),
      title: Text('รายละเอียดผู้มาติดต่อ #${widget.visitId}'),
      content: SizedBox(
        width: width,
        height: height,
        child: FutureBuilder<VisitorVisitDetail>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const SizedBox(
                height: 180,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) return Text(snapshot.error.toString());
            final detail = snapshot.data!;
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ผู้มาติดต่อ: ${detail.visit['visitorName'] ?? widget.visitorName}',
                  ),
                  Text('ผู้รับรอง: ${detail.visit['hostName'] ?? '-'}'),
                  Text('จุดติดต่อ: ${detail.visit['contactPointName'] ?? '-'}'),
                  Text(
                    'ผลการเข้าพบ: ${detail.visit['visitOutcomeCode'] ?? '-'}',
                  ),
                  if (detail.visit['hostConfirmationResultCode'] != null) ...[
                    Text(
                      'ผู้รับรองยืนยัน: ${detail.visit['hostConfirmationResultCode']}',
                    ),
                    Text(
                      'ยืนยันโดย: ${detail.visit['hostConfirmedByName'] ?? '-'}',
                    ),
                    if ((detail.visit['hostConfirmationNote']?.toString() ?? '')
                        .isNotEmpty)
                      Text(
                        'หมายเหตุผู้รับรอง: ${detail.visit['hostConfirmationNote']}',
                      ),
                  ],
                  Text(
                    'ประเภท Check-out: ${detail.visit['checkoutReasonCode'] ?? '-'}',
                  ),
                  const Divider(),
                  Text(
                    'สถานะแจ้งผู้รับรอง ${detail.notifications.length} รายการ',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (detail.notifications.isEmpty)
                    const Text('ยังไม่มีการแจ้งผู้รับรอง')
                  else
                    ...detail.notifications.map(
                      (notification) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.notifications_outlined),
                        title: Text(_notificationStatus(notification)),
                        subtitle: Text(
                          _notificationDescription(notification),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing:
                            notification['statusCode'] == 'FAILED' &&
                                widget.canEdit
                            ? OutlinedButton.icon(
                                onPressed: _working ? null : _retryNotification,
                                icon: const Icon(Icons.refresh, size: 16),
                                label: const Text('ลองส่งใหม่'),
                              )
                            : null,
                      ),
                    ),
                  const Divider(),
                  const Text(
                    'หลักฐานเดิม',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (detail.images.isEmpty)
                    const Text('ยังไม่มีหลักฐาน')
                  else
                    ...detail.images.map(
                      (image) => ListTile(
                        onTap: () => _showEvidence(image),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: _evidenceThumbnail(image),
                        title: Text(
                          '${image['evidenceType'] ?? 'DOCUMENT'} / ${image['captureStage'] ?? 'CHECKIN'}',
                        ),
                        subtitle: Text(
                          '${image['originalFileName'] ?? ''}\nบันทึก ${image['createDate'] ?? '-'} โดย ${image['createBy'] ?? '-'} - ดูได้อย่างเดียว',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  const Divider(),
                  Text(
                    'ข้อความเพิ่มเติม ${detail.notes.length} รายการ',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (detail.notes.isEmpty)
                    const Text('ยังไม่มีข้อความเพิ่มเติม')
                  else
                    ...detail.notes.map(
                      (note) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.notes_outlined),
                        title: Text(note['noteText']?.toString() ?? '-'),
                        subtitle: Text(
                          'บันทึก ${note['createDate'] ?? '-'} โดย ${note['createBy'] ?? '-'}',
                        ),
                      ),
                    ),
                  const Divider(),
                  const Text(
                    'Timeline การดำเนินการ',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: _auditFuture,
                    builder: (context, auditSnapshot) {
                      if (auditSnapshot.connectionState !=
                          ConnectionState.done) {
                        return const Padding(
                          padding: EdgeInsets.all(8),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      if (auditSnapshot.hasError) {
                        return const Text('ไม่สามารถโหลด Timeline ได้');
                      }
                      final audit = auditSnapshot.data ?? const [];
                      if (audit.isEmpty) {
                        return const Text('ยังไม่มี Timeline การดำเนินการ');
                      }
                      return Column(
                        children: audit
                            .map(
                              (item) => ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.history_outlined),
                                title: Text(
                                  '${item['fromStatusCode'] ?? '-'} → ${item['toStatusCode'] ?? '-'}',
                                ),
                                subtitle: Text(
                                  _auditDescription(item),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(growable: false),
                      );
                    },
                  ),
                  const Divider(),
                  const Text(
                    'เพิ่มข้อความ',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextField(
                    controller: _note,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'ข้อความของเจ้าหน้าที่',
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _working ? null : _saveNote,
                      child: const Text('บันทึกข้อความ'),
                    ),
                  ),
                  const Divider(),
                  const Text(
                    'เพิ่มหลักฐานรูปภาพ',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final type = DropdownButtonFormField<String>(
                        key: ValueKey(_evidenceType),
                        initialValue: _evidenceType,
                        items: const [
                          DropdownMenuItem(
                            value: 'VEHICLE',
                            child: Text('รูปรถ'),
                          ),
                          DropdownMenuItem(
                            value: 'OTHER',
                            child: Text('รูปอื่น'),
                          ),
                        ],
                        onChanged: (value) =>
                            setState(() => _evidenceType = value ?? 'VEHICLE'),
                        decoration: const InputDecoration(labelText: 'ประเภท'),
                      );
                      final stage = DropdownButtonFormField<String>(
                        key: ValueKey(_captureStage),
                        initialValue: _captureStage,
                        items: const [
                          DropdownMenuItem(
                            value: 'CHECKIN',
                            child: Text('ขาเข้า'),
                          ),
                          DropdownMenuItem(
                            value: 'CHECKOUT',
                            child: Text('ขาออก'),
                          ),
                        ],
                        onChanged: (value) =>
                            setState(() => _captureStage = value ?? 'CHECKOUT'),
                        decoration: const InputDecoration(
                          labelText: 'ช่วงเวลา',
                        ),
                      );
                      if (constraints.maxWidth < 420) {
                        return Column(
                          children: [type, const SizedBox(height: 12), stage],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: type),
                          const SizedBox(width: 8),
                          Expanded(child: stage),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _working ? null : _pickImage,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('เลือกรูปภาพ'),
                  ),
                  if (_preview != null) ...[
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 180),
                      child: Image.memory(_preview!, fit: BoxFit.contain),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton(
                        onPressed: _working ? null : _upload,
                        child: const Text('Upload หลักฐาน'),
                      ),
                    ),
                  ],
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('ปิด'),
        ),
      ],
    );
  }

  Widget _evidenceThumbnail(Map<String, dynamic> image) {
    final imageId = (image['visitorVisitImageId'] as num?)?.toInt();
    if (imageId == null) return const Icon(Icons.broken_image_outlined);
    return SizedBox(
      width: 48,
      height: 48,
      child: FutureBuilder<Uint8List>(
        future: _evidenceBytes(imageId),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.memory(snapshot.data!, fit: BoxFit.cover),
            );
          }
          if (snapshot.hasError) return const Icon(Icons.broken_image_outlined);
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }

  Future<Uint8List> _evidenceBytes(int imageId) => _evidenceFutures.putIfAbsent(
    imageId,
    () async => Uint8List.fromList(
      await widget.repository.imageBytes(widget.visitId, imageId),
    ),
  );

  Future<void> _showEvidence(Map<String, dynamic> image) async {
    final imageId = (image['visitorVisitImageId'] as num?)?.toInt();
    if (imageId == null) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(image['originalFileName']?.toString() ?? 'หลักฐานรูปภาพ'),
        content: SizedBox(
          width: 560,
          child: AspectRatio(
            aspectRatio: 1,
            child: FutureBuilder<Uint8List>(
              future: _evidenceBytes(imageId),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return InteractiveViewer(
                    child: Image.memory(snapshot.data!, fit: BoxFit.contain),
                  );
                }
                if (snapshot.hasError) {
                  return const Center(
                    child: Icon(Icons.broken_image_outlined, size: 80),
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
