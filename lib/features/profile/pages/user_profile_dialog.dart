import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/laoo_typography.dart';
import '../../../app/theme/workspace_theme_presets.dart';
import '../../../core/auth/app_auth_controller.dart';
import '../../../core/auth/auth_session.dart';
import '../../../core/navigation/menu_style_preferences.dart';
import '../../../core/widgets/auto_dismiss_message.dart';
import '../data/user_profile_repository.dart';

Future<void> saveUserProfileTheme(String themeCode) =>
    UserProfileRepository().saveTheme(themeCode);

final ValueNotifier<Uint8List?> userProfileAvatarNotifier = ValueNotifier(null);
final ValueNotifier<String?> userProfileIntroductionNotifier = ValueNotifier(
  null,
);

class UserProfileThemeLoader extends StatefulWidget {
  const UserProfileThemeLoader({super.key});
  @override
  State<UserProfileThemeLoader> createState() => _UserProfileThemeLoaderState();
}

class _UserProfileThemeLoaderState extends State<UserProfileThemeLoader> {
  final _repo = UserProfileRepository();
  String? _loadedUser;

  @override
  void initState() {
    super.initState();
    appAuthController.addListener(_loadForCurrentUser);
    _loadForCurrentUser();
  }

  @override
  void dispose() {
    appAuthController.removeListener(_loadForCurrentUser);
    super.dispose();
  }

  Future<void> _loadForCurrentUser() async {
    final session = appAuthController.session;
    final identity = _identity(session);
    if (session == null) {
      _loadedUser = null;
      userProfileAvatarNotifier.value = null;
      userProfileIntroductionNotifier.value = null;
      return;
    }
    if (identity == _loadedUser) {
      return;
    }
    _loadedUser = identity;
    final requestIdentity = identity;
    workspaceThemeController.value = workspaceThemeByCode('STYLE01');
    try {
      final profile = await _repo.get();
      final code = profile['themeCode']?.toString();
      final menuStyle = profile['menuStyleCode']?.toString().toUpperCase();
      final avatar = profile['avatarDataBase64']?.toString();
      final introduction = profile['introduction']?.toString().trim();
      if (_loadedUser == requestIdentity &&
          avatar != null &&
          avatar.isNotEmpty) {
        userProfileAvatarNotifier.value = base64Decode(avatar);
      } else if (_loadedUser == requestIdentity) {
        userProfileAvatarNotifier.value = null;
      }
      if (_loadedUser == requestIdentity) {
        userProfileIntroductionNotifier.value =
            introduction == null || introduction.isEmpty ? null : introduction;
      }
      if (mounted &&
          _loadedUser == requestIdentity &&
          _identity(appAuthController.session) == requestIdentity) {
        workspaceThemeController.value = code != null && code.isNotEmpty
            ? workspaceThemeByCode(code)
            : workspaceThemeByCode('STYLE01');
      }
      if (_loadedUser == requestIdentity) {
        workspaceButtonMenu.value = menuStyle == menuStyleButton;
      }
    } catch (_) {
      // Profile loading must not block the workspace.
    }
  }

  String _identity(AuthSession? session) =>
      '${session?.userType}:${session?.laooUserId}:${session?.userId}:${session?.username}';

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

Future<bool> showUserProfileDialog(BuildContext context) async =>
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _UserProfileDialog(),
    ) ??
    false;

void showUserProfileSavedAlert(BuildContext context) {
  OverlayEntry? entry;
  final preset = workspaceThemeController.value;
  void close() {
    entry?.remove();
    entry = null;
  }

  entry = OverlayEntry(
    builder: (_) => Positioned(
      top: 16,
      right: 24,
      child: Theme(
        data: preset.toThemeData(),
        child: AutoDismissMessage(
          message: 'บันทึกข้อมูลส่วนตัวสำเร็จ',
          onClose: close,
        ),
      ),
    ),
  );
  Overlay.of(context).insert(entry!);
}

class _UserProfileDialog extends StatefulWidget {
  const _UserProfileDialog();
  @override
  State<_UserProfileDialog> createState() => _UserProfileDialogState();
}

class _UserProfileDialogState extends State<_UserProfileDialog> {
  final _repo = UserProfileRepository();
  final _username = TextEditingController(
    text: appAuthController.session?.username ?? '',
  );
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _intro = TextEditingController();
  String? _themeCode;
  String? _avatarBase64;
  String? _avatarType;
  String? _avatarName;
  bool _removeAvatar = false;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  late String _originalThemeCode;
  late String _originalMenuStyleCode;
  String _menuStyleCode = menuStyleSlide;
  String _defaultViewMode = 'LIST';

  @override
  void initState() {
    super.initState();
    _originalThemeCode = workspaceThemeController.value.code;
    _originalMenuStyleCode = workspaceButtonMenu.value
        ? menuStyleButton
        : menuStyleSlide;
    _load();
  }

