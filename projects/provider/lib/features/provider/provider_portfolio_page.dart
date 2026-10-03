import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:laoo_shared_core/laoo_shared_core.dart';
import 'package:laoo_shared_workspace_ui/laoo_shared_workspace_ui.dart';

import 'provider_feature_host.dart';
import 'provider_image_compression.dart';

class ProviderPortfolioPage extends StatefulWidget {
  const ProviderPortfolioPage({super.key});

  @override
  State<ProviderPortfolioPage> createState() => _ProviderPortfolioPageState();
}

class _ProviderPortfolioPageState extends State<ProviderPortfolioPage> {
  static const menuCode = '51009';
  late final JsonApiClient api = createProviderApi();
  final search = TextEditingController();
  String title = 'ผลงานที่ผ่านมา';
  bool loading = true;
  bool cards = false;
  Object? error;
  Map<String, dynamic> actions = const {};
  List<Map<String, dynamic>> items = const [];
  int page = 1;
  int total = 0;
  static const pageSize = 10;

  int get pageCount => total == 0 ? 1 : (total / pageSize).ceil();

  @override
  void initState() {
    super.initState();
    providerTitle(menuCode, title).then((value) {
      if (mounted) setState(() => title = value);
    });
    load();
  }

  @override
  void dispose() {
    search.dispose();
    disposeProviderApi(api);
    super.dispose();
  }

