import 'package:flutter/material.dart';

import '../../../../app/theme/workspace_theme_presets.dart';
import '../../../../core/widgets/timed_snack_bar.dart';
import '../../presentation/widgets/support_workspace_shell.dart';
import '../data/laoo_menu_management_api.dart';

class LaooMenuManagementPage extends StatefulWidget {
  const LaooMenuManagementPage({super.key});
  @override
  State<LaooMenuManagementPage> createState() => _LaooMenuManagementPageState();
}

class _LaooMenuManagementPageState extends State<LaooMenuManagementPage> {
  final _api = LaooMenuManagementApi();
  String _caption = '';
  String? _projectCode;
  List<_MenuGroupEditor> _groups = [];
  List<Map<String, dynamic>> _systems = [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final group in _groups) {
      group.dispose();
    }
    _api.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final result = await Future.wait([
        _api.caption(),
        _api.load(projectCode: _projectCode),
      ]);
      final data = Map<String, dynamic>.from(result[1] as Map);
      for (final group in _groups) {
        group.dispose();
      }
      _groups = (data['groups'] as List<dynamic>? ?? const [])
          .map(
            (row) => _MenuGroupEditor.fromJson(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList();
      _systems = (data['systems'] as List<dynamic>? ?? const [])
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
      _caption = '${result[0]}';
    } catch (error) {
      if (mounted)
        showTimedSnackBar(context, message: error.toString(), error: true);
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _api.save(
        groups: _groups.map((group) => group.toRequest()).toList(),
        menus: _groups
            .expand((group) => group.menus)
            .map((menu) => menu.toRequest())
            .toList(),
      );
      if (mounted) showTimedSnackBar(context, message: 'Saved successfully.');
      await _load();
    } catch (error) {
      if (mounted)
        showTimedSnackBar(context, message: error.toString(), error: true);
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final accent = workspaceThemeController.value.primary;
    return SupportWorkspaceShell(
      pageTitle: _caption,
      activeMenu: 'laooMenuManagement',
      menuScope: WorkspaceMenuScope.support,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _caption,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: const Icon(Icons.save_outlined),
                      label: Text(_saving ? 'Saving...' : 'Save changes'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Wrap(
                      spacing: 16,
                      runSpacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SizedBox(
                          width: 320,
                          child: DropdownButtonFormField<String?>(
                            value: _projectCode,
                            decoration: const InputDecoration(
                              labelText: 'System',
                            ),
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text('All systems'),
                              ),
                              ..._systems.map(
                                (system) => DropdownMenuItem(
                                  value: '${system['projectCode']}',
                                  child: Text(
                                    '${system['projectName']} (${system['projectCode']})',
                                  ),
                                ),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() => _projectCode = value);
                              _load();
                            },
                          ),
                        ),
                        Text(
                          'Edit names and sort order, then save all changes together.',
                          style: TextStyle(color: accent),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_groups.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No menus were found for this system.'),
                    ),
                  ),
                ..._groups.map((group) => _groupCard(context, group)),
              ],
            ),
    );
  }

  Widget _groupCard(BuildContext context, _MenuGroupEditor group) => Card(
    margin: const EdgeInsets.only(bottom: 16),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Menu group ${group.code}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: group.name,
                  decoration: const InputDecoration(labelText: 'Group name'),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 130,
                child: TextField(
                  controller: group.sortOrder,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Sort order'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          ...group.menus.map(
            (menu) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 58,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(menu.code),
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: menu.name,
                      decoration: const InputDecoration(labelText: 'Menu name'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 110,
                    child: TextField(
                      controller: menu.sortOrder,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Sort order',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 190,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(
                        menu.projectCodes,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _MenuGroupEditor {
  _MenuGroupEditor(this.code, String name, int sortOrder, this.menus)
    : name = TextEditingController(text: name),
      sortOrder = TextEditingController(text: '$sortOrder');
  factory _MenuGroupEditor.fromJson(Map<String, dynamic> json) =>
      _MenuGroupEditor(
        '${json['menuGroupCode']}',
        '${json['menuGroupName']}',
        (json['sortOrder'] as num?)?.toInt() ?? 0,
        (json['menus'] as List<dynamic>? ?? const [])
            .map(
              (row) => _MainMenuEditor.fromJson(
                Map<String, dynamic>.from(row as Map),
              ),
            )
            .toList(),
      );
  final String code;
  final TextEditingController name;
  final TextEditingController sortOrder;
  final List<_MainMenuEditor> menus;
  Map<String, dynamic> toRequest() => {
    'menuGroupCode': code,
    'menuGroupName': name.text.trim(),
    'sortOrder': int.tryParse(sortOrder.text) ?? -1,
  };
  void dispose() {
    name.dispose();
    sortOrder.dispose();
    for (final menu in menus) {
      menu.dispose();
    }
  }
}

class _MainMenuEditor {
  _MainMenuEditor(this.code, String name, int sortOrder, this.projectCodes)
    : name = TextEditingController(text: name),
      sortOrder = TextEditingController(text: '$sortOrder');
  factory _MainMenuEditor.fromJson(Map<String, dynamic> json) =>
      _MainMenuEditor(
        '${json['menuCode']}',
        '${json['menuName']}',
        (json['sortOrder'] as num?)?.toInt() ?? 0,
        '${json['projectCodes'] ?? ''}',
      );
  final String code;
  final String projectCodes;
  final TextEditingController name;
  final TextEditingController sortOrder;
  Map<String, dynamic> toRequest() => {
    'menuCode': code,
    'menuName': name.text.trim(),
    'sortOrder': int.tryParse(sortOrder.text) ?? -1,
  };
  void dispose() {
    name.dispose();
    sortOrder.dispose();
  }
}
