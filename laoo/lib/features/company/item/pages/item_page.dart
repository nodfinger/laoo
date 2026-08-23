import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../../app/theme/laoo_typography.dart';
import '../../../../app/theme/workspace_theme_presets.dart';
import '../../../../core/company_setup/company_setup_controller.dart';
import '../../../../core/widgets/timed_snack_bar.dart';
import '../../../../features/support/master_data/data/master_data_api.dart';
import '../../../../features/support/presentation/widgets/support_workspace_shell.dart';
import '../data/item_api.dart';
import 'item_form_layout.dart';

typedef _ItemForm = ItemFormLayout;

class ItemPage extends StatefulWidget {
  const ItemPage({super.key, required this.activeMenu});
  final String activeMenu;
  @override
  State<ItemPage> createState() => _ItemPageState();
}

class _ItemPageState extends State<ItemPage> {
  final _api = ItemApi();
  final _master = MasterDataApi();
  final _search = TextEditingController();
  final _tableHorizontal = ScrollController();
  List<Map<String, dynamic>> _rows = const [];
  List<Map<String, dynamic>> _groups = const [],
      _types = const [],
      _units = const [];
  Map<String, bool> _actions = const {};
  String? _group, _type;
  String _statusFilter = 'all', _showFilter = 'all';
  bool _card = false, _loading = true, _showImages = true;
  int _currentPage = 0;
  Map<String, dynamic>? _editing;
  String? _message;
  Timer? _timer;

  int get _pageSize => companySetupController.pageSize > 0
      ? companySetupController.pageSize
      : 20;
  List<Map<String, dynamic>> get _filteredRows => _rows.where((x) {
    final statusOk =
        _statusFilter == 'all' ||
        (_statusFilter == 'active'
            ? x['isActive'] == true
            : x['isActive'] != true);
    final showOk =
        _showFilter == 'all' ||
        (_showFilter == 'online'
            ? x['showShop'] == true
            : x['showShop'] != true);
    return statusOk && showOk;
  }).toList();
  int get _totalPages =>
      _filteredRows.isEmpty ? 1 : (_filteredRows.length / _pageSize).ceil();
  List<Map<String, dynamic>> get _visibleRows {
    final page = _currentPage.clamp(0, _totalPages - 1);
    final start = page * _pageSize;
    return _filteredRows.skip(start).take(_pageSize).toList();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _search.dispose();
    _tableHorizontal.dispose();
    _api.dispose();
    _master.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final result = await Future.wait([
        _api.actions(),
        _api.list(groupCode: _group, typeCode: _type, search: _search.text),
        _master.list('006'),
        _master.list('007'),
        _master.list('002'),
      ]);
      if (!mounted) return;
      setState(() {
        _actions = result[0] as Map<String, bool>;
        _rows = result[1] as List<Map<String, dynamic>>;
        _groups = result[2] as List<Map<String, dynamic>>;
        _types = result[3] as List<Map<String, dynamic>>;
        _units = result[4] as List<Map<String, dynamic>>;
        _currentPage = _currentPage.clamp(0, _totalPages - 1);
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _show(e.toString());
      }
    }
  }

  void _show(String text) {
    _timer?.cancel();
    setState(() => _message = text);
    _timer = Timer(
      Duration(seconds: companySetupController.current?.timeAlert ?? 30),
      () {
        if (mounted) setState(() => _message = null);
      },
    );
  }

