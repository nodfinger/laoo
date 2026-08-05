param(
    [switch]$InstallPackages,
    [switch]$Overwrite
)

$ErrorActionPreference = "Stop"

function Write-Section {
    param([string]$Text)
    Write-Host ""
    Write-Host "====================================="
    Write-Host $Text
    Write-Host "====================================="
}

function Write-FileSafe {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Content
    )

    $fullPath = Join-Path (Get-Location) $Path
    $parent = Split-Path $fullPath -Parent

    if (-not (Test-Path $parent)) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }

    if ((Test-Path $fullPath) -and -not $Overwrite) {
        Write-Host "[SKIP] $Path already exists"
        return
    }

    Set-Content -Path $fullPath -Value $Content -Encoding UTF8
    Write-Host "[OK]   $Path"
}

Write-Section "Laoo Solutions Flutter Foundation Generator"

if (-not (Test-Path ".\pubspec.yaml")) {
    throw "pubspec.yaml not found. Run this script from the Flutter project root."
}

$folders = @(
    "lib/app/router",
    "lib/app/theme",

    "lib/core/constants",
    "lib/core/network",
    "lib/core/services",
    "lib/core/storage",
    "lib/core/utils",

    "lib/shared/models",
    "lib/shared/providers",
    "lib/shared/widgets",

    "lib/features/splash/presentation/pages",

    "lib/features/authentication/data/models",
    "lib/features/authentication/data/repositories",
    "lib/features/authentication/data/services",
    "lib/features/authentication/domain/entities",
    "lib/features/authentication/domain/repositories",
    "lib/features/authentication/presentation/pages",
    "lib/features/authentication/presentation/providers",
    "lib/features/authentication/presentation/states",
    "lib/features/authentication/presentation/widgets",

    "lib/features/home/presentation/pages",
    "lib/features/home/presentation/providers",
    "lib/features/home/presentation/widgets",

    "lib/features/marketplace/presentation/pages",
    "lib/features/marketplace/presentation/providers",
    "lib/features/marketplace/presentation/widgets",

    "lib/features/product/presentation/pages",
    "lib/features/product/presentation/providers",
    "lib/features/product/presentation/widgets",

    "lib/features/profile/presentation/pages",
    "lib/features/profile/presentation/providers",
    "lib/features/profile/presentation/widgets",

    "test/app",
    "test/features"
)

Write-Section "Creating folders"

foreach ($folder in $folders) {
    New-Item -ItemType Directory -Force -Path $folder | Out-Null
    Write-Host "[OK]   $folder"
}

if ($InstallPackages) {
    Write-Section "Installing packages"
    flutter pub add flutter_riverpod
    flutter pub add go_router
    flutter pub get
}

Write-Section "Creating foundation files"

Write-FileSafe -Path "lib/main.dart" -Content @'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    const ProviderScope(
      child: LaooApp(),
    ),
  );
}
'@

Write-FileSafe -Path "lib/app/router/route_names.dart" -Content @'
abstract final class RouteNames {
  static const String splash = 'splash';
  static const String login = 'login';
  static const String home = 'home';
}
'@

Write-FileSafe -Path "lib/app/router/route_paths.dart" -Content @'
abstract final class RoutePaths {
  static const String splash = '/';
  static const String login = '/login';
  static const String home = '/home';
}
'@

Write-FileSafe -Path "lib/features/splash/presentation/pages/splash_page.dart" -Content @'
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();

    _navigationTimer = Timer(
      const Duration(seconds: 2),
      () {
        if (!mounted) {
          return;
        }

        context.goNamed(RouteNames.login);
      },
    );
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1ABC9C),
              Color(0xFF148F77),
            ],
          ),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.storefront_rounded,
              size: 88,
              color: Colors.white,
            ),
            SizedBox(height: 20),
            Text(
              'Laoo Solutions',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Connecting business through technology',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 32),
            CircularProgressIndicator(
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}
'@

Write-FileSafe -Path "lib/features/authentication/presentation/pages/login_page.dart" -Content @'
import 'package:flutter/material.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController txtUsername = TextEditingController();
  final TextEditingController txtPassword = TextEditingController();

  bool isPasswordVisible = false;

  @override
  void dispose() {
    txtUsername.dispose();
    txtPassword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.storefront_rounded,
                      size: 64,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Laoo Solutions',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'เข้าสู่ระบบเพื่อใช้งาน',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),
                    TextField(
                      controller: txtUsername,
                      decoration: const InputDecoration(
                        labelText: 'ชื่อผู้ใช้งาน',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: txtPassword,
                      obscureText: !isPasswordVisible,
                      decoration: InputDecoration(
                        labelText: 'รหัสผ่าน',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() {
                              isPasswordVisible = !isPasswordVisible;
                            });
                          },
                          icon: Icon(
                            isPasswordVisible
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: () {},
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: Text('เข้าสู่ระบบ'),
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
  }
}
'@

Write-FileSafe -Path "lib/features/home/presentation/pages/home_page.dart" -Content @'
import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          'Laoo Solutions Home',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
'@

Write-FileSafe -Path "lib/app/router/app_router.dart" -Content @'
import 'package:go_router/go_router.dart';

import '../../features/authentication/presentation/pages/login_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/splash/presentation/pages/splash_page.dart';
import 'route_names.dart';
import 'route_paths.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: RoutePaths.splash,
  routes: [
    GoRoute(
      path: RoutePaths.splash,
      name: RouteNames.splash,
      builder: (context, state) => const SplashPage(),
    ),
    GoRoute(
      path: RoutePaths.login,
      name: RouteNames.login,
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(
      path: RoutePaths.home,
      name: RouteNames.home,
      builder: (context, state) => const HomePage(),
    ),
  ],
);
'@

Write-FileSafe -Path "lib/app/app.dart" -Content @'
import 'package:flutter/material.dart';

import 'router/app_router.dart';

class LaooApp extends StatelessWidget {
  const LaooApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Laoo Solutions',
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1ABC9C),
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F9F9),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }
}
'@

Write-Section "Formatting and checking"

dart format lib

Write-Host ""
Write-Host "Run these commands next:"
Write-Host "  flutter analyze"
Write-Host "  flutter run -d chrome"
Write-Host ""
Write-Host "Use -Overwrite only when you intentionally want to replace existing files."
Write-Host "Example:"
Write-Host "  .\create_laoo_project.ps1 -Overwrite"
