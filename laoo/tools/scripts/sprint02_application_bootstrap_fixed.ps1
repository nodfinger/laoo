param(
    [string]$ProjectPath = "C:\laoo\laoo"
)

$ErrorActionPreference = "Stop"

function Write-Utf8NoBom {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Content
    )

    $directory = Split-Path -Parent $Path

    if (-not (Test-Path $directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }

    [System.IO.File]::WriteAllText(
        $Path,
        $Content,
        [System.Text.UTF8Encoding]::new($false)
    )
}

if (-not (Test-Path $ProjectPath)) {
    throw "Flutter project was not found: $ProjectPath"
}

$pubspecPath = Join-Path $ProjectPath "pubspec.yaml"

if (-not (Test-Path $pubspecPath)) {
    throw "pubspec.yaml was not found. Check ProjectPath."
}

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupPath = Join-Path $ProjectPath "backup\sprint02_$timestamp"

New-Item -ItemType Directory -Path $backupPath -Force | Out-Null

$filesToBackup = @(
    "lib\main.dart",
    "lib\app.dart",
    "lib\app\app.dart",
    "lib\features\landing\presentation\pages\landing_page.dart",
    "lib\features\authentication\presentation\pages\login_page.dart"
)

foreach ($relativePath in $filesToBackup) {
    $sourcePath = Join-Path $ProjectPath $relativePath

    if (Test-Path $sourcePath) {
        $destinationPath = Join-Path $backupPath $relativePath
        $destinationDirectory = Split-Path -Parent $destinationPath

        New-Item -ItemType Directory -Path $destinationDirectory -Force | Out-Null
        Copy-Item $sourcePath $destinationPath -Force
    }
}

$mainDart = @'
import 'package:flutter/widgets.dart';

import 'app/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LaooApp());
}
'@

$appDart = @'
import 'package:flutter/material.dart';

import 'router/app_router.dart';
import 'theme/app_theme.dart';
import 'theme/app_theme_key.dart';

class LaooApp extends StatelessWidget {
  const LaooApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Laoo Solutions',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.fromKey(AppThemeKey.green),
      routerConfig: appRouter,
    );
  }
}
'@

