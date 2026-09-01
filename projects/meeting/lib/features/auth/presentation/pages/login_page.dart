import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/router/app_router.dart';
import '../../../../app/router/route_names.dart';
import '../../../../app/theme/laoo_design_tokens.dart';
import '../../../../app/theme/laoo_typography.dart';
import '../../../../core/api/api_exception.dart';
import '../../../../core/auth/app_auth_controller.dart';
import '../../../../core/auth/auth_storage.dart';
import '../../../../core/company_setup/company_setup_controller.dart';
import '../../../../core/platform/window_title_service.dart';
import '../../../../core/widgets/auto_dismiss_message.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isSubmitting = false;
  bool _rememberLogin = true;
  String? _loginError;
  bool _loginAlertError = true;

  @override
  void initState() {
    super.initState();
    _restoreRememberedUsername();
  }

  Future<void> _restoreRememberedUsername() async {
    final username = await AuthStorage().readRememberedUsername();
    if (!mounted) {
      return;
    }
    if (username != null && username.isNotEmpty) {
      _usernameController.text = username;
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showLoginAlert(String message, {bool error = true}) {
    if (!mounted) return;
    setState(() {
      _loginError = message;
      _loginAlertError = error;
    });
  }

  void _dismissLoginAlert() {
    if (mounted) setState(() => _loginError = null);
  }

  Future<void> _submitLogin() async {
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _loginError = null;
    });

    try {
      final session = await appAuthController.login(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        rememberLogin: _rememberLogin,
      );

      // Company Setup is the runtime configuration source after login.
      await companySetupController.load();

      // On Windows, MaterialApp.title does not update the native title bar
      // caption by itself. Update the native window caption after Company
      // Setup is loaded.
      WindowTitleService.setTitle(companySetupController.appTitle);

      TextInput.finishAutofillContext(shouldSave: _rememberLogin);

      if (!mounted) {
        return;
      }

      if (session.userType == 'LAOO_SUPPORT') {
        appRouter.goNamed(RouteNames.supportHome);
        return;
      }

      appRouter.goNamed(RouteNames.authenticatedHome);
      return;
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      _showLoginAlert(_apiErrorMessage(error));
    } on StateError catch (error) {
      if (!mounted) {
        return;
      }

      _showLoginAlert(error.message);
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showLoginAlert('ไม่สามารถเข้าสู่ระบบได้: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  String _apiErrorMessage(ApiException error) {
    switch (error.statusCode) {
      case 400:
        return error.message;
      case 401:
        return 'ไม่พบ Username หรือ Password ไม่ถูกต้อง';
      case 403:
        return 'ผู้ใช้งานไม่มีสิทธิ์เข้าสู่ Project นี้';
      case 404:
        return 'ไม่พบข้อมูลผู้ใช้งานหรือ Project';
      default:
        return error.message;
    }
  }

  Future<void> _openForgotPassword() async {
    final controller = TextEditingController();
    final username = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        titleTextStyle: LaooTypography.popupTitleStyle,
        titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
        contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
        actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        title: const Text('ลืมรหัสผ่าน'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Divider(height: 1),
            const SizedBox(height: 16),
            const Text('กรุณาระบุ Username เพื่อขอเปลี่ยนรหัสผ่าน'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Username'),
            ),
            const SizedBox(height: 8),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('ส่งคำขอ'),
          ),
        ],
      ),
    );
    // Let the dialog route finish its closing animation before disposing the
    // controller used by its TextField.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    controller.dispose();
    if (!mounted || username == null || username.trim().isEmpty) return;
    try {
      _showLoginAlert(
        'กำลังตรวจสอบข้อมูลและส่งคำแนะนำไปยัง Email...',
        error: false,
      );
      await appAuthController.requestPasswordReset(username: username);
      if (mounted) {
        _showLoginAlert(
          'ระบบส่งคำแนะนำการตั้งรหัสผ่านใหม่ไปยัง Email แล้ว',
          error: false,
        );
        appRouter.goNamed(RouteNames.resetPassword);
      }
    } on ApiException catch (error) {
      if (mounted) _showLoginAlert(error.message);
    } catch (_) {
      if (mounted) {
        _showLoginAlert(
          'ไม่สามารถส่งคำขอได้ กรุณาตรวจสอบการตั้งค่า Email ของระบบ',
        );
      }
    }
  }

  void _openRegister() {
    _showLoginAlert('ระบบสมัครใช้งานจะพัฒนาในขั้นตอนถัดไป', error: false);
  }

  void _backToLanding() {
    appRouter.goNamed(RouteNames.landing);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    if (width < 920) {
      return _buildMobile();
    }

    return _buildDesktop();
  }

  Widget _buildDesktop() {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: LaooColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final availableHeight = constraints.maxHeight - 32;
            final panelHeight = availableHeight > 596 ? 596.0 : availableHeight;
            final condensed = constraints.maxHeight < 560;
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 980),
                  child: SizedBox(
                    height: panelHeight,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(LaooRadius.lg),
                        border: Border.all(color: LaooColors.border),
                        boxShadow: LaooShadows.soft,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(LaooRadius.lg),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 48,
                              child: _RoomSignalPanel(condensed: condensed),
                            ),
                            Expanded(
                              flex: 52,
                              child: _buildLoginPanel(
                                compact: false,
                                condensed: condensed,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMobile() {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: LaooColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
            final condensed = constraints.maxHeight < 690 || keyboardVisible;
            return Padding(
              padding: const EdgeInsets.all(10),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: LaooColors.white,
                  borderRadius: BorderRadius.circular(LaooRadius.lg),
                  border: Border.all(color: LaooColors.border),
                  boxShadow: LaooShadows.soft,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(LaooRadius.lg),
                  child: Column(
                    children: [
                      SizedBox(
                        height: condensed ? 58 : 116,
                        width: double.infinity,
                        child: _CompactRoomSignalHeader(condensed: condensed),
                      ),
                      Expanded(
                        child: _buildLoginPanel(
                          compact: true,
                          condensed: condensed,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLoginPanel({required bool compact, required bool condensed}) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 18 : 44,
        vertical: condensed ? 10 : (compact ? 16 : 20),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final formWidth = constraints.maxWidth > 400
              ? 400.0
              : constraints.maxWidth;
          return Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox(
                width: formWidth,
                child: Form(
                  key: _formKey,
                  child: AutofillGroup(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_loginError != null) ...[
                          AutoDismissMessage(
                            key: ValueKey((_loginError, _loginAlertError)),
                            message: _loginError!,
                            error: _loginAlertError,
                            onClose: _dismissLoginAlert,
                          ),
                          const SizedBox(height: 12),
                        ],
                        Text(
                          'เข้าสู่ระบบ',
                          style: const TextStyle(
                            fontSize: LaooTypography.pageTitle,
                            height: LaooTypography.titleLineHeight,
                            fontWeight: LaooTypography.strongWeight,
                            color: LaooColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: condensed ? 0 : 3),
                        const Text(
                          'เข้าสู่ระบบ Laoo-Meeting & Display',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: LaooTypography.body,
                            color: LaooColors.textSecondary,
                          ),
                        ),
                        SizedBox(height: condensed ? 8 : 14),
                        TextFormField(
                          controller: _usernameController,
                          enabled: !_isSubmitting,
                          style: const TextStyle(
                            fontSize: LaooTypography.inputText,
                            height: 1.2,
                          ),
                          autofillHints: const [AutofillHints.username],
                          textInputAction: TextInputAction.next,
                          decoration: _fieldDecoration(
                            hintText: 'Username',
                            prefixIcon: Icons.person_outline,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'กรุณากรอก Username';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: condensed ? 7 : 10),
                        TextFormField(
                          controller: _passwordController,
                          // Keep the password editable even if a previous login
                          // request is still waiting on the API.
                          enabled: true,
                          style: const TextStyle(
                            fontSize: LaooTypography.inputText,
                            height: 1.2,
                          ),
                          obscureText: _obscurePassword,
                          autofillHints: const [AutofillHints.password],
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) {
                            if (!_isSubmitting) {
                              _submitLogin();
                            }
                          },
                          decoration: _fieldDecoration(
                            hintText: 'Password',
                            prefixIcon: Icons.lock_outline,
                            suffixIcon: IconButton(
                              tooltip: _obscurePassword
                                  ? 'แสดงรหัสผ่าน'
                                  : 'ซ่อนรหัสผ่าน',
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                size: 18,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'กรุณากรอก Password';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            SizedBox(
                              width: 28,
                              height: 28,
                              child: Checkbox(
                                value: _rememberLogin,
                                onChanged: _isSubmitting
                                    ? null
                                    : (value) {
                                        setState(() {
                                          _rememberLogin = value ?? false;
                                        });
                                      },
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                            const SizedBox(width: 2),
                            const Expanded(
                              child: Text(
                                'จำการเข้าสู่ระบบ',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: LaooTypography.body,
                                  fontWeight: FontWeight.w600,
                                  color: LaooColors.textPrimary,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: _isSubmitting
                                  ? null
                                  : _openForgotPassword,
                              style: TextButton.styleFrom(
                                minimumSize: Size.zero,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 3,
                                ),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                textStyle: const TextStyle(
                                  fontSize: LaooTypography.button,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              child: const Text('ลืมรหัสผ่าน?'),
                            ),
                          ],
                        ),
                        SizedBox(height: condensed ? 6 : 9),
                        SizedBox(
                          height: LaooTypography.buttonHeight,
                          child: FilledButton(
                            onPressed: _isSubmitting ? null : _submitLogin,
                            child: _isSubmitting
                                ? const SizedBox(
                                    width: 19,
                                    height: 19,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('เข้าสู่ระบบ'),
                          ),
                        ),
                        SizedBox(height: condensed ? 7 : 10),
                        Row(
                          children: [
                            const Expanded(
                              child: Divider(color: Color(0xFFE1E6E3)),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              child: Text(
                                'หรือ',
                                style: TextStyle(
                                  fontSize: LaooTypography.body,
                                  color: LaooColors.textSecondary,
                                ),
                              ),
                            ),
                            const Expanded(
                              child: Divider(color: Color(0xFFE1E6E3)),
                            ),
                          ],
                        ),
                        SizedBox(height: condensed ? 7 : 9),
                        SizedBox(
                          height: LaooTypography.buttonHeight,
                          child: OutlinedButton(
                            onPressed: _isSubmitting ? null : _openRegister,
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: LaooColors.green),
                              foregroundColor: LaooColors.greenDark,
                            ),
                            child: const Text('สมัครใช้งาน'),
                          ),
                        ),
                        SizedBox(height: condensed ? 0 : 2),
                        Center(
                          child: TextButton.icon(
                            onPressed: _isSubmitting ? null : _backToLanding,
                            style: TextButton.styleFrom(
                              foregroundColor: LaooColors.greenDark,
                              textStyle: const TextStyle(
                                fontSize: LaooTypography.button,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            icon: const Icon(
                              Icons.arrow_back_rounded,
                              size: 15,
                            ),
                            label: const Text('กลับหน้าหลัก'),
                          ),
                        ),
                        const Text(
                          '© Laoo Meeting Room & Display',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: LaooColors.textSecondary,
                            fontSize: LaooTypography.caption,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required String hintText,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(
        fontSize: LaooTypography.inputHint,
        color: Color(0xFF748078),
      ),
      prefixIcon: Icon(prefixIcon, size: 19),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: LaooColors.surfaceSoft,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(LaooRadius.xs),
        borderSide: const BorderSide(color: LaooColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(LaooRadius.xs),
        borderSide: const BorderSide(color: Color(0xFFB8C4BC)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(LaooRadius.xs),
        borderSide: const BorderSide(color: LaooColors.green, width: 1.5),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(LaooRadius.xs),
        borderSide: const BorderSide(color: Color(0xFFD8DEDA), width: 1),
      ),
    );
  }
}

class _RoomSignalPanel extends StatelessWidget {
  const _RoomSignalPanel({required this.condensed});

  final bool condensed;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: LaooColors.greenDark,
      child: Padding(
        padding: EdgeInsets.all(condensed ? 20 : 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _MeetingBrandMark(),
            const Spacer(),
            const Text(
              'จัดการห้องประชุม\nให้ทุกนัดพร้อมเสมอ',
              style: TextStyle(
                color: LaooColors.white,
                fontSize: 26,
                height: 1.35,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (!condensed) ...[
              const SizedBox(height: 8),
              const Text(
                'จองห้อง ติดตามสถานะ และแสดงตารางใช้งาน\nได้จากทุกอุปกรณ์ในระบบเดียว',
                style: TextStyle(
                  color: Color(0xFFC7DDD5),
                  fontSize: LaooTypography.body,
                  height: 1.55,
                ),
              ),
            ],
            SizedBox(height: condensed ? 14 : 24),
            const _RoomStatusBoard(),
          ],
        ),
      ),
    );
  }
}

class _CompactRoomSignalHeader extends StatelessWidget {
  const _CompactRoomSignalHeader({required this.condensed});

  final bool condensed;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: LaooColors.greenDark,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: condensed ? 9 : 14,
        ),
        child: condensed
            ? const Row(
                children: [
                  _MeetingBrandMark(compact: true),
                  Spacer(),
                  _SignalDot(color: Color(0xFF4ADE80)),
                ],
              )
            : const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _MeetingBrandMark(compact: true),
                  Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: _CompactStatusItem(
                          color: Color(0xFF4ADE80),
                          label: 'ว่าง',
                        ),
                      ),
                      SizedBox(width: 6),
                      Expanded(
                        child: _CompactStatusItem(
                          color: Color(0xFFFBBF24),
                          label: 'ใช้งาน',
                        ),
                      ),
                      SizedBox(width: 6),
                      Expanded(
                        child: _CompactStatusItem(
                          color: Color(0xFF60A5FA),
                          label: 'นัดถัดไป',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}

class _MeetingBrandMark extends StatelessWidget {
  const _MeetingBrandMark({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: compact ? 34 : 40,
          height: compact ? 34 : 40,
          decoration: BoxDecoration(
            color: const Color(0xFF1D6B55),
            borderRadius: BorderRadius.circular(LaooRadius.sm),
            border: Border.all(color: const Color(0xFF4B8C78)),
          ),
          child: Icon(
            Icons.meeting_room_outlined,
            color: LaooColors.white,
            size: compact ? 20 : 23,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          compact ? 'LAOO MEETING' : 'LAOO MEETING ROOM',
          style: TextStyle(
            color: LaooColors.white,
            fontSize: compact ? 14 : 15,
            letterSpacing: 0.8,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _RoomStatusBoard extends StatelessWidget {
  const _RoomStatusBoard();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF123F34),
        borderRadius: BorderRadius.circular(LaooRadius.md),
        border: Border.all(color: const Color(0xFF2A6554)),
      ),
      child: const Padding(
        padding: EdgeInsets.all(14),
        child: Column(
          children: [
            _RoomStatusRow(
              room: 'ROOM 01',
              detail: 'พร้อมใช้งาน',
              status: 'ว่าง',
              color: Color(0xFF4ADE80),
            ),
            Divider(height: 17, color: Color(0xFF2A6554)),
            _RoomStatusRow(
              room: 'ROOM 02',
              detail: 'สิ้นสุด 10:30',
              status: 'ใช้งาน',
              color: Color(0xFFFBBF24),
            ),
            Divider(height: 17, color: Color(0xFF2A6554)),
            _RoomStatusRow(
              room: 'ROOM 03',
              detail: 'นัดถัดไป 11:00',
              status: 'ถัดไป',
              color: Color(0xFF60A5FA),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoomStatusRow extends StatelessWidget {
  const _RoomStatusRow({
    required this.room,
    required this.detail,
    required this.status,
    required this.color,
  });

  final String room;
  final String detail;
  final String status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _SignalDot(color: color),
        const SizedBox(width: 9),
        SizedBox(
          width: 70,
          child: Text(
            room,
            style: const TextStyle(
              color: LaooColors.white,
              fontSize: LaooTypography.caption,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Expanded(
          child: Text(
            detail,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFC7DDD5),
              fontSize: LaooTypography.caption,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          status,
          style: TextStyle(
            color: color,
            fontSize: LaooTypography.caption,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _CompactStatusItem extends StatelessWidget {
  const _CompactStatusItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF123F34),
        borderRadius: BorderRadius.circular(LaooRadius.xs),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _SignalDot(color: color, size: 7),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: LaooColors.white,
                  fontSize: LaooTypography.caption,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SignalDot extends StatelessWidget {
  const _SignalDot({required this.color, this.size = 9});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 6),
        ],
      ),
    );
  }
}
