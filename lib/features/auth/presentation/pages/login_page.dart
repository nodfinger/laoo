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
        backgroundColor: LaooColors.white,
        titleTextStyle: const TextStyle(
          color: LaooColors.greenDark,
          fontSize: LaooTypography.sectionTitle,
          fontWeight: LaooTypography.emphasizedWeight,
        ),
        titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
        contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
        actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        title: const Text('ลืมรหัสผ่าน'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Divider(height: 1, color: LaooColors.border),
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
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
            label: const Text('ยกเลิก'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, controller.text),
            icon: const Icon(Icons.send_outlined),
            label: const Text('ส่งคำขอ'),
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
    return Scaffold(
      backgroundColor: LaooColors.white,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [LaooColors.white, LaooColors.greenLight],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 600;
              final horizontalPadding = isMobile ? 16.0 : 24.0;
              final verticalPadding = isMobile ? 16.0 : 24.0;

              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: verticalPadding,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - (verticalPadding * 2),
                  ),
                  child: Align(
                    alignment: isMobile
                        ? Alignment.topCenter
                        : Alignment.center,
                    child: Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxWidth: 430),
                      decoration: BoxDecoration(
                        color: LaooColors.white,
                        borderRadius: BorderRadius.circular(LaooRadius.md),
                        boxShadow: LaooShadows.soft,
                      ),
                      child: _buildLoginPanel(compact: isMobile),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLoginPanel({required bool compact}) {
    return Container(
      color: LaooColors.white,
      padding: EdgeInsets.fromLTRB(
        compact ? 18 : 28,
        compact ? 16 : 20,
        compact ? 18 : 28,
        compact ? 12 : 18,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Form(
            key: _formKey,
            child: AutofillGroup(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _LoginBrandMark(),
                  SizedBox(height: compact ? 12 : 14),
                  if (_loginError != null) ...[
                    AutoDismissMessage(
                      key: ValueKey((_loginError, _loginAlertError)),
                      message: _loginError!,
                      error: _loginAlertError,
                      onClose: _dismissLoginAlert,
                    ),
                    const SizedBox(height: 16),
                  ],
                  const Text(
                    'เข้าสู่ระบบ',
                    style: TextStyle(
                      fontSize: LaooTypography.pageTitle,
                      height: LaooTypography.titleLineHeight,
                      fontWeight: LaooTypography.pageTitleWeight,
                      color: LaooColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'ยินดีต้อนรับกลับสู่ Laoo Platform',
                    style: TextStyle(
                      fontSize: LaooTypography.body,
                      height: LaooTypography.bodyLineHeight,
                      color: LaooColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const _LoginFieldLabel(label: 'ชื่อผู้ใช้งาน'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _usernameController,
                    enabled: !_isSubmitting,
                    style: const TextStyle(
                      fontSize: LaooTypography.inputText,
                      height: LaooTypography.inputLineHeight,
                    ),
                    autofillHints: const [AutofillHints.username],
                    textInputAction: TextInputAction.next,
                    decoration: _fieldDecoration(
                      hintText: 'กรอก Username',
                      prefixIcon: Icons.person_outline_rounded,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'กรุณากรอก Username';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  const _LoginFieldLabel(label: 'รหัสผ่าน'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _passwordController,
                    // Keep the password editable even if a previous login
                    // request is still waiting on the API.
                    enabled: true,
                    style: const TextStyle(
                      fontSize: LaooTypography.inputText,
                      height: LaooTypography.inputLineHeight,
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
                      hintText: 'กรอก Password',
                      prefixIcon: Icons.lock_outline_rounded,
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
                          size: 19,
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
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      SizedBox(
                        width: 32,
                        height: 32,
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
                      const SizedBox(width: 4),
                      const Expanded(
                        child: Text(
                          'จำการเข้าสู่ระบบ',
                          style: TextStyle(
                            fontSize: LaooTypography.bodySmall,
                            fontWeight: LaooTypography.emphasizedWeight,
                            color: LaooColors.textPrimary,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _isSubmitting ? null : _openForgotPassword,
                        style: TextButton.styleFrom(
                          minimumSize: const Size(44, 40),
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          textStyle: const TextStyle(
                            fontFamily: LaooTypography.fontFamily,
                            fontSize: LaooTypography.bodySmall,
                            fontWeight: LaooTypography.emphasizedWeight,
                          ),
                        ),
                        child: const Text('ลืมรหัสผ่าน?'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: LaooTypography.buttonHeight,
                    child: FilledButton.icon(
                      onPressed: _isSubmitting ? null : _submitLogin,
                      icon: _isSubmitting
                          ? const SizedBox(
                              width: 19,
                              height: 19,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: LaooColors.white,
                              ),
                            )
                          : const Icon(Icons.login_rounded, size: 19),
                      label: Text(
                        _isSubmitting ? 'กำลังเข้าสู่ระบบ...' : 'เข้าสู่ระบบ',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Row(
                    children: [
                      Expanded(child: Divider(color: LaooColors.border)),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'ยังไม่มีบัญชี?',
                          style: TextStyle(
                            fontSize: LaooTypography.caption,
                            color: LaooColors.textSecondary,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: LaooColors.border)),
                    ],
                  ),
                  const SizedBox(height: 10),
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
                  const SizedBox(height: 4),
                  Center(
                    child: TextButton.icon(
                      onPressed: _isSubmitting ? null : _backToLanding,
                      style: TextButton.styleFrom(
                        foregroundColor: LaooColors.greenDark,
                        minimumSize: const Size(44, 40),
                        textStyle: const TextStyle(
                          fontFamily: LaooTypography.fontFamily,
                          fontSize: LaooTypography.bodySmall,
                          fontWeight: LaooTypography.emphasizedWeight,
                        ),
                      ),
                      icon: const Icon(Icons.arrow_back_rounded, size: 17),
                      label: const Text('กลับหน้าหลัก'),
                    ),
                  ),
                  const Text(
                    '© Laoo 2026',
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
  }

  InputDecoration _fieldDecoration({
    required String hintText,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(LaooRadius.sm),
      borderSide: const BorderSide(color: LaooColors.border),
    );
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(
        fontSize: LaooTypography.inputHint,
        color: LaooColors.textSecondary,
      ),
      prefixIcon: Icon(prefixIcon, size: 20, color: LaooColors.greenDark),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: LaooColors.surfaceSoft,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      border: border,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(LaooRadius.sm),
        borderSide: const BorderSide(color: LaooColors.green, width: 1.5),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(LaooRadius.sm),
        borderSide: const BorderSide(color: LaooColors.border),
      ),
      errorStyle: const TextStyle(fontSize: LaooTypography.validation),
    );
  }
}

class _LoginFieldLabel extends StatelessWidget {
  const _LoginFieldLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: LaooTypography.body,
        fontWeight: LaooTypography.emphasizedWeight,
        color: LaooColors.textPrimary,
      ),
    );
  }
}

class _LoginBrandMark extends StatelessWidget {
  const _LoginBrandMark();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Image.asset(
          'assets/images/laoo_app_icon.png',
          width: 36,
          height: 36,
          filterQuality: FilterQuality.high,
          semanticLabel: 'Laoo Solutions',
        ),
        const SizedBox(height: 5),
        const Text(
          'LAOO PLATFORM',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: LaooTypography.sectionTitle,
            fontWeight: LaooTypography.strongWeight,
            color: LaooColors.greenDark,
          ),
        ),
        const SizedBox(height: 1),
        const Text(
          'Simple today. Ready Tomorrow.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: LaooTypography.bodySmall,
            height: LaooTypography.bodyLineHeight,
            fontWeight: LaooTypography.emphasizedWeight,
            color: LaooColors.green,
          ),
        ),
      ],
    );
  }
}