$landingPageDart = @'
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  static const List<_ProductItem> _products = [
    _ProductItem(
      title: 'Laoo Market',
      description: '\u0E23\u0E30\u0E1A\u0E1A\u0E2B\u0E19\u0E49\u0E32\u0E23\u0E49\u0E32\u0E19\u0E41\u0E25\u0E30\u0E08\u0E31\u0E14\u0E01\u0E32\u0E23\u0E01\u0E32\u0E23\u0E02\u0E32\u0E22\u0E2A\u0E33\u0E2B\u0E23\u0E31\u0E1A\u0E18\u0E38\u0E23\u0E01\u0E34\u0E08',
      icon: Icons.storefront_outlined,
    ),
    _ProductItem(
      title: 'Laoo Meeting',
      description: '\u0E23\u0E30\u0E1A\u0E1A\u0E41\u0E2A\u0E14\u0E07\u0E41\u0E25\u0E30\u0E08\u0E31\u0E14\u0E01\u0E32\u0E23\u0E2B\u0E49\u0E2D\u0E07\u0E1B\u0E23\u0E30\u0E0A\u0E38\u0E21',
      icon: Icons.meeting_room_outlined,
    ),
    _ProductItem(
      title: 'Laoo POS',
      description: '\u0E23\u0E30\u0E1A\u0E1A\u0E02\u0E32\u0E22\u0E2B\u0E19\u0E49\u0E32\u0E23\u0E49\u0E32\u0E19\u0E2A\u0E33\u0E2B\u0E23\u0E31\u0E1A\u0E18\u0E38\u0E23\u0E01\u0E34\u0E08\u0E2B\u0E25\u0E32\u0E22\u0E2A\u0E32\u0E02\u0E32',
      icon: Icons.point_of_sale_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(context)),
            SliverToBoxAdapter(child: _buildHero(context)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
              sliver: SliverToBoxAdapter(
                child: _buildProducts(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        children: [
          Text(
            'Laoo Solutions',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const Spacer(),
          FilledButton.icon(
            onPressed: () => context.goNamed(RouteNames.login),
            icon: const Icon(Icons.login),
            label: const Text('Login'),
          ),
        ],
      ),
    );
  }

  Widget _buildHero(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 56, 24, 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            children: [
              Text(
                'Laoo Solutions',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.05,
                    ),
              ),
              const SizedBox(height: 16),
              Text(
                '\u0E08\u0E38\u0E14\u0E40\u0E23\u0E34\u0E48\u0E21\u0E15\u0E49\u0E19\u0E2A\u0E33\u0E2B\u0E23\u0E31\u0E1A\u0E23\u0E30\u0E1A\u0E1A\u0E07\u0E32\u0E19\u0E41\u0E25\u0E30\u0E1C\u0E25\u0E34\u0E15\u0E20\u0E31\u0E13\u0E11\u0E4C\u0E02\u0E2D\u0E07 Laoo Solutions',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.black54,
                      height: 1.5,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProducts(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Products',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              '\u0E15\u0E31\u0E27\u0E2D\u0E22\u0E48\u0E32\u0E07\u0E23\u0E30\u0E1A\u0E1A\u0E17\u0E35\u0E48\u0E08\u0E30\u0E40\u0E1B\u0E34\u0E14\u0E43\u0E2B\u0E49\u0E40\u0E02\u0E49\u0E32\u0E43\u0E0A\u0E49\u0E07\u0E32\u0E19\u0E43\u0E19\u0E2D\u0E19\u0E32\u0E04\u0E15',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.black54,
                  ),
            ),
            const SizedBox(height: 24),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final columns = width >= 900
                    ? 3
                    : width >= 600
                        ? 2
                        : 1;

                const spacing = 16.0;
                final itemWidth =
                    (width - (spacing * (columns - 1))) / columns;

                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: _products
                      .map(
                        (product) => SizedBox(
                          width: itemWidth,
                          child: _ProductCard(
                            product: product,
                            onPressed: () => _showComingSoon(context),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('\u0E1F\u0E35\u0E40\u0E08\u0E2D\u0E23\u0E4C\u0E19\u0E35\u0E49\u0E2D\u0E22\u0E39\u0E48\u0E23\u0E30\u0E2B\u0E27\u0E48\u0E32\u0E07\u0E01\u0E32\u0E23\u0E1E\u0E31\u0E12\u0E19\u0E32'),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.onPressed,
  });

  final _ProductItem product;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                product.icon,
                size: 40,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                product.title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                product.description,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Colors.black54,
                      height: 1.45,
                    ),
              ),
              const SizedBox(height: 20),
              Text(
                '\u0E2D\u0E22\u0E39\u0E48\u0E23\u0E30\u0E2B\u0E27\u0E48\u0E32\u0E07\u0E01\u0E32\u0E23\u0E1E\u0E31\u0E12\u0E19\u0E32',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductItem {
  const _ProductItem({
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final IconData icon;
}
'@

$loginPageDart = @'
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';

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
      appBar: AppBar(
        leading: IconButton(
          tooltip: '\u0E01\u0E25\u0E31\u0E1A\u0E2B\u0E19\u0E49\u0E32\u0E2B\u0E25\u0E31\u0E01',
          onPressed: () => context.goNamed(RouteNames.landing),
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('Login'),
      ),
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
                      '\u0E40\u0E02\u0E49\u0E32\u0E2A\u0E39\u0E48\u0E23\u0E30\u0E1A\u0E1A\u0E40\u0E1E\u0E37\u0E48\u0E2D\u0E40\u0E23\u0E34\u0E48\u0E21\u0E43\u0E0A\u0E49\u0E07\u0E32\u0E19',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),
                    TextField(
                      controller: txtUsername,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: '\u0E0A\u0E37\u0E48\u0E2D\u0E1C\u0E39\u0E49\u0E43\u0E0A\u0E49\u0E07\u0E32\u0E19',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: txtPassword,
                      obscureText: !isPasswordVisible,
                      onSubmitted: (_) => _showLoginNotConnectedMessage(),
                      decoration: InputDecoration(
                        labelText: '\u0E23\u0E2B\u0E31\u0E2A\u0E1C\u0E48\u0E32\u0E19',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          tooltip: isPasswordVisible
                              ? '\u0E0B\u0E48\u0E2D\u0E19\u0E23\u0E2B\u0E31\u0E2A\u0E1C\u0E48\u0E32\u0E19'
                              : '\u0E41\u0E2A\u0E14\u0E07\u0E23\u0E2B\u0E31\u0E2A\u0E1C\u0E48\u0E32\u0E19',
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
                      onPressed: _showLoginNotConnectedMessage,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: Text('\u0E40\u0E02\u0E49\u0E32\u0E2A\u0E39\u0E48\u0E23\u0E30\u0E1A\u0E1A'),
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

  void _showLoginNotConnectedMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('\u0E23\u0E30\u0E1A\u0E1A Login \u0E08\u0E30\u0E40\u0E0A\u0E37\u0E48\u0E2D\u0E21\u0E15\u0E48\u0E2D API \u0E43\u0E19\u0E02\u0E31\u0E49\u0E19\u0E15\u0E2D\u0E19\u0E16\u0E31\u0E14\u0E44\u0E1B'),
      ),
    );
  }
}
'@

Write-Utf8NoBom `
    -Path (Join-Path $ProjectPath "lib\main.dart") `
    -Content $mainDart

Write-Utf8NoBom `
    -Path (Join-Path $ProjectPath "lib\app\app.dart") `
    -Content $appDart

Write-Utf8NoBom `
    -Path (Join-Path $ProjectPath "lib\features\landing\presentation\pages\landing_page.dart") `
    -Content $landingPageDart

Write-Utf8NoBom `
    -Path (Join-Path $ProjectPath "lib\features\authentication\presentation\pages\login_page.dart") `
    -Content $loginPageDart

$legacyAppPath = Join-Path $ProjectPath "lib\app.dart"

if (Test-Path $legacyAppPath) {
    Remove-Item $legacyAppPath -Force
}

Push-Location $ProjectPath

try {
    Write-Host ""
    Write-Host "Formatting Dart files..." -ForegroundColor Cyan

    dart format `
        "lib\main.dart" `
        "lib\app\app.dart" `
        "lib\features\landing\presentation\pages\landing_page.dart" `
        "lib\features\authentication\presentation\pages\login_page.dart"

    Write-Host ""
    Write-Host "Running flutter pub get..." -ForegroundColor Cyan
    flutter pub get

    Write-Host ""
    Write-Host "Running flutter analyze..." -ForegroundColor Cyan
    flutter analyze

    Write-Host ""
    Write-Host "Sprint 02 completed successfully." -ForegroundColor Green
    Write-Host "Backup: $backupPath" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "Next command: flutter run -d windows" -ForegroundColor Yellow
}
finally {
    Pop-Location
}
