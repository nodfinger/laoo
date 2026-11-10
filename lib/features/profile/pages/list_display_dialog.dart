import 'package:flutter/material.dart';

import '../../../app/theme/laoo_design_tokens.dart';
import '../../../app/theme/laoo_typography.dart';
import '../../../app/theme/workspace_theme_presets.dart';
import '../../../core/api/api_client.dart';
import '../../../core/navigation/navigation_menu_repository.dart';
import '../../../core/widgets/list_display_preferences.dart';
import '../../../core/widgets/timed_snack_bar.dart';

/// Only registered screens expose configurable fields. More screens must add
/// matching adapters and server-side registrations before being enabled here.
const _fields = <String, List<ListDisplayField>>{
  '10003': [
    ListDisplayField(key: 'name', label: 'ชื่อกลุ่ม', requiredVisible: true),
    ListDisplayField(key: 'status', label: 'สถานะ'),
  ],
  '10008': aiCapabilityDisplayFields,
  '05002': masterDataDisplayFields,
  '66001': travelClaimDisplayFields,
};

Future<bool> _confirmReset(BuildContext context, String? screenName) async {
  final primary = workspaceThemeController.value.primary;
  return await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(LaooRadius.xs),
          ),
          title: const Text(
            'ยืนยันคืนค่ามาตรฐาน',
            style: LaooTypography.popupTitleStyle,
          ),
          content: Text(
            screenName == null
                ? 'ต้องการคืนค่าการแสดงและลำดับข้อมูลทุกหน้าจอเป็นค่าเริ่มต้นหรือไม่?'
                : 'ต้องการคืนค่าการแสดงและลำดับข้อมูลของหน้าจอ $screenName เป็นค่าเริ่มต้นหรือไม่?',
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('ยืนยัน'),
            ),
          ],
        ),
      ) ??
      false;
}

