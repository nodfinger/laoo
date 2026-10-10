import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';
import 'pet_host.dart';

class PetPhotosDialog extends StatefulWidget {
  const PetPhotosDialog({
    super.key,
    required this.title,
    required this.petId,
    this.stayId,
    required this.canEdit,
  });
  final String title;
  final int petId;
  final int? stayId;
  final bool canEdit;
  @override
  State<PetPhotosDialog> createState() => _PetPhotosDialogState();
}

class _PetPhotosDialogState extends State<PetPhotosDialog> {
  late final api = petApi();
  List<Map<String, dynamic>> photos = [];
  final Map<int, Future<List<int>>> images = {};
  bool loading = true, uploading = false;
  String? error;
  LaooWorkspaceUiTokens get tokens => petTokens();
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    petDispose(api);
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final path = widget.stayId == null
          ? '/api/company/pet/photos/pet/${widget.petId}'
          : '/api/company/pet/photos/stay/${widget.stayId}';
      photos = (await api.get(path) as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      images.clear();
      if (mounted) {
        setState(() => loading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          error = petErrorText(e, 'โหลดรูปสัตว์เลี้ยง');
        });
      }
    }
  }

  Future<void> add() async {
    if (uploading || !widget.canEdit) {
      return;
    }
    final selected = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
      allowMultiple: false,
    );
    if (selected == null || selected.files.isEmpty || !mounted) {
      return;
    }
    final file = selected.files.first;
    final bytes = file.bytes;
    if (bytes == null || bytes.length > 2 * 1024 * 1024 || bytes.length < 12) {
      petMessage(
        context,
        message: 'เลือกรูป JPG, PNG หรือ WebP ขนาดไม่เกิน 2 MB',
        error: true,
      );
      return;
    }
    setState(() => uploading = true);
    try {
      await petUpload(
        '/api/company/pet/photos',
        fileName: file.name,
        bytes: bytes,
        fields: {
          'petId': widget.petId.toString(),
          if (widget.stayId != null) 'stayId': widget.stayId.toString(),
        },
      );
      if (mounted) {
        petMessage(context, message: 'แนบรูปแล้ว', error: false);
        await load();
      }
    } catch (e) {
      if (mounted) {
        petMessage(
          context,
          message: petErrorText(e, 'แนบรูปสัตว์เลี้ยง'),
          error: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => uploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => LaooActionDialog(
    tokens: tokens,
    icon: Icons.photo_library_outlined,
    title: '${widget.title} > รูปภาพ',
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.canEdit)
          OutlinedButton.icon(
            onPressed: uploading ? null : add,
            icon: uploading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_photo_alternate_outlined),
            label: Text(uploading ? 'กำลังแนบรูป...' : 'แนบรูป'),
          ),
        if (widget.canEdit) const SizedBox(height: 16),
        if (loading)
          const Center(child: CircularProgressIndicator())
        else if (error != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(error!),
              OutlinedButton.icon(
                onPressed: load,
                icon: const Icon(Icons.refresh),
                label: const Text('ลองอีกครั้ง'),
              ),
            ],
          )
        else if (photos.isEmpty)
          const Text('ยังไม่มีรูปภาพ')
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final photo in photos)
                SizedBox(
                  width: 128,
                  height: 150,
                  child: Column(
                    children: [
                      FutureBuilder<List<int>>(
                        future: images.putIfAbsent(
                          (photo['id'] as num).toInt(),
                          () => petDownload(
                            '/api/company/pet/photos/${photo['id']}',
                          ),
                        ),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return const SizedBox(
                              height: 120,
                              child: Center(
                                child: Icon(Icons.broken_image_outlined),
                              ),
                            );
                          }
                          if (!snapshot.hasData) {
                            return const SizedBox(
                              height: 120,
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(tokens.radius),
                            child: Image.memory(
                              Uint8List.fromList(snapshot.data!),
                              width: 120,
                              height: 120,
                              fit: BoxFit.cover,
                            ),
                          );
                        },
                      ),
                      Text('#${photo['id']}'),
                    ],
                  ),
                ),
            ],
          ),
      ],
    ),
    actions: [
      OutlinedButton(
        onPressed: uploading ? null : () => Navigator.pop(context),
        child: const Text('ปิด'),
      ),
    ],
  );
}