  @override
  void dispose() {
    _username.dispose();
    _currentPassword.dispose();
    _newPassword.dispose();
    _intro.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final item = await _repo.get();
      if (!mounted) {
        return;
      }
      setState(() {
        _username.text = item['username']?.toString() ?? _username.text;
        _intro.text = item['introduction']?.toString() ?? '';
        _themeCode =
            item['themeCode']?.toString() ??
            workspaceThemeController.value.code;
        _menuStyleCode =
            item['menuStyleCode']?.toString().toUpperCase() == menuStyleButton
            ? menuStyleButton
            : menuStyleSlide;
        _defaultViewMode =
            item['defaultViewMode']?.toString().toUpperCase() == 'CARD'
            ? 'CARD'
            : 'LIST';
        _originalMenuStyleCode = _menuStyleCode;
        _avatarBase64 = item['avatarDataBase64']?.toString();
        _avatarType = item['avatarContentType']?.toString();
        _avatarName = item['avatarFileName']?.toString();
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    final file = result?.files.single;
    if (file?.bytes == null) {
      return;
    }
    if (file!.bytes!.length > 2 * 1024 * 1024) {
      setState(() => _error = 'รูปโปรไฟล์ต้องมีขนาดไม่เกิน 2 MB');
      return;
    }
    setState(() {
      _avatarBase64 = base64Encode(file.bytes!);
      _avatarName = file.name;
      _removeAvatar = false;
      _avatarType = switch (file.extension?.toLowerCase()) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        _ => 'image/jpeg',
      };
    });
  }

  void _deleteImage() => setState(() {
    _avatarBase64 = null;
    _avatarType = null;
    _avatarName = null;
    _removeAvatar = true;
  });

  Future<void> _save() async {
    if (_username.text.trim().isEmpty) {
      setState(() => _error = 'กรุณาระบุ Username');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (_themeCode != null) {
        workspaceThemeController.value = workspaceThemeByCode(_themeCode!);
      }
      final result = await _repo.save({
        'username': _username.text.trim(),
        'currentPassword': _currentPassword.text,
        'newPassword': _newPassword.text.isEmpty ? null : _newPassword.text,
        'themeCode': _themeCode,
        'menuStyleCode': _isPhone ? menuStyleButton : _menuStyleCode,
        'defaultViewMode': _defaultViewMode,
        'introduction': _intro.text.trim(),
        'avatarDataBase64': _avatarBase64,
        'avatarContentType': _avatarType,
        'avatarFileName': _avatarName,
        'removeAvatar': _removeAvatar,
      });
      userProfileAvatarNotifier.value = _avatarBase64 == null
          ? null
          : base64Decode(_avatarBase64!);
      final introduction = _intro.text.trim();
      userProfileIntroductionNotifier.value = introduction.isEmpty
          ? null
          : introduction;
      workspaceButtonMenu.value =
          (_isPhone ? menuStyleButton : _menuStyleCode) == menuStyleButton;
      await appAuthController.updateSessionProfile(
        result['username']?.toString() ?? _username.text.trim(),
      );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _chooseTheme() async {
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: const Text('เลือกโทนสี'),
        content: SizedBox(
          width: 460,
          child: GridView.builder(
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 210,
              mainAxisExtent: 58,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: workspaceThemePresets.length,
            itemBuilder: (_, index) {
              final item = workspaceThemePresets[index];
              return InkWell(
                onTap: () => Navigator.of(context).pop(item.code),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: item.surface,
                    border: Border.all(
                      color: item.code == _themeCode
                          ? item.primary
                          : item.border,
                      width: item.code == _themeCode ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: item.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.name,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: item.textPrimary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('ปิด'),
          ),
        ],
      ),
    );
    if (selected != null && mounted) {
      setState(() => _themeCode = selected);
      workspaceThemeController.value = workspaceThemeByCode(selected);
    }
  }

  void _cancel() {
    workspaceThemeController.value = workspaceThemeByCode(_originalThemeCode);
    workspaceButtonMenu.value = _originalMenuStyleCode == menuStyleButton;
    Navigator.of(context).pop(false);
  }

  bool get _isPhone => MediaQuery.sizeOf(context).width < 600;

  Widget _menuStyleSelector(ThemeData theme) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'รูปแบบเมนู',
        style: TextStyle(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
          fontSize: LaooTypography.validation,
        ),
      ),
      const SizedBox(height: 2),
      Opacity(
        opacity: _isPhone ? 0.55 : 1,
        child: SegmentedButton<String>(
          segments: const [
            ButtonSegment<String>(
              value: menuStyleSlide,
              icon: Icon(Icons.view_sidebar_outlined),
              label: Text('Slide'),
            ),
            ButtonSegment<String>(
              value: menuStyleButton,
              icon: Icon(Icons.dashboard_outlined),
              label: Text('ปุ่มกด'),
            ),
          ],
          selected: {_menuStyleCode},
          onSelectionChanged: _isPhone
              ? null
              : (selected) {
                  final code = selected.first;
                  setState(() => _menuStyleCode = code);
                  workspaceButtonMenu.value = code == menuStyleButton;
                },
        ),
      ),
    ],
  );

  Widget _viewModeSelector(ThemeData theme) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'รูปแบบเริ่มต้นแสดงข้อมูล',
        style: TextStyle(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
          fontSize: LaooTypography.validation,
        ),
      ),
      const SizedBox(height: 4),
      SegmentedButton<String>(
        segments: const [
          ButtonSegment(
            value: 'LIST',
            icon: Icon(Icons.view_list_outlined),
            label: Text('List'),
          ),
          ButtonSegment(
            value: 'CARD',
            icon: Icon(Icons.grid_view_outlined),
            label: Text('Card'),
          ),
        ],
        selected: {_defaultViewMode},
        onSelectionChanged: (value) =>
            setState(() => _defaultViewMode = value.first),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preview = _avatarBase64 == null
        ? null
        : MemoryImage(Uint8List.fromList(base64Decode(_avatarBase64!)));
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      title: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundImage: preview,
            child: preview == null ? const Icon(Icons.person_outline) : null,
          ),
          const SizedBox(width: 12),
          Text(
            'ข้อมูลส่วนตัว',
            style: TextStyle(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        child: _loading
            ? const SizedBox(
                height: 140,
                child: Center(child: CircularProgressIndicator()),
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_error != null) _errorBox(theme),
                    _section(theme, 'ข้อมูลเข้าสู่ระบบ', [
                      TextField(
                        controller: _username,
                        decoration: const InputDecoration(
                          labelText: 'Username',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _currentPassword,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: 'Password เดิม',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _newPassword,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: 'Password ใหม่ (ถ้าต้องการเปลี่ยน)',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ]),
                    const SizedBox(height: 12),
                    _section(theme, 'การแสดงผลส่วนตัว', [
                      _viewModeSelector(theme),
                      const SizedBox(height: 14),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 34,
                            backgroundImage: preview,
                            child: preview == null
                                ? Icon(
                                    Icons.person_outline,
                                    color: theme.colorScheme.primary,
                                    size: 30,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'รูปโปรไฟล์',
                                  style: TextStyle(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 8,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: _pickImage,
                                      icon: const Icon(
                                        Icons.photo_camera_outlined,
                                        size: 18,
                                      ),
                                      label: const Text('เลือกรูป'),
                                    ),
                                    if (preview != null)
                                      OutlinedButton.icon(
                                        onPressed: _deleteImage,
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          size: 18,
                                          color: Colors.red,
                                        ),
                                        label: const Text(
                                          'ลบรูป',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final compact = constraints.maxWidth < 420;
                          final intro = Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: SizedBox(
                              height: 56,
                              child: TextField(
                                controller: _intro,
                                maxLines: 1,
                                maxLength: 300,
                                decoration: const InputDecoration(
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  labelText: 'ข้อความแนะนำ',
                                ),
                              ),
                            ),
                          );
                          final palette = IconButton(
                            tooltip: 'เลือกโทนสี',
                            onPressed: _chooseTheme,
                            icon: Icon(
                              Icons.palette_outlined,
                              color: theme.colorScheme.primary,
                            ),
                          );
                          final menuStyle = SizedBox(
                            width: 200,
                            child: _menuStyleSelector(theme),
                          );
                          return compact
                              ? Row(
                                  children: [
                                    palette,
                                    const SizedBox(width: 8),
                                    Expanded(child: intro),
                                    const SizedBox(width: 8),
                                    menuStyle,
                                  ],
                                )
                              : Row(
                                  children: [
                                    palette,
                                    const SizedBox(width: 8),
                                    Expanded(child: intro),
                                    const SizedBox(width: 8),
                                    menuStyle,
                                  ],
                                );
                        },
                      ),
                    ]),
                  ],
                ),
              ),
      ),
      actions: [
        OutlinedButton.icon(
          onPressed: _saving ? null : _cancel,
          icon: const Icon(Icons.close),
          label: const Text('ยกเลิก'),
        ),
        FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: const Icon(Icons.save_outlined),
          label: Text(_saving ? 'กำลังบันทึก...' : 'บันทึก'),
        ),
      ],
    );
  }

  Widget _errorBox(ThemeData theme) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Colors.red.shade50,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      _error!,
      style: TextStyle(
        color: theme.colorScheme.error,
        fontSize: LaooTypography.validation,
      ),
    ),
  );

  Widget _section(ThemeData theme, String title, List<Widget> children) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: .28),
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      );
}