Future<void> showListDisplayDialog(BuildContext context) async {
  final api = ApiClient();
  late final Set<String> enabledCodes;
  try {
    final response = await api.get('/api/user-list-display/available-menus');
    if (response is! List) throw StateError('Invalid menu response');
    enabledCodes = response.map((item) => item.toString()).toSet();
  } catch (_) {
    if (context.mounted) {
      showTimedSnackBar(
        context,
        message: 'โหลดหน้าจอที่กำหนดคอลัมน์ได้ไม่สำเร็จ กรุณาลองใหม่',
        error: true,
      );
    }
    return;
  } finally {
    api.dispose();
  }
  final projects = await NavigationMenuRepository().getProjects(refresh: true);
  if (!context.mounted) return;
  final menus = [
    for (final project in projects)
      for (final group in project.menuGroups)
        for (final item in group.items)
          if (enabledCodes.contains(item.code))
            (
              project: project.name,
              group: group.name,
              code: item.code,
              name: item.name,
            ),
  ];
  var query = '';
  var page = 0;
  var resetting = false;
  String? resetError;
  bool resetDone = false;
  const pageSize = 10;
  await showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, update) {
        final filtered = menus
            .where(
              (item) => '${item.project} ${item.group} ${item.name}'
                  .toLowerCase()
                  .contains(query.toLowerCase()),
            )
            .toList();
        final start = page * pageSize;
        final visible = filtered.skip(start).take(pageSize).toList();
        final end = start + visible.length;
        final primary = workspaceThemeController.value.primary;
        final border = workspaceThemeController.value.border;
        Widget pageButton({
          required Widget child,
          VoidCallback? onPressed,
          bool selected = false,
        }) => SizedBox(
          width: LaooLayout.paginationButtonSize,
          height: LaooLayout.paginationButtonSize,
          child: FilledButton(
            onPressed: selected ? () {} : onPressed,
            style: FilledButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              backgroundColor: primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey.shade300,
              disabledForegroundColor: Colors.grey.shade700,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(LaooRadius.xs),
              ),
            ),
            child: child,
          ),
        );
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(LaooRadius.xs),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.view_column_outlined, color: primary),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'กำหนดแสดง / จัดเรียงข้อมูล',
                      style: LaooTypography.popupTitleStyle,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Divider(height: 0.6, thickness: 0.6, color: border),
            ],
          ),
          content: SizedBox(
            width: 600,
            height: (MediaQuery.sizeOf(context).height * .55).clamp(180, 480),
            child: Column(
              children: [
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'ค้นหาระบบ กลุ่มเมนู หรือหน้าจอ',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) => update(() {
                    query = value.trim();
                    page = 0;
                  }),
                ),
                const SizedBox(height: 8),
                if (resetError != null)
                  Text(
                    resetError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                if (resetDone)
                  Text('คืนค่ามาตรฐานแล้ว', style: TextStyle(color: primary)),
                Expanded(
                  child: ListView.separated(
                    itemCount: visible.length,
                    separatorBuilder: (_, _) =>
                        Divider(height: 0.6, thickness: 0.6, color: border),
                    itemBuilder: (context, index) {
                      final item = visible[index];
                      return ListTile(
                        title: Text(item.name),
                        subtitle: Text('${item.project} > ${item.group}'),
                        trailing: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            TextButton(
                              onPressed: _fields.containsKey(item.code)
                                  ? () => _edit(context, item.code, item.name)
                                  : null,
                              child: Text(
                                _fields.containsKey(item.code)
                                    ? 'กำหนดค่า'
                                    : 'อยู่ระหว่างรองรับ',
                              ),
                            ),
                            if (_fields.containsKey(item.code))
                              IconButton(
                                tooltip: 'คืนค่ามาตรฐาน ${item.name}',
                                icon: Icon(Icons.restore, color: primary),
                                onPressed: resetting
                                    ? null
                                    : () async {
                                        if (!await _confirmReset(
                                              context,
                                              item.name,
                                            ) ||
                                            !context.mounted) {
                                          return;
                                        }
                                        update(() {
                                          resetting = true;
                                          resetError = null;
                                          resetDone = false;
                                        });
                                        final api = ApiClient();
                                        try {
                                          await api.delete(
                                            '/api/user-list-display/${item.code}',
                                          );
                                          listDisplayPreferencesRevision
                                              .value++;
                                          if (context.mounted) {
                                            showTimedSnackBar(
                                              context,
                                              message:
                                                  'คืนค่ามาตรฐานเรียบร้อยแล้ว',
                                            );
                                            update(() {
                                              resetting = false;
                                              resetDone = true;
                                            });
                                          }
                                        } catch (_) {
                                          if (context.mounted) {
                                            update(() {
                                              resetting = false;
                                              resetError =
                                                  'คืนค่ามาตรฐานไม่สำเร็จ กรุณาลองใหม่';
                                            });
                                          }
                                        } finally {
                                          api.dispose();
                                        }
                                      },
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Divider(height: 0.6, thickness: 0.6, color: border),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    children: [
                      pageButton(
                        onPressed: page > 0 ? () => update(() => page--) : null,
                        child: const Icon(Icons.chevron_left, size: 22),
                      ),
                      pageButton(selected: true, child: Text('${page + 1}')),
                      pageButton(
                        onPressed: end < filtered.length
                            ? () => update(() => page++)
                            : null,
                        child: const Icon(Icons.chevron_right, size: 22),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${filtered.isEmpty ? 0 : start + 1}-$end จาก ${filtered.length}',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Divider(height: 0.6, thickness: 0.6, color: border),
                const SizedBox(height: 12),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: resetting
                          ? null
                          : () async {
                              if (!await _confirmReset(context, null) ||
                                  !context.mounted) {
                                return;
                              }
                              update(() {
                                resetting = true;
                                resetError = null;
                                resetDone = false;
                              });
                              final api = ApiClient();
                              try {
                                await api.delete('/api/user-list-display');
                                listDisplayPreferencesRevision.value++;
                                if (context.mounted) {
                                  showTimedSnackBar(
                                    context,
                                    message:
                                        'คืนค่ามาตรฐานทุกหน้าจอเรียบร้อยแล้ว',
                                  );
                                  update(() {
                                    resetting = false;
                                    resetDone = true;
                                  });
                                }
                              } catch (_) {
                                if (context.mounted) {
                                  update(() {
                                    resetting = false;
                                    resetError =
                                        'คืนค่ามาตรฐานไม่สำเร็จ กรุณาลองใหม่';
                                  });
                                }
                              } finally {
                                api.dispose();
                              }
                            },
                      icon: const Icon(Icons.restore),
                      label: const Text('คืนค่ามาตรฐานทุกหน้าจอ'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: primary,
                        minimumSize: const Size(0, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(LaooRadius.xs),
                        ),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: resetting
                          ? null
                          : () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      label: const Text('ปิด'),
                      style: FilledButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(84, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(LaooRadius.xs),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        );
      },
    ),
  );
}

Future<void> _edit(BuildContext context, String menu, String name) async {
  final api = ApiClient();
  try {
    final data = await api.get('/api/user-list-display/$menu');
    if (!context.mounted) return;
    final current = ListDisplayPreferences.fromJson(
      Map<String, dynamic>.from(data as Map),
    );
    final fields = current.resolve(_fields[menu]!);
    final hidden = {
      for (final field in fields)
        if (!current.isVisible(field)) field.key,
    };
    var right = current.actionOnRight;
    var saving = false;
    String? error;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('กำหนดคอลัมน์ > $name'),
              const SizedBox(height: 16),
              Divider(
                height: 0.6,
                thickness: 0.6,
                color: workspaceThemeController.value.border,
              ),
            ],
          ),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (error != null)
                    Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  SwitchListTile(
                    title: const Text('Action อยู่ด้านขวา'),
                    value: right,
                    onChanged: (value) => update(() => right = value),
                  ),
                  Divider(
                    height: 0.6,
                    thickness: 0.6,
                    color: workspaceThemeController.value.border,
                  ),
                  for (var i = 0; i < fields.length; i++) ...[
                    ListTile(
                      leading: Checkbox(
                        value: !hidden.contains(fields[i].key),
                        onChanged: fields[i].requiredVisible
                            ? null
                            : (checked) => update(() {
                                if (checked == true) {
                                  hidden.remove(fields[i].key);
                                } else {
                                  hidden.add(fields[i].key);
                                }
                              }),
                      ),
                      title: Text(fields[i].label),
                      trailing: Wrap(
                        children: [
                          IconButton(
                            tooltip: 'เลื่อนขึ้น',
                            icon: const Icon(Icons.arrow_upward),
                            onPressed: i == 0
                                ? null
                                : () => update(() {
                                    final field = fields.removeAt(i);
                                    fields.insert(i - 1, field);
                                  }),
                          ),
                          IconButton(
                            tooltip: 'เลื่อนลง',
                            icon: const Icon(Icons.arrow_downward),
                            onPressed: i == fields.length - 1
                                ? null
                                : () => update(() {
                                    final field = fields.removeAt(i);
                                    fields.insert(i + 1, field);
                                  }),
                          ),
                        ],
                      ),
                    ),
                    if (i < fields.length - 1)
                      Divider(
                        height: 0.6,
                        thickness: 0.6,
                        color: workspaceThemeController.value.border,
                      ),
                  ],
                  const SizedBox(height: 16),
                  Divider(
                    height: 0.6,
                    thickness: 0.6,
                    color: workspaceThemeController.value.border,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!await _confirmReset(context, name) ||
                          !context.mounted) {
                        return;
                      }
                      update(() {
                        saving = true;
                        error = null;
                      });
                      try {
                        await api.delete('/api/user-list-display/$menu');
                        listDisplayPreferencesRevision.value++;
                        if (context.mounted) {
                          showTimedSnackBar(
                            context,
                            message: 'คืนค่ามาตรฐานเรียบร้อยแล้ว',
                          );
                          Navigator.pop(context);
                        }
                      } catch (_) {
                        if (context.mounted) {
                          update(() {
                            saving = false;
                            error =
                                'คืนค่าไม่สำเร็จ กรุณาตรวจสอบสิทธิ์และลองใหม่';
                          });
                        }
                      }
                    },
              child: const Text('คืนค่ามาตรฐาน'),
            ),
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(context),
              child: const Text('ยกเลิก'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      update(() {
                        saving = true;
                        error = null;
                      });
                      try {
                        await api.put(
                          '/api/user-list-display/$menu',
                          body: ListDisplayPreferences(
                            order: fields.map((f) => f.key).toList(),
                            hidden: hidden,
                            actionOnRight: right,
                          ).toJson(),
                        );
                        listDisplayPreferencesRevision.value++;
                        if (context.mounted) {
                          showTimedSnackBar(
                            context,
                            message:
                                'บันทึกการแสดงและจัดเรียงข้อมูลเรียบร้อยแล้ว',
                          );
                          Navigator.pop(context);
                        }
                      } catch (_) {
                        if (context.mounted) {
                          update(() {
                            saving = false;
                            error =
                                'บันทึกไม่สำเร็จ กรุณาตรวจสอบสิทธิ์และลองใหม่';
                          });
                        }
                      }
                    },
              child: const Text('บันทึก'),
            ),
          ],
        ),
      ),
    );
  } catch (_) {
    if (context.mounted) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('ไม่สามารถโหลดการตั้งค่า'),
          content: const Text('กรุณาตรวจสอบสิทธิ์และการเชื่อมต่อ แล้วลองใหม่'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ปิด'),
            ),
          ],
        ),
      );
    }
  } finally {
    api.dispose();
  }
}