  Future<void> _showPackUnitsDialog(Map<String, dynamic> item) async {
    final accent = workspaceThemeController.value.primary;
    try {
      final detail = await _api.get((item['itemID'] as num).toInt());
      item = {...item, 'packUnits': detail['packUnits']};
    } catch (error) {
      if (mounted) _show('ไม่สามารถอ่านอัตราส่วนการบรรจุได้: $error');
      return;
    }
    final packs = item['packUnits'] is List
        ? List<Map<String, dynamic>>.from(item['packUnits'] as List)
        : <Map<String, dynamic>>[];
    String? newUnit = _units.isNotEmpty ? '${_units.first['code']}' : null;
    String? newParentUnit = _units.length > 1
        ? '${_units[1]['code']}'
        : newUnit;
    final newQuantity = TextEditingController(text: '1');
    final canEdit = _actions['edit'] == true;
    final canDelete = _actions['delete'] == true;
    String? dialogError;
    bool draftTouched = false;
    Map<String, dynamic>? buildDraftPack() {
      final unitCode = newUnit?.trim() ?? '';
      final parentUnitCode = newParentUnit?.trim() ?? '';
      final quantity = double.tryParse(newQuantity.text.trim());
      if (unitCode.isEmpty ||
          parentUnitCode.isEmpty ||
          quantity == null ||
          quantity <= 0) {
        return null;
      }
      return <String, dynamic>{
        'unitCode': unitCode,
        'conversionQuantity': quantity,
        'parentUnitCode': parentUnitCode,
        'isDefault': false,
        'baseQuantity': 1,
        'sortOrder': packs.length + 1,
      };
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
          contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
          actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: accent, width: 1.2),
          ),
          title: Row(
            children: [
              Icon(Icons.inventory_2_outlined, color: accent),
              const SizedBox(width: 8),
              const Expanded(child: Text('อัตราส่วนการบรรจุสินค้า')),
            ],
          ),
          content: SizedBox(
            width: 560,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${item['itemCode'] ?? ''} - ${item['itemName'] ?? ''}',
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  color: accent.withValues(alpha: .10),
                  child: DefaultTextStyle.merge(
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w700,
                    ),
                    child: Stack(
                      children: [
                          const Row(
                        children: [
                          SizedBox(
                            width: 70,
                            child: Text('จำนวน', textAlign: TextAlign.left),
                          ),
                          SizedBox(width: 12),
                          Expanded(child: Text('หน่วยย่อยคิดเป็น')),
                          SizedBox(width: 12),
                          Expanded(child: Text('หน่วยใหญ่')),
                          SizedBox.shrink(),
                        ],
                      ),
                      Positioned(
                        top: 0,
                        right: 0,
                        bottom: 0,
                        width: 64,
                        child: Container(
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: .10),
                          ),
                          child: Center(
                            child: Text(
                              'Action',
                              style: TextStyle(
                                color: accent,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                      ],
                    ),
                  ),
                ),
                ...packs.asMap().entries.map((entry) {
                  final index = entry.key;
                  final pack = entry.value;
                  return Column(
                    children: [
                      Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 70,
                          child: Text(
                            '${pack['conversionQuantity'] ?? 0}',
                            textAlign: TextAlign.left,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '${pack['unitName'] ?? pack['unitCode'] ?? ''}',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '${pack['parentUnitName'] ?? pack['parentUnitCode'] ?? ''}',
                          ),
                        ),
                        if (false)
                          Text(
                            pack['isActive'] == false ? 'ไม่ใช้งาน' : 'ใช้งาน',
                            style: TextStyle(
                              color: pack['isActive'] == false
                                  ? Colors.red
                                  : accent,
                            ),
                          ),
                        if (canEdit || canDelete)
                          SizedBox(
                            width: 64,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (canEdit)
                                  IconButton(
                                    tooltip: 'Edit pack unit',
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                    onPressed: () {
                                      setDialogState(() {
                                        final selected = packs.removeAt(index);
                                        newUnit = '${selected['unitCode']}';
                                        newParentUnit =
                                            '${selected['parentUnitCode'] ?? ''}';
                                        newQuantity.text =
                                            '${selected['conversionQuantity'] ?? 1}';
                                      });
                                    },
                                    icon: Icon(
                                      Icons.edit_outlined,
                                      color: accent,
                                      size: 20,
                                    ),
                                  ),
                                if (canDelete)
                                  IconButton(
                                    tooltip: 'Delete pack unit',
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                    onPressed: () async {
                                      final confirmed = await showDialog<bool>(
                                        context: dialogContext,
                                        builder: (confirmContext) => AlertDialog(
                                          backgroundColor: Colors.white,
                                          surfaceTintColor: Colors.transparent,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(16),
                                            side: const BorderSide(
                                              color: Colors.red,
                                              width: 1.2,
                                            ),
                                          ),
                                          titlePadding: const EdgeInsets.fromLTRB(
                                            24,
                                            22,
                                            24,
                                            0,
                                          ),
                                          contentPadding: const EdgeInsets.fromLTRB(
                                            24,
                                            16,
                                            24,
                                            0,
                                          ),
                                          title: Column(
                                            children: [
                                              Container(
                                                width: double.infinity,
                                                padding: const EdgeInsets.symmetric(
                                                  vertical: 8,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.red.withValues(alpha: .10),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: const Icon(
                                                  Icons.delete_outline,
                                                  color: Colors.red,
                                                ),
                                              ),
                                              const SizedBox(height: 14),
                                              const Text(
                                                'ยืนยันการลบข้อมูล',
                                                style: TextStyle(
                                                  color: Colors.red,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ],
                                          ),
                                          content: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                width: double.infinity,
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 10,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.red.withValues(alpha: .08),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  'ต้องการลบหน่วย ${pack['unitName'] ?? pack['unitCode'] ?? ''} หรือไม่?',
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),
                                              const SizedBox(height: 12),
                                              const Align(
                                                alignment: Alignment.centerLeft,
                                                child: Text(
                                                  'ข้อมูลที่ลบแล้วไม่สามารถเรียกคืนกลับมาได้',
                                                  style: TextStyle(fontSize: 12),
                                                ),
                                              ),
                                            ],
                                          ),
                                          actionsPadding: const EdgeInsets.fromLTRB(
                                            24,
                                            8,
                                            24,
                                            18,
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(confirmContext, false),
                                              child: Text(
                                                'ยกเลิก',
                                                style: TextStyle(color: accent),
                                              ),
                                            ),
                                            FilledButton.icon(
                                              onPressed: () =>
                                                  Navigator.pop(confirmContext, true),
                                              icon: const Icon(Icons.delete_outline),
                                              label: const Text('ลบ'),
                                              style: FilledButton.styleFrom(
                                                backgroundColor: Colors.red,
                                                foregroundColor: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirmed == true) {
                                        try {
                                          final rawPackId =
                                              pack['itemPackUnitID'] ??
                                              pack['itemPackUnitId'];
                                          if (rawPackId is num) {
                                            await _api.deletePackUnit(
                                              (item['itemID'] as num).toInt(),
                                              rawPackId.toInt(),
                                            );
                                          }
                                          if (mounted) {
                                            setDialogState(
                                              () => packs.removeAt(index),
                                            );
                                          }
                                        } catch (error) {
                                          if (mounted) {
                                            setDialogState(() {
                                              dialogError =
                                                  'ลบหน่วยบรรจุไม่สำเร็จ: $error';
                                            });
                                          }
                                        }
                                      }
                                    },
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.red,
                                      size: 20,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                      ],
                    ),
                      ),
                      if (index < packs.length - 1)
                        const Divider(
                          height: 1,
                          thickness: 1,
                          color: Color(0xFFD1D5DB),
                          indent: 12,
                          endIndent: 12,
                        ),
                    ],
                  );
                }),
                const Divider(height: 1),
                const SizedBox(height: 18),
                Row(
                  children: [
                    SizedBox(
                      width: 90,
                      child: TextField(
                        controller: newQuantity,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 12),
                        decoration: const InputDecoration(labelText: 'จำนวน'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: newUnit,
                        style: const TextStyle(fontSize: 12),
                        decoration: const InputDecoration(
                          labelText: 'หน่วยย่อยคิดเป็น',
                        ),
                        items: _units
                            .map(
                              (unit) => DropdownMenuItem<String>(
                                value: '${unit['code']}',
                                child: Text(
                                  '${unit['name']}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => setDialogState(() {
                          newUnit = value;
                          draftTouched = true;
                          final normalized = (value ?? '').trim().toUpperCase();
                          dialogError = packs.any(
                            (pack) =>
                                '${pack['unitCode']}'.trim().toUpperCase() ==
                                normalized,
                          )
                              ? 'หน่วยย่อยซ้ำกัน กรุณาเลือกหน่วยอื่น'
                              : null;
                        }),
                      ),
                    ),
                    const SizedBox(width: 10),
                    if (false)
                      SizedBox(
                      width: 90,
                      child: TextField(
                        controller: newQuantity,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 12),
                        decoration: const InputDecoration(labelText: 'จำนวน'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: newParentUnit,
                        style: const TextStyle(fontSize: 12),
                        decoration: const InputDecoration(
                          labelText: 'หน่วยใหญ่',
                        ),
                        items: _units
                            .map(
                              (unit) => DropdownMenuItem<String>(
                                value: '${unit['code']}',
                                child: Text(
                                  '${unit['name']}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setDialogState(() => newParentUnit = value),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (dialogError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      dialogError!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: canEdit
                      ? () {
                          final draft = buildDraftPack();
                          if (draft == null) {
                            setDialogState(() {
                              dialogError = 'กรุณาระบุข้อมูลหน่วยบรรจุให้ครบถ้วน';
                            });
                            _show(
                              'กรุณาเลือกหน่วยย่อย หน่วยใหญ่ และระบุจำนวนมากกว่า 0',
                            );
                            return;
                          }
                          final unitCode = '${draft['unitCode']}'.toUpperCase();
                          if (packs.any(
                            (pack) =>
                                '${pack['unitCode']}'.trim().toUpperCase() ==
                                unitCode.trim(),
                          )) {
                            setDialogState(() {
                              dialogError = 'หน่วยย่อยซ้ำกัน กรุณาเลือกหน่วยอื่น';
                            });
                            _show('หน่วยย่อยนี้มีอยู่ในรายการแล้ว');
                            return;
                          }
                          setDialogState(() {
                            packs.add(draft);
                            dialogError = null;
                            draftTouched = false;
                            newQuantity.text = '1';
                          });
                        }
                      : null,
                  icon: const Icon(Icons.add),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: accent,
                    side: BorderSide(color: accent),
                  ),
                  label: const Text('เพิ่มอัตราส่วน'),
                ),
              ],
            ),
          ),
          actions: [
            FilledButton(
              onPressed: canEdit
                  ? () async {
                      try {
                        final payload = packs
                            .map((pack) => Map<String, dynamic>.from(pack))
                            .toList();
                        final draft = buildDraftPack();
                        if (draft != null) {
                          final draftUnit = '${draft['unitCode']}'
                              .toUpperCase();
                          final alreadyAdded = payload.any(
                            (pack) =>
                                '${pack['unitCode']}'.toUpperCase() ==
                                draftUnit,
                          );
                          if (alreadyAdded && draftTouched) {
                            setDialogState(() {
                              dialogError = 'หน่วยย่อยซ้ำกัน กรุณาเลือกหน่วยอื่น';
                            });
                            return;
                          }
                          if (!alreadyAdded) payload.add(draft);
                        }
                        if (payload.isEmpty) {
                          _show(
                            'กรุณาเพิ่มอัตราส่วนการบรรจุอย่างน้อย 1 รายการ',
                          );
                          return;
                        }
                        for (var index = 0; index < payload.length; index++) {
                          payload[index]['sortOrder'] = index + 1;
                        }
                        final saved = await _api.savePackUnits(
                          (item['itemID'] as num).toInt(),
                          payload,
                        );
                        if (saved.length != payload.length) {
                          throw StateError(
                            'API บันทึกข้อมูลไม่ครบ กรุณาลองใหม่อีกครั้ง',
                          );
                        }
                        setDialogState(() {
                          packs
                            ..clear()
                            ..addAll(saved);
                        });
                        if (mounted) _show('บันทึกอัตราส่วนการบรรจุสำเร็จ');
                      } catch (error) {
                        if (mounted)
                          _show('บันทึกอัตราส่วนการบรรจุไม่สำเร็จ: $error');
                      }
                    }
                  : null,
              style: FilledButton.styleFrom(backgroundColor: accent),
              child: const Text('บันทึก'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              style: TextButton.styleFrom(foregroundColor: accent),
              child: const Text('ปิด'),
            ),
          ],
        ),
      ),
    );
    newQuantity.dispose();
  }

  Future<void> _edit(Map<String, dynamic> row) async {
    if (_actions['edit'] != true) {
      _show('ผู้ใช้งานไม่มีสิทธิ์แก้ไขข้อมูลสินค้า (EDIT)');
      return;
    }
    try {
      final detail = await _api.get((row['itemID'] as num).toInt());
      if (mounted) setState(() => _editing = detail);
    } catch (e) {
      if (mounted) {
        _show('ไม่สามารถเปิดหน้าแก้ไขสินค้าได้: $e');
      }
    }
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    final ok =
        await showDialog<bool>(
          context: context,
          builder: (c) {
            final accent = workspaceThemeController.value.primary;
            return AlertDialog(
              backgroundColor: const Color(0xFFF7FBF8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Colors.red, width: 1.2),
              ),
              titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 0),
              contentPadding: const EdgeInsets.fromLTRB(22, 16, 22, 0),
              actionsPadding: const EdgeInsets.fromLTRB(22, 8, 22, 18),
              title: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.delete_outline,
                      color: Colors.red,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'ยืนยันการลบข้อมูล',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'ต้องการลบ ${row['itemCode']} - ${row['itemName']} หรือไม่?',
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('ข้อมูลที่ลบแล้วไม่สามารถเรียกคืนกลับมาได้'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(c, false),
                  style: TextButton.styleFrom(foregroundColor: accent),
                  child: const Text('ยกเลิก'),
                ),
                FilledButton.icon(
                  onPressed: () => Navigator.pop(c, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('ลบ'),
                ),
              ],
            );
          },
        ) ??
        false;
    if (!ok) return;
    try {
      await _api.delete((row['itemID'] as num).toInt());
      _show('ลบสินค้าสำเร็จ');
      await _load();
    } catch (e) {
      _show(e.toString());
    }
  }

