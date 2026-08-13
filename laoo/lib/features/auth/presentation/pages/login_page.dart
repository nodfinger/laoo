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

  @override
  void initState() {
    super.initState();
    _restoreRememberedUsername();
  }

  Future<void> _restoreRememberedUsername() async {
    final username = await AuthStorage().readRememberedUsername();
    final password = await AuthStorage().readRememberedPassword();
    if (!mounted) {
      return;
    }
    if (username != null && username.isNotEmpty) {
      _usernameController.text = username;
    }
    if (password != null && password.isNotEmpty) {
      _passwordController.text = password;
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
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

      setState(() => _loginError = _apiErrorMessage(error));
    } on StateError catch (error) {
      if (!mounted) {
        return;
      }

      setState(() => _loginError = error.message);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() => _loginError = 'ไม่สามารถเข้าสู่ระบบได้: $error');
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

  void _forgotPassword() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ระบบลืมรหัสผ่านจะพัฒนาในขั้นตอนถัดไป')),
    );
  }

  void _openRegister() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ระบบสมัครใช้งานจะพัฒนาในขั้นตอนถัดไป')),
    );
  }

  void _backToLanding() {
    appRouter.goNamed(RouteNames.landing);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    if (width < 820) {
      return _buildMobile();
    }

    return _buildDesktop();
  }

  Widget _buildDesktop() {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F7),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1060),
              child: SizedBox(
                height: 545,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFFE4EAE6)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 28,
                        offset: Offset(0, 12),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: Row(
                      children: [
                        const Expanded(flex: 40, child: _LeftPanelImage()),
                        Expanded(
                          flex: 60,
                          child: _buildLoginPanel(compact: false),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobile() {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8F7),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: const SizedBox(
                  width: double.infinity,
                  height: 285,
                  child: _LeftPanelImage(mobile: true),
                ),
              ),
              const SizedBox(height: 12),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE4EAE6)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x18000000),
                      blurRadius: 20,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: _buildLoginPanel(compact: true),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoginPanel({required bool compact}) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 20 : 48,
        vertical: compact ? 23 : 21,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Form(
            key: _formKey,
            child: AutofillGroup(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_loginError != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        border: Border.all(color: Colors.red.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _loginError!,
                              style: TextStyle(color: Colors.red.shade800),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Text(
                    'Welcome Back',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: compact ? 26 : 27,
                      height: 1.05,
                      fontWeight: FontWeight.w900,
                      color: LaooColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 7),
                  const Text(
                    'เข้าสู่ระบบเพื่อใช้งานระบบ',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: LaooColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 19),
                  TextFormField(
                    controller: _usernameController,
                    enabled: !_isSubmitting,
                    style: const TextStyle(fontSize: 13, height: 1.2),
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
                  const SizedBox(height: 11),
                  TextFormField(
                    controller: _passwordController,
                    enabled: !_isSubmitting,
                    style: const TextStyle(fontSize: 13, height: 1.2),
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
                        onPressed: _isSubmitting
                            ? null
                            : () {
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
                  const SizedBox(height: 5),
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
                      const Text(
                        'จำการเข้าสู่ระบบ',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: LaooColors.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: _isSubmitting ? null : _forgotPassword,
                        style: TextButton.styleFrom(
                          minimumSize: Size.zero,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 3,
                          ),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          textStyle: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: const Text('ลืมรหัสผ่าน?'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 11),
                  SizedBox(
                    height: LaooTypography.buttonHeight,
                    child: FilledButton(
                      onPressed: _isSubmitting ? null : _submitLogin,
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 19,
                              height: 19,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('เข้าสู่ระบบ'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Expanded(child: Divider(color: Color(0xFFE1E6E3))),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          'หรือ',
                          style: TextStyle(
                            fontSize: 11,
                            color: LaooColors.textSecondary,
                          ),
                        ),
                      ),
                      const Expanded(child: Divider(color: Color(0xFFE1E6E3))),
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
                        textStyle: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      icon: const Icon(Icons.arrow_back_rounded, size: 15),
                      label: const Text('กลับหน้าหลัก'),
                    ),
                  ),
                  const Text(
                    '© Laoo Solutions',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: LaooColors.textSecondary,
                      fontSize: 10,
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
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF8A958D)),
      prefixIcon: Icon(prefixIcon, size: 18),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFBFC8C2), width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFBFC8C2), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: LaooColors.green, width: 1.5),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFD8DEDA), width: 1),
      ),
    );
  }
}

class _LeftPanelImage extends StatelessWidget {
  const _LeftPanelImage({this.mobile = false});

  final bool mobile;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: LaooColors.greenDark,
      child: SizedBox.expand(
        child: Image.asset(
          'assets/images/laoo_login_left_panel.png',
          fit: BoxFit.cover,
          alignment: mobile ? Alignment.topCenter : Alignment.center,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}
