import 'package:flutter/material.dart';

import '../../../../app/router/app_router.dart';
import '../../../../app/router/route_names.dart';
import '../../../../app/theme/laoo_design_tokens.dart';
import '../../../../core/api/api_exception.dart';
import '../../../../core/auth/app_auth_controller.dart';

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
    });

    try {
      final session = await appAuthController.login(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        projectCode: 'LAOO',
      );

      if (!mounted) {
        return;
      }

      if (session.userType == 'LAOO_SUPPORT') {
        appRouter.goNamed(RouteNames.supportHome);
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'เข้าสู่ระบบสำเร็จ แต่ Workspace สำหรับ '
            '${session.userType ?? 'ผู้ใช้งาน'} อยู่ระหว่างพัฒนา',
          ),
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_apiErrorMessage(error))));
    } on StateError catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ไม่สามารถเข้าสู่ระบบได้: $error')),
      );
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
        return 'Username หรือ Password ไม่ถูกต้อง';
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

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 780;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: isCompact
            ? SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 250, child: _BrandPanel()),
                    _buildLoginPanel(),
                  ],
                ),
              )
            : Row(
                children: [
                  const Expanded(flex: 4, child: _BrandPanel()),
                  Expanded(flex: 6, child: _buildLoginPanel()),
                ],
              ),
      ),
    );
  }

  Widget _buildLoginPanel() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Form(
            key: _formKey,
            child: AutofillGroup(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 170,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Image.asset(
                        'assets/images/laoo_logo_new.png',
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                        errorBuilder: (context, error, stackTrace) {
                          return const Center(
                            child: Text(
                              'LAOO SOLUTIONS',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: LaooColors.greenDark,
                                fontSize: 34,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'เข้าสู่ระบบ',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      color: LaooColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'กรุณาเข้าสู่ระบบเพื่อดำเนินการต่อ',
                    style: TextStyle(color: LaooColors.textSecondary),
                  ),
                  const SizedBox(height: 30),
                  const Text(
                    'ชื่อผู้ใช้ (Username)',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _usernameController,
                    enabled: !_isSubmitting,
                    autofillHints: const [AutofillHints.username],
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      hintText: 'กรอกชื่อผู้ใช้',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'กรุณากรอก Username';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'รหัสผ่าน (Password)',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _passwordController,
                    enabled: !_isSubmitting,
                    obscureText: _obscurePassword,
                    autofillHints: const [AutofillHints.password],
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) {
                      if (!_isSubmitting) {
                        _submitLogin();
                      }
                    },
                    decoration: InputDecoration(
                      hintText: 'กรอกรหัสผ่าน',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
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
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _isSubmitting ? null : _forgotPassword,
                      child: const Text('ลืมรหัสผ่าน?'),
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 50,
                    child: FilledButton(
                      onPressed: _isSubmitting ? null : _submitLogin,
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('เข้าสู่ระบบ'),
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
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: LaooColors.greenDark,
      padding: const EdgeInsets.all(44),
      child: Stack(
        children: [
          Positioned(
            right: -60,
            bottom: -60,
            child: Icon(
              Icons.location_city_rounded,
              size: 310,
              color: Colors.white.withValues(alpha: 0.06),
            ),
          ),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'LAOO',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              Text(
                'SOLUTIONS',
                style: TextStyle(
                  color: Color(0xFF8EE6B5),
                  letterSpacing: 4,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Spacer(),
              Text(
                'ยินดีต้อนรับ\nกลับเข้าสู่ระบบ',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  height: 1.2,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 14),
              Text(
                'เข้าใช้งานแพลตฟอร์มของ Laoo Solutions\n'
                'ได้อย่างปลอดภัยบนทุกอุปกรณ์',
                style: TextStyle(color: Color(0xFFCFE7DA), height: 1.6),
              ),
              SizedBox(height: 36),
              Text(
                'Simple Today. Ready Tomorrow.',
                style: TextStyle(
                  color: Color(0xFF8EE6B5),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