  Future<void> load({int? nextPage}) async {
    setState(() {
      loading = true;
      error = null;
      if (nextPage != null) page = nextPage;
    });
    try {
      final result = await Future.wait([
        api.get('/api/company/provider/actions/$menuCode'),
        api.get(
          '/api/company/provider/portfolio',
          query: {
            'page': '$page',
            'pageSize': '$pageSize',
            if (search.text.trim().isNotEmpty) 'search': search.text.trim(),
          },
        ),
      ]);
      final payload = _map(result[1]);
      if (!mounted) return;
      setState(() {
        actions = _map(result[0]);
        items = (payload['items'] as List? ?? const []).map(_map).toList();
        total = (payload['total'] as num?)?.toInt() ?? 0;
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
  Widget build(BuildContext context) => providerShell(
    title: title,
    menu: title,
    child: Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          LaooCaptionCard(
            tokens: providerTokens,
            caption: title,
            leading: Icon(
              Icons.photo_library_outlined,
              color: providerTokens.primaryColor,
            ),
            favoriteKey: menuCode,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                LaooListCardToggle(
                  tokens: providerTokens,
                  cards: cards,
                  onChanged: (value) => setState(() => cards = value),
                ),
                if (actions['create'] == true) ...[
                  const SizedBox(width: 8),
                  SizedBox(
                    height: providerTokens.buttonHeight,
                    child: FilledButton.icon(
                      onPressed: () => _openForm(),
                      icon: const Icon(Icons.add),
                      label: const Text('เพิ่ม'),
                      style: _filledStyle,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 6),
          LaooFilterCard(
            tokens: providerTokens,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 360,
                  child: TextField(
                    controller: search,
                    onSubmitted: (_) => load(nextPage: 1),
                    decoration: _input('ค้นหาชื่อผลงาน', Icons.search),
                  ),
                ),
                SizedBox(
                  height: providerTokens.buttonHeight,
                  child: FilledButton.icon(
                    onPressed: () => load(nextPage: 1),
                    icon: const Icon(Icons.search),
                    label: const Text('ค้นหา'),
                    style: _filledStyle,
                  ),
                ),
                SizedBox(
                  height: providerTokens.buttonHeight,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      search.clear();
                      load(nextPage: 1);
                    },
                    icon: const Icon(Icons.filter_alt_off_outlined),
                    label: const Text('ล้าง Filter'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Expanded(child: _body()),
          if (!loading && error == null) ...[
            const SizedBox(height: 6),
            LaooPaginationCard(
              tokens: providerTokens,
              page: page,
              pageCount: pageCount,
              pageSize: pageSize,
              total: total,
              onPrevious: page > 1 ? () => load(nextPage: page - 1) : null,
              onNext: page < pageCount ? () => load(nextPage: page + 1) : null,
            ),
          ],
        ],
      ),
    ),
  );

  Widget _body() {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) {
      return Center(
        child: OutlinedButton.icon(
          onPressed: load,
          icon: const Icon(Icons.replay),
          label: const Text('โหลดไม่สำเร็จ ลองอีกครั้ง'),
        ),
      );
    }
    if (items.isEmpty) return const Center(child: Text('ยังไม่มีผลงาน'));
    return cards ? _cardGrid() : _table();
  }

  Widget _table() => LaooTableCard(
    tokens: providerTokens,
    child: LaooWorkspaceDataTable(
      tokens: providerTokens,
      columns: const [
        LaooWorkspaceTableColumns.id,
        DataColumn(label: Text('รูปปก')),
        DataColumn(label: Text('ชื่อผลงาน')),
        DataColumn(label: Text('วันที่ดำเนินการ')),
        DataColumn(label: Text('รูปถ่ายงาน')),
        DataColumn(label: Text('สถานะ')),
        DataColumn(label: Text('จัดการ')),
      ],
      rows: items.asMap().entries.map((entry) {
        final row = entry.value;
        return DataRow(
          cells: [
            DataCell(Text('${(page - 1) * pageSize + entry.key + 1}')),
            DataCell(_cover(row, 72, 44)),
            DataCell(
              SizedBox(
                width: 260,
                child: Text(
                  '${row['title'] ?? '-'}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            DataCell(Text(_date(row['serviceDate']))),
            DataCell(Text('${(row['photos'] as List?)?.length ?? 0} รูป')),
            DataCell(Text(row['active'] == true ? 'ใช้งาน' : 'ไม่ใช้งาน')),
            DataCell(_actions(row)),
          ],
        );
      }).toList(),
    ),
  );

  Widget _cardGrid() => SingleChildScrollView(
    child: LayoutBuilder(
      builder: (context, constraints) {
        final count = constraints.maxWidth >= 1200
            ? 4
            : constraints.maxWidth >= 760
            ? 3
            : constraints.maxWidth >= 480
            ? 2
            : 1;
        final width = (constraints.maxWidth - (count - 1) * 12) / count;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: items
              .map(
                (row) => SizedBox(
                  width: width,
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AspectRatio(
                          aspectRatio: 16 / 9,
                          child: _cover(row, double.infinity, double.infinity),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${row['title'] ?? '-'}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${_date(row['serviceDate'])} • ${(row['photos'] as List?)?.length ?? 0} รูป',
                              ),
                              Align(
                                alignment: Alignment.centerRight,
                                child: _actions(row),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    ),
  );

  Widget _cover(Map<String, dynamic> row, double width, double height) {
    final path = '${row['coverImagePath'] ?? ''}';
    return SizedBox(
      width: width,
      height: height,
      child: path.isEmpty
          ? const ColoredBox(
              color: Color(0xfff1f5f4),
              child: Icon(Icons.image_outlined),
            )
          : Image.network(
              '/api/public/providers/portfolio/${row['id']}/cover',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  const Icon(Icons.broken_image_outlined),
            ),
    );
  }

  Widget _actions(Map<String, dynamic> row) => Wrap(
    spacing: 2,
    children: [
      IconButton(
        tooltip: 'ดูอัลบั้ม',
        onPressed: () => _showAlbum(row),
        icon: const Icon(Icons.visibility_outlined),
      ),
      if (actions['edit'] == true)
        IconButton(
          tooltip: 'แก้ไข',
          onPressed: () => _openForm(row),
          icon: Icon(Icons.edit_outlined, color: providerTokens.primaryColor),
        ),
      if (actions['delete'] == true)
        IconButton(
          tooltip: 'ลบ',
          onPressed: () => _confirmDelete(row),
          icon: const Icon(Icons.delete_outline, color: Colors.red),
        ),
    ],
  );

  Future<void> _openForm([Map<String, dynamic>? row]) async {
    final editing = row != null;
    final workTitle = TextEditingController(text: '${row?['title'] ?? ''}');
    final serviceDate = TextEditingController(
      text: editing
          ? _date(row['serviceDate'])
          : _date(DateTime.now().toIso8601String()),
    );
    var active = row?['active'] != false;
    ProviderCompressedImage? cover;
    final addedPhotos = <ProviderCompressedImage>[];
    var saving = false;
    var existingPhotos = (row?['photos'] as List? ?? const [])
        .map(_map)
        .toList();
    await showDialog<void>(
      context: context,
      barrierDismissible: !saving,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> pickCover() async {
            final picked = await _pickImages(single: true);
            if (picked.isNotEmpty) setDialogState(() => cover = picked.first);
          }

          Future<void> save() async {
            if (workTitle.text.trim().isEmpty ||
                serviceDate.text.trim().isEmpty ||
                (!editing && cover == null)) {
              providerMessage(
                this.context,
                'กรุณากรอกข้อมูลและเลือกรูปปกให้ครบ',
                error: true,
              );
              return;
            }
            setDialogState(() => saving = true);
            try {
              int id;
              if (editing) {
                id = (row['id'] as num).toInt();
                await api.put(
                  '/api/company/provider/portfolio/$id',
                  body: {
                    'title': workTitle.text.trim(),
                    'serviceDate': serviceDate.text.trim(),
                    'active': active,
                  },
                );
                if (cover != null)
                  await uploadProviderFile(
                    '/api/company/provider/portfolio/$id/cover',
                    fileName: cover!.fileName,
                    bytes: cover!.bytes,
                  );
              } else {
                final response = _map(
                  await uploadProviderFile(
                    '/api/company/provider/portfolio',
                    fileName: cover!.fileName,
                    bytes: cover!.bytes,
                    fields: {
                      'title': workTitle.text.trim(),
                      'serviceDate': serviceDate.text.trim(),
                      'active': '$active',
                    },
                  ),
                );
                id = (response['id'] as num).toInt();
              }
              for (final photo in addedPhotos) {
                await uploadProviderFile(
                  '/api/company/provider/portfolio/$id/photos',
                  fileName: photo.fileName,
                  bytes: photo.bytes,
                );
              }
              if (!mounted) return;
              providerMessage(
                this.context,
                editing ? 'แก้ไขผลงานแล้ว' : 'เพิ่มผลงานแล้ว',
              );
              await load(nextPage: editing ? page : 1);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              if (!editing && mounted) _openForm();
            } catch (_) {
              if (mounted)
                providerMessage(
                  this.context,
                  'บันทึกผลงานไม่สำเร็จ',
                  error: true,
                );
              setDialogState(() => saving = false);
            }
          }

          return LaooActionDialog(
            tokens: providerTokens,
            icon: Icons.photo_library_outlined,
            title: '$title > ${editing ? 'แก้ไข' : 'เพิ่ม'}',
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('สถานะ', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 8),
                    Switch(
                      value: active,
                      onChanged: saving
                          ? null
                          : (v) => setDialogState(() => active = v),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: workTitle,
                  enabled: !saving,
                  maxLength: 200,
                  decoration: _input('ชื่อผลงาน *'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: serviceDate,
                  enabled: !saving,
                  decoration: _input(
                    'วันที่ดำเนินการ *',
                    Icons.calendar_today_outlined,
                  ),
                ),
                const SizedBox(height: 16),
                _imagePickerTile(
                  'รูปปก 1 รูป *',
                  cover?.fileName ??
                      (editing ? 'ใช้รูปปกปัจจุบัน' : 'ยังไม่ได้เลือกรูป'),
                  pickCover,
                ),
                const SizedBox(height: 16),
                _imagePickerTile(
                  'รูปถ่ายงาน (ไม่จำกัดจำนวน)',
                  'เลือกแล้ว ${addedPhotos.length} รูป',
                  () async {
                    final picked = await _pickImages(single: false);
                    setDialogState(() => addedPhotos.addAll(picked));
                  },
                ),
                if (editing && existingPhotos.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: existingPhotos
                        .map(
                          (photo) => Stack(
                            children: [
                              SizedBox(
                                width: 88,
                                height: 70,
                                child: Image.network(
                                  '/api/public/providers/portfolio/photos/${photo['id']}',
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                right: 0,
                                top: 0,
                                child: IconButton.filled(
                                  visualDensity: VisualDensity.compact,
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: saving
                                      ? null
                                      : () async {
                                          await api.delete(
                                            '/api/company/provider/portfolio/${row['id']}/photos/${photo['id']}',
                                          );
                                          setDialogState(
                                            () => existingPhotos.removeWhere(
                                              (x) => x['id'] == photo['id'],
                                            ),
                                          );
                                        },
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                        .toList(),
                  ),
                ],
                const SizedBox(height: 4),
                const Text(
                  'ระบบจะลดขนาดรูปอัตโนมัติให้ไม่เกิน 1 MB',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
            actions: [
              OutlinedButton(
                onPressed: saving ? null : () => Navigator.pop(dialogContext),
                child: const Text('ยกเลิก'),
              ),
              FilledButton.icon(
                onPressed: saving ? null : save,
                icon: saving
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: const Text('บันทึก'),
              ),
            ],
          );
        },
      ),
    );
    workTitle.dispose();
    serviceDate.dispose();
  }

  Widget _imagePickerTile(String label, String value, VoidCallback onPressed) =>
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          border: Border.all(color: providerTokens.borderColor),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
              onPressed: onPressed,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: const Text('เลือกรูป'),
            ),
          ],
        ),
      );

  Future<List<ProviderCompressedImage>> _pickImages({
    required bool single,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: !single,
        withData: true,
      );
      if (result == null) return const [];
      return result.files
          .where((file) => file.bytes != null)
          .map((file) => compressProviderImage(file.bytes!, file.name))
          .toList();
    } catch (e) {
      if (mounted) providerMessage(context, '$e', error: true);
      return const [];
    }
  }

  Future<void> _showAlbum(Map<String, dynamic> row) async {
    final photos = <Map<String, dynamic>>[
      {'id': row['id'], 'cover': true},
      ...(row['photos'] as List? ?? const []).map(_map),
    ];
    await showDialog<void>(
      context: context,
      builder: (context) => LaooActionDialog(
        tokens: providerTokens,
        icon: Icons.collections_outlined,
        title: '${row['title']}',
        width: 760,
        content: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: photos
              .map(
                (photo) => SizedBox(
                  width: 210,
                  height: 150,
                  child: Image.network(
                    photo['cover'] == true
                        ? '/api/public/providers/portfolio/${photo['id']}/cover'
                        : '/api/public/providers/portfolio/photos/${photo['id']}',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.broken_image_outlined),
                  ),
                ),
              )
              .toList(),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ปิด'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(Map<String, dynamic> row) async {
    final accepted =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 34),
            title: const Text(
              'ยืนยันการลบ',
              style: TextStyle(color: Colors.red),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('${row['title']}'),
                ),
                const SizedBox(height: 10),
                const Text('เมื่อลบแล้วไม่สามารถเรียกคืนได้'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('ยกเลิก'),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.delete_outline),
                label: const Text('ลบ'),
              ),
            ],
          ),
        ) ==
        true;
    if (!accepted) return;
    try {
      await api.delete('/api/company/provider/portfolio/${row['id']}');
      if (mounted) providerMessage(context, 'ลบผลงานแล้ว');
      await load(nextPage: items.length == 1 && page > 1 ? page - 1 : page);
    } catch (_) {
      if (mounted) providerMessage(context, 'ลบผลงานไม่สำเร็จ', error: true);
    }
  }

  InputDecoration _input(String label, [IconData? icon]) => InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(fontSize: 14),
    prefixIcon: icon == null ? null : Icon(icon),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(4),
      borderSide: BorderSide(color: providerTokens.borderColor),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(4),
      borderSide: BorderSide(color: providerTokens.borderColor),
    ),
  );

  ButtonStyle get _filledStyle => FilledButton.styleFrom(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
  );
  static Map<String, dynamic> _map(dynamic value) =>
      Map<String, dynamic>.from(value as Map);
  static String _date(dynamic value) {
    final text = '$value';
    return text.length >= 10 ? text.substring(0, 10) : text;
  }
}