  Future<void> _setVisibility(
    Map<String, dynamic> row, {
    bool? isActive,
    bool? showShop,
  }) async {
    final oldActive = row['isActive'] == true;
    final oldShowShop = row['showShop'] == true;
    final nextActive = isActive ?? oldActive;
    final nextShowShop = showShop ?? oldShowShop;
    setState(() {
      row['isActive'] = nextActive;
      row['showShop'] = nextShowShop;
    });
    try {
      await _api.updateVisibility(
        (row['itemID'] as num).toInt(),
        isActive: nextActive,
        showShop: nextShowShop,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        row['isActive'] = oldActive;
        row['showShop'] = oldShowShop;
      });
      _show(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) => SupportWorkspaceShell(
    pageTitle: _editing == null
        ? 'ข้อมูลสินค้า'
        : 'ข้อมูลสินค้า > ${_editing!['itemID'] == null ? 'เพิ่ม' : 'แก้ไข'}',
    activeMenu: widget.activeMenu,
    menuScope: WorkspaceMenuScope.company,
    child: _editing == null
        ? _list()
        : _ItemForm(
            initial: _editing,
            groups: _groups,
            types: _types,
            units: _units,
            onCancel: () => setState(() => _editing = null),
            onSaved: () {
              setState(() => _editing = null);
              _show('บันทึกข้อมูลสินค้าสำเร็จ');
              _load();
            },
          ),
  );

  Widget _list() => Stack(
    children: [
      Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: Row(
              children: [
                const Expanded(
                  child: WorkspacePageTitle(
                    title: 'ข้อมูลสินค้า',
                    favoriteKey: '08001',
                  ),
                ),
                if (!_card && MediaQuery.sizeOf(context).width >= 1200)
                  IconButton(
                    tooltip: 'สลับมุมมอง',
                    onPressed: () => setState(() => _card = !_card),
                    icon: const Icon(Icons.grid_view_outlined),
                  ),
                if (_actions['create'] == true)
                  FilledButton.icon(
                    onPressed: () => setState(() => _editing = {}),
                    icon: const Icon(Icons.add),
                    label: const Text('เพิ่ม'),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final filterWidth = constraints.maxWidth < 700
                    ? ((constraints.maxWidth - 8) / 2).clamp(140.0, 240.0)
                    : ((constraints.maxWidth - 32) / 5).clamp(140.0, 240.0);
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: filterWidth,
                      child: _filter('กลุ่มสินค้า', _group, _groups, (v) {
                        _group = v;
                        _currentPage = 0;
                        _load();
                      }),
                    ),
                    SizedBox(
                      width: filterWidth,
                      child: _filter('ประเภทสินค้า', _type, _types, (v) {
                        _type = v;
                        _currentPage = 0;
                        _load();
                      }),
                    ),
                    SizedBox(
                      width: filterWidth,
                      child: TextField(
                        controller: _search,
                        onSubmitted: (_) => _load(),
                        decoration: InputDecoration(
                          labelText: 'ค้นหารหัส/ชื่อสินค้า',
                          suffixIcon: IconButton(
                            onPressed: _load,
                            icon: const Icon(Icons.arrow_forward),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: filterWidth,
                      child: DropdownButtonFormField<String>(
                        initialValue: _statusFilter,
                        decoration: const InputDecoration(labelText: 'สถานะ'),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: LaooTypography.tableBody,
                          height: 1.35,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'all',
                            child: Text('ทั้งหมด'),
                          ),
                          DropdownMenuItem(
                            value: 'active',
                            child: Text('ใช้งาน'),
                          ),
                          DropdownMenuItem(
                            value: 'inactive',
                            child: Text('ไม่ใช้งาน'),
                          ),
                        ],
                        onChanged: (v) => setState(() {
                          _statusFilter = v ?? 'all';
                          _currentPage = 0;
                        }),
                      ),
                    ),
                    SizedBox(
                      width: filterWidth,
                      child: DropdownButtonFormField<String>(
                        initialValue: _showFilter,
                        decoration: const InputDecoration(labelText: 'แสดง'),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: LaooTypography.tableBody,
                          height: 1.35,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'all',
                            child: Text('ทั้งหมด'),
                          ),
                          DropdownMenuItem(
                            value: 'online',
                            child: Text('Online'),
                          ),
                          DropdownMenuItem(
                            value: 'offline',
                            child: Text('Offline'),
                          ),
                        ],
                        onChanged: (v) => setState(() {
                          _showFilter = v ?? 'all';
                          _currentPage = 0;
                        }),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : (_card || MediaQuery.sizeOf(context).width < 1200)
                ? _cardsV2()
                : _table(),
          ),
          const SizedBox(height: 10),
          _paginationBar(),
        ],
      ),
      if (_message != null)
        Positioned(
          top: 12,
          right: 24,
          child: _Alert(
            text: _message!,
            onClose: () => setState(() => _message = null),
          ),
        ),
    ],
  );

  Widget _filter(
    String label,
    String? value,
    List<Map<String, dynamic>> values,
    ValueChanged<String?> onChanged,
  ) => DropdownButtonFormField<String>(
    initialValue: value,
    decoration: InputDecoration(labelText: label),
    style: Theme.of(context).textTheme.bodySmall?.copyWith(
      fontSize: LaooTypography.tableBody,
      height: 1.35,
    ),
    items: values
        .map(
          (x) => DropdownMenuItem(
            value: '${x['code']}',
            child: Text(
              '${x['name']}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: LaooTypography.tableBody,
                height: 1.35,
              ),
            ),
          ),
        )
        .toList(),
    onChanged: onChanged,
  );

