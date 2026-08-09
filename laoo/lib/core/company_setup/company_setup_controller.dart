import 'package:flutter/foundation.dart';

import 'company_setup_context.dart';
import 'company_setup_service.dart';

final CompanySetupController companySetupController =
    CompanySetupController();

class CompanySetupController extends ChangeNotifier {
  CompanySetupController({CompanySetupService? service})
      : _service = service ?? CompanySetupService();

  final CompanySetupService _service;
  CompanySetupContext? _current;

  CompanySetupContext? get current => _current;

  String get appTitle {
    final value = _current?.titleHeader.trim() ?? '';
    return value.isEmpty ? 'Laoo Solutions' : value;
  }

  String get versionText {
    final value = _current?.versionId.trim() ?? '';
    return value.isEmpty ? '' : 'Version $value';
  }

  int get pageSize => _current?.rowStd ?? 50;

  Future<CompanySetupContext> load() async {
    final setup = await _service.loadRuntime();
    _current = setup;
    notifyListeners();
    return setup;
  }

  void clear() {
    _current = null;
    notifyListeners();
  }
}
