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
$backupPath = Join-Path $ProjectPath "backup\sprint03_$timestamp"
$loginPagePath = Join-Path $ProjectPath "lib\features\authentication\presentation\pages\login_page.dart"

New-Item -ItemType Directory -Path $backupPath -Force | Out-Null

if (Test-Path $loginPagePath) {
    $backupFilePath = Join-Path $backupPath "lib\features\authentication\presentation\pages\login_page.dart"
    $backupDirectory = Split-Path -Parent $backupFilePath
    New-Item -ItemType Directory -Path $backupDirectory -Force | Out-Null
    Copy-Item $loginPagePath $backupFilePath -Force
}

$loginPageDart = @'
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';

enum LoginType {
  user,
  admin,
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController txtUsername = TextEditingController();
  final TextEditingController txtPassword = TextEditingController();

  LoginType loginType = LoginType.user;
  bool isPasswordVisible = false;
  bool isSubmitting = false;

  @override
  void dispose() {
    txtUsername.dispose();
    txtPassword.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = loginType == LoginType.admin;

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
            constraints: const BoxConstraints(maxWidth: 460),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        isAdmin
                            ? Icons.admin_panel_settings_outlined
                            : Icons.person_outline,
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
                      Text(
                        isAdmin
                            ? '\u0E40\u0E02\u0E49\u0E32\u0E2A\u0E39\u0E48\u0E23\u0E30\u0E1A\u0E1A\u0E2B\u0E25\u0E31\u0E07\u0E1A\u0E49\u0E32\u0E19\u0E2A\u0E33\u0E2B\u0E23\u0E31\u0E1A\u0E1C\u0E39\u0E49\u0E14\u0E39\u0E41\u0E25\u0E23\u0E30\u0E1A\u0E1A'
                            : '\u0E40\u0E02\u0E49\u0E32\u0E2A\u0E39\u0E48\u0E23\u0E30\u0E1A\u0E1A\u0E40\u0E1E\u0E37\u0E48\u0E2D\u0E40\u0E23\u0E34\u0E48\u0E21\u0E43\u0E0A\u0E49\u0E07\u0E32\u0E19',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      SegmentedButton<LoginType>(
                        segments: const [
                          ButtonSegment<LoginType>(
                            value: LoginType.user,
                            icon: Icon(Icons.person_outline),
                            label: Text('\u0E1C\u0E39\u0E49\u0E43\u0E0A\u0E49\u0E07\u0E32\u0E19'),
                          ),
                          ButtonSegment<LoginType>(
                            value: LoginType.admin,
                            icon: Icon(Icons.admin_panel_settings_outlined),
                            label: Text('\u0E1C\u0E39\u0E49\u0E14\u0E39\u0E41\u0E25\u0E23\u0E30\u0E1A\u0E1A'),
                          ),
                        ],
                        selected: <LoginType>{loginType},
                        onSelectionChanged: isSubmitting
                            ? null
                            : (selection) {
                                setState(() {
                                  loginType = selection.first;
                                });
                              },
                      ),
                      const SizedBox(height: 28),
                      TextFormField(
                        controller: txtUsername,
                        enabled: !isSubmitting,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.username],
                        decoration: const InputDecoration(
                          labelText: '\u0E0A\u0E37\u0E48\u0E2D\u0E1C\u0E39\u0E49\u0E43\u0E0A\u0E49\u0E07\u0E32\u0E19',
                          prefixIcon: Icon(Icons.person_outline),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return '\u0E01\u0E23\u0E38\u0E13\u0E32\u0E01\u0E23\u0E2D\u0E01\u0E0A\u0E37\u0E48\u0E2D\u0E1C\u0E39\u0E49\u0E43\u0E0A\u0E49\u0E07\u0E32\u0E19';
                          }

                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: txtPassword,
                        enabled: !isSubmitting,
                        obscureText: !isPasswordVisible,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: '\u0E23\u0E2B\u0E31\u0E2A\u0E1C\u0E48\u0E32\u0E19',
                          prefixIcon: const Icon(Icons.lock_outline),
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            tooltip: isPasswordVisible
                                ? '\u0E0B\u0E48\u0E2D\u0E19\u0E23\u0E2B\u0E31\u0E2A\u0E1C\u0E48\u0E32\u0E19'
                                : '\u0E41\u0E2A\u0E14\u0E07\u0E23\u0E2B\u0E31\u0E2A\u0E1C\u0E48\u0E32\u0E19',
                            onPressed: isSubmitting
                                ? null
                                : () {
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
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return '\u0E01\u0E23\u0E38\u0E13\u0E32\u0E01\u0E23\u0E2D\u0E01\u0E23\u0E2B\u0E31\u0E2A\u0E1C\u0E48\u0E32\u0E19';
                          }

                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: isSubmitting ? null : _submit,
                        icon: isSubmitting
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.login),
                        label: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Text(
                            isSubmitting
                                ? '\u0E01\u0E33\u0E25\u0E31\u0E07\u0E15\u0E23\u0E27\u0E08\u0E2A\u0E2D\u0E1A...'
                                : '\u0E40\u0E02\u0E49\u0E32\u0E2A\u0E39\u0E48\u0E23\u0E30\u0E1A\u0E1A',
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '\u0E02\u0E31\u0E49\u0E19\u0E15\u0E2D\u0E19\u0E19\u0E35\u0E49\u0E22\u0E31\u0E07\u0E44\u0E21\u0E48\u0E40\u0E0A\u0E37\u0E48\u0E2D\u0E21\u0E15\u0E48\u0E2D API',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.black54,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      isSubmitting = true;
    });

    await Future<void>.delayed(const Duration(milliseconds: 500));

    if (!mounted) {
      return;
    }

    setState(() {
      isSubmitting = false;
    });

    final loginTypeText = loginType == LoginType.admin
        ? '\u0E1C\u0E39\u0E49\u0E14\u0E39\u0E41\u0E25\u0E23\u0E30\u0E1A\u0E1A'
        : '\u0E1C\u0E39\u0E49\u0E43\u0E0A\u0E49\u0E07\u0E32\u0E19';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '\u0E1F\u0E2D\u0E23\u0E4C\u0E21 $loginTypeText \u0E1C\u0E48\u0E32\u0E19\u0E01\u0E32\u0E23\u0E15\u0E23\u0E27\u0E08\u0E2A\u0E2D\u0E1A \u0E23\u0E2D\u0E40\u0E0A\u0E37\u0E48\u0E2D\u0E21\u0E15\u0E48\u0E2D API',
        ),
      ),
    );
  }
}
'@

Write-Utf8NoBom -Path $loginPagePath -Content $loginPageDart

Push-Location $ProjectPath

try {
    Write-Host ""
    Write-Host "Formatting login page..." -ForegroundColor Cyan
    dart format "lib\features\authentication\presentation\pages\login_page.dart"

    Write-Host ""
    Write-Host "Running flutter analyze..." -ForegroundColor Cyan
    flutter analyze

    Write-Host ""
    Write-Host "Sprint 03 completed successfully." -ForegroundColor Green
    Write-Host "Backup: $backupPath" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "Next command: flutter run -d windows" -ForegroundColor Yellow
}
finally {
    Pop-Location
}