  Widget _table() {
    final theme = Theme.of(context);
    final accent = workspaceThemeController.value.primary;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: accent.withValues(alpha: .55), width: .8),
        ),
        clipBehavior: Clip.antiAlias,
        child: LayoutBuilder(
          builder: (context, constraints) => SizedBox(
            width: constraints.maxWidth,
            child: DataTableTheme(
              data: DataTableThemeData(
                headingTextStyle: TextStyle(
                  fontSize: LaooTypography.tableHeader,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
              child: DataTable(
                horizontalMargin: 6,
                columnSpacing: 2,
                dataRowMinHeight: 58,
                dataRowMaxHeight: 64,
                headingRowColor: WidgetStatePropertyAll(
                  accent.withValues(alpha: .10),
                ),
                headingTextStyle: TextStyle(
                  fontSize: LaooTypography.tableHeader,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
                dataTextStyle: TextStyle(
                  fontSize: LaooTypography.tableBody,
                  color: theme.colorScheme.onSurface,
                ),
                border: TableBorder(
                  top: BorderSide(
                    color: accent.withValues(alpha: .45),
                    width: .6,
                  ),
                  bottom: BorderSide(
                    color: accent.withValues(alpha: .45),
                    width: .6,
                  ),
                  horizontalInside: BorderSide(
                    color: theme.dividerColor,
                    width: .45,
                  ),
                ),
                columns: [
                  DataColumn(
                    label: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: SizedBox(width: 48, child: Text('ID')),
                    ),
                  ),
                  const DataColumn(label: Text('รูปสินค้า')),
                  DataColumn(
                    numeric: true,
                    label: SizedBox(
                      width: 84,
                      child: Center(child: Text('Action')),
                    ),
                  ),
                  DataColumn(
                    label: SizedBox(width: 78, child: Text('รหัสสินค้า')),
                  ),
                  DataColumn(
                    label: SizedBox(width: 220, child: Text('ชื่อสินค้า')),
                  ),
                  DataColumn(
                    numeric: true,
                    label: SizedBox(
                      width: 78,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text('ราคาขาย'),
                      ),
                    ),
                  ),
                  DataColumn(
                    numeric: true,
                    label: SizedBox(width: 52, child: Text('สต๊อกคงเหลือ')),
                  ),
                  DataColumn(
                    label: SizedBox(
                      width: 48,
                      child: Text(
                        'หน่วยบรรจุ',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: SizedBox(
                      width: 68,
                      child: Center(child: Text('สถานะ')),
                    ),
                  ),
                  DataColumn(
                    label: SizedBox(
                      width: 68,
                      child: Center(child: Text('แสดง')),
                    ),
                  ),
                ],
                rows: _visibleRows.asMap().entries.map((e) {
                  final x = e.value;
                  final cells = <DataCell>[
                    DataCell(
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text(
                          '${(_currentPage * _pageSize) + e.key + 1}',
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 42,
                        child: _cover(x['coverImageBase64'], 24),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 84,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_actions['edit'] == true)
                              IconButton(
                                onPressed: () => _edit(x),
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                                constraints: const BoxConstraints.tightFor(
                                  width: 24,
                                  height: 32,
                                ),
                                icon: Icon(Icons.edit_outlined, color: accent),
                              ),
                            IconButton(
                              tooltip: 'อัตราส่วนการบรรจุ',
                              onPressed: () => _showPackUnitsDialog(x),
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                              constraints: const BoxConstraints.tightFor(
                                width: 24,
                                height: 32,
                              ),
                              icon: Icon(
                                Icons.inventory_2_outlined,
                                color: accent,
                              ),
                            ),
                            if (_actions['delete'] == true)
                              IconButton(
                                onPressed: () => _delete(x),
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                                constraints: const BoxConstraints.tightFor(
                                  width: 24,
                                  height: 32,
                                ),
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 78,
                        child: Text(
                          '${x['itemCode']}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    DataCell(Text('${x['itemName']}')),
                    DataCell(
                      SizedBox(
                        width: 68,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: _actions['edit'] == true
                              ? () => _setVisibility(
                                  x,
                                  isActive: x['isActive'] != true,
                                )
                              : null,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: x['isActive'] == true
                                  ? accent.withValues(alpha: .14)
                                  : Colors.red.withValues(alpha: .14),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              x['isActive'] == true ? 'ใช้งาน' : 'ไม่ใช้งาน',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: x['isActive'] == true
                                    ? accent
                                    : Colors.red,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 68,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: _actions['edit'] == true
                              ? () => _setVisibility(
                                  x,
                                  showShop: x['showShop'] != true,
                                )
                              : null,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: x['showShop'] == true
                                  ? accent.withValues(alpha: .14)
                                  : Colors.red.withValues(alpha: .14),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              x['showShop'] == true ? 'Online' : 'Offline',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: x['showShop'] == true
                                    ? accent
                                    : Colors.red,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 78,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text('${x['unitPrice']}'),
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 52,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text('${x['stockBalance']}'),
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 48,
                        child: Text(
                          '${x['unitCode']}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ];
                  return DataRow(
                    cells: [
                      cells[0],
                      cells[1],
                      cells[2],
                      cells[3],
                      cells[4],
                      cells[7],
                      cells[8],
                      cells[9],
                      cells[5],
                      cells[6],
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _paginationBar() {
    final total = _filteredRows.length;
    final start = total == 0 ? 0 : _currentPage * _pageSize + 1;
    final end = total == 0 ? 0 : (start + _pageSize - 1).clamp(0, total);
    final accent = workspaceThemeController.value.primary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          spacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _pageButton(
              Icons.chevron_left_rounded,
              _currentPage > 0 ? () => setState(() => _currentPage--) : null,
              accent,
            ),
            for (var page = 0; page < _totalPages; page++)
              _numberButton(page, accent),
            _pageButton(
              Icons.chevron_right_rounded,
              _currentPage + 1 < _totalPages
                  ? () => setState(() => _currentPage++)
                  : null,
              accent,
            ),
            Text('$start-$end จาก $total'),
          ],
        ),
      ),
    );
  }

  Widget _pageButton(IconData icon, VoidCallback? onPressed, Color accent) {
    return SizedBox(
      width: 34,
      height: 34,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor: onPressed == null
              ? Theme.of(context).disabledColor.withValues(alpha: .18)
              : accent,
          foregroundColor: onPressed == null
              ? Theme.of(context).disabledColor
              : Colors.white,
          shape: const CircleBorder(),
        ),
        child: Icon(icon, size: 20),
      ),
    );
  }

  Widget _numberButton(int page, Color accent) {
    final active = page == _currentPage;
    return SizedBox(
      width: 34,
      height: 34,
      child: active
          ? FilledButton(
              onPressed: () {},
              style: FilledButton.styleFrom(
                padding: EdgeInsets.zero,
                backgroundColor: accent,
                shape: const CircleBorder(),
              ),
              child: Text('${page + 1}'),
            )
          : OutlinedButton(
              onPressed: () => setState(() => _currentPage = page),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.zero,
                shape: const CircleBorder(),
              ),
              child: Text('${page + 1}'),
            ),
    );
  }

  Widget _cards() => ListView.separated(
    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
    itemCount: _visibleRows.length,
    separatorBuilder: (_, _) => const SizedBox(height: 10),
    itemBuilder: (_, i) {
      final x = _visibleRows[i];
      final cover = x['coverImageBase64'];
      return Card(
        child: ListTile(
          leading: cover is String && cover.isNotEmpty
              ? Image.memory(
                  base64Decode(cover),
                  width: 54,
                  height: 54,
                  fit: BoxFit.cover,
                )
              : const Icon(Icons.inventory_2_outlined, size: 42),
          title: Text('${x['itemCode']} - ${x['itemName']}'),
          subtitle: Text(
            'ราคา ${x['unitPrice']} | หน่วย ${x['unitCode']} | สต๊อก ${x['stockBalance']}',
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_actions['edit'] == true)
                IconButton(
                  onPressed: () => _edit(x),
                  icon: Icon(
                    Icons.edit_outlined,
                    color: workspaceThemeController.value.primary,
                  ),
                ),
              if (_actions['delete'] == true)
                IconButton(
                  onPressed: () => _delete(x),
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                ),
            ],
          ),
        ),
      );
    },
  );

  Widget _cover(Object? value, double size) {
    if (value is String && value.isNotEmpty) {
      try {
        return GestureDetector(
          onTap: () => showDialog<void>(
            context: context,
            builder: (_) => Dialog(
              child: InteractiveViewer(
                child: Image.memory(base64Decode(value)),
              ),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.memory(
              base64Decode(value),
              width: size,
              height: size,
              fit: BoxFit.cover,
            ),
          ),
        );
      } catch (_) {}
    }
    return SizedBox(
      width: size,
      height: size,
      child: Icon(Icons.inventory_2_outlined, size: size * .7),
    );
  }

  Widget _cardsV2() => ListView.separated(
    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
    itemCount: _visibleRows.length,
    separatorBuilder: (_, _) => const SizedBox(height: 10),
    itemBuilder: (_, i) {
      final x = _visibleRows[i];
      final accent = workspaceThemeController.value.primary;
      final active = x['isActive'] == true;
      return Card(
        color: Colors.white,
        elevation: 2,
        shadowColor: accent.withValues(alpha: .18),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: accent.withValues(alpha: .12)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (_actions['edit'] == true) ...[
                          Switch(
                            value: active,
                            onChanged: (value) =>
                                _setVisibility(x, isActive: value),
                          ),
                          const Text('ใช้งาน'),
                          Switch(
                            value: x['showShop'] == true,
                            onChanged: (value) =>
                                _setVisibility(x, showShop: value),
                          ),
                          const Text('Online'),
                        ],
                      ],
                    ),
                  ),
                  if (_actions['edit'] == true)
                    IconButton(
                      tooltip: 'แก้ไข',
                      onPressed: () => _edit(x),
                      icon: Icon(Icons.edit_outlined, color: accent),
                    ),
                  IconButton(
                    tooltip: 'อัตราส่วนการบรรจุ',
                    onPressed: () => _showPackUnitsDialog(x),
                    icon: Icon(Icons.inventory_2_outlined, color: accent),
                  ),
                  if (_actions['delete'] == true)
                    IconButton(
                      tooltip: 'ลบ',
                      onPressed: () => _delete(x),
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  if (_showImages) ...[
                    _cover(x['coverImageBase64'], 42),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Text(
                      '${x['itemCode']} | ${x['itemName']}',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.w700,
                        fontSize: LaooTypography.tableBody,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'ราคาขาย ${x['unitPrice']}  |  หน่วยบรรจุ ${x['unitCode']}  |  สต๊อกขั้นต่ำ ${x['minStock']}',
                style: TextStyle(
                  fontSize: LaooTypography.tableBody,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/*
class _ItemForm extends StatefulWidget {
  const _ItemForm({this.initial, required this.groups, required this.types, required this.units, required this.onCancel, required this.onSaved});
  final Map<String, dynamic>? initial; final List<Map<String, dynamic>> groups, types, units; final VoidCallback onCancel, onSaved;
  @override State<_ItemForm> createState() => _ItemFormState();
}

class _ItemFormState extends State<_ItemForm> {
  final _form = GlobalKey<FormState>(); late final Map<String, dynamic> _data; late final TextEditingController _code, _name, _price, _cost, _min, _purchase; String? _group, _type, _unit; bool _active = true, _saving = false; List<Map<String, dynamic>> _packs = []; List<Map<String, dynamic>> _images = [];
  @override void initState() { super.initState(); _data = widget.initial ?? {}; _code = TextEditingController(text: '${_data['itemCode'] ?? ''}'); _name = TextEditingController(text: '${_data['itemName'] ?? ''}'); _price = TextEditingController(text: '${_data['unitPrice'] ?? 0}'); _cost = TextEditingController(text: '${_data['costPrice'] ?? 0}'); _min = TextEditingController(text: '${_data['minStock'] ?? 0}'); _purchase = TextEditingController(text: '${_data['purchaseQuantity'] ?? 0}'); _group = _data['itemGroupCode']; _type = _data['itemTypeCode']; _unit = _data['unitCode']; _active = _data['isActive'] != false; _packs = List<Map<String, dynamic>>.from(_data['packUnits'] ?? []); _images = List<Map<String, dynamic>>.from(_data['images'] ?? []); }
  @override void dispose() { for (final c in [_code, _name, _price, _cost, _min, _purchase]) c.dispose(); super.dispose(); }
  Future<void> _pickImage() async { if (_images.length >= 5) return; final f = await FilePicker.platform.pickFiles(type: FileType.image, withData: true); if (f?.files.single.bytes == null) return; final file = f!.files.single; setState(() => _images.add({'contentType': file.extension == 'png' ? 'image/png' : 'image/jpeg', 'fileName': file.name, 'isCover': _images.isEmpty, 'sortOrder': _images.length + 1, 'imageDataBase64': base64Encode(file.bytes!)})); }
  Future<void> _save() async { if (!_form.currentState!.validate()) return; setState(() => _saving = true); final body = {'itemCode': _code.text.trim(), 'itemName': _name.text.trim(), 'itemGroupCode': _group, 'itemTypeCode': _type, 'unitPrice': double.tryParse(_price.text) ?? 0, 'unitCode': _unit, 'costPrice': double.tryParse(_cost.text) ?? 0, 'minStock': double.tryParse(_min.text) ?? 0, 'purchaseQuantity': double.tryParse(_purchase.text) ?? 0, 'isActive': _active, 'packUnits': _packs, 'images': _images}; try { final api = ItemApi(); if (_data['itemID'] == null) { await api.create(body); } else { await api.update((_data['itemID'] as num).toInt(), body); } api.dispose(); widget.onSaved(); } catch (e) { if (mounted) { setState(() => _saving = false); showTimedSnackBar(context, message: e.toString(), error: true); } } }
  @override Widget build(BuildContext context) => Form(key: _form, child: ListView(padding: const EdgeInsets.all(24), children: [Row(children: [Expanded(child: WorkspacePageTitle(title: 'ข้อมูลสินค้า > ${_data['itemID'] == null ? 'เพิ่ม' : 'แก้ไข'}')), TextButton(onPressed: widget.onCancel, child: const Text('ยกเลิก')), const SizedBox(width: 8), FilledButton(onPressed: _saving ? null : _save, child: const Text('บันทึก'))]), const SizedBox(height: 12), _drop('กลุ่มสินค้า', _group, widget.groups, (v) => setState(() => _group = v)), _drop('ประเภทสินค้า', _type, widget.types, (v) => setState(() => _type = v)), TextFormField(controller: _code, decoration: const InputDecoration(labelText: 'รหัสสินค้า'), validator: (v) => v == null || v.trim().isEmpty ? 'กรุณาระบุรหัสสินค้า' : null), TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'ชื่อสินค้า'), validator: (v) => v == null || v.trim().isEmpty ? 'กรุณาระบุชื่อสินค้า' : null), TextFormField(controller: _price, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'ราคาขายมาตรฐาน')), _drop('หน่วยบรรจุ', _unit, widget.units, (v) => setState(() => _unit = v)), TextFormField(controller: _cost, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'ราคาต้นทุนมาตรฐาน')), TextFormField(controller: _min, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'สต๊อกขั้นต่ำ')), TextFormField(controller: _purchase, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'จำนวนซื้อเพิ่ม')), SwitchListTile(title: const Text('สถานะใช้งาน'), value: _active, onChanged: (v) => setState(() => _active = v)), const SizedBox(height: 12), Text('หน่วยบรรจุและอัตราแปลง', style: Theme.of(context).textTheme.titleMedium), ..._packs.map((p) => ListTile(title: Text('${p['unitCode']} = ${p['conversionQuantity']} ${p['parentUnitCode'] ?? _unit}'), subtitle: Text('เทียบหน่วยหลัก ${p['baseQuantity']}'), trailing: IconButton(onPressed: () => setState(() => _packs.remove(p)), icon: const Icon(Icons.delete_outline, color: Colors.red))), OutlinedButton.icon(onPressed: () => setState(() => _packs.add({'unitCode': _unit ?? '', 'parentUnitCode': _unit, 'conversionQuantity': 1, 'baseQuantity': 1, 'isDefault': false, 'isActive': true, 'sortOrder': _packs.length + 1})), icon: const Icon(Icons.add), label: const Text('เพิ่มหน่วยบรรจุ')), const SizedBox(height: 12), Text('รูปภาพสินค้า (สูงสุด 5 รูป)', style: Theme.of(context).textTheme.titleMedium), Wrap(spacing: 8, children: [..._images.map((x) => Image.memory(base64Decode(x['imageDataBase64']), width: 72, height: 72, fit: BoxFit.cover)), IconButton(onPressed: _pickImage, icon: const Icon(Icons.add_photo_alternate_outlined))]) ]));
  Widget _drop(String label, String? value, List<Map<String, dynamic>> values, ValueChanged<String?> onChanged) => DropdownButtonFormField<String>(initialValue: value, decoration: InputDecoration(labelText: label), validator: (v) => v == null ? 'กรุณาเลือก$label' : null, items: values.map((x) => DropdownMenuItem(value: '${x['code']}', child: Text('${x['name']}'))).toList(), onChanged: onChanged);
}

*/
class _Alert extends StatelessWidget {
  const _Alert({required this.text, required this.onClose});
  final String text;
  final VoidCallback onClose;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.primary.withValues(alpha: .62),
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, color: scheme.onPrimary),
            const SizedBox(width: 8),
            Text(text, style: TextStyle(color: scheme.onPrimary)),
            IconButton(
              onPressed: onClose,
              icon: Icon(Icons.close, color: scheme.onPrimary),
            ),
          ],
        ),
      ),
    );
  }
}
