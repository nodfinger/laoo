import 'company_setup_context.dart';

abstract final class CompanyDateFormatter {
  static String formatCurrentDate(CompanySetupContext setup) {
    return formatDate(DateTime.now(), setup);
  }

  static String formatDate(DateTime value, CompanySetupContext setup) {
    return formatDateByYearFormat(value, setup.yearFormat);
  }

  static String formatDateByYearFormat(DateTime value, String yearFormat) {
    final year = _useBuddhistEra(yearFormat) ? value.year + 543 : value.year;

    return '${_two(value.day)}/${_two(value.month)}/$year';
  }

  static bool _useBuddhistEra(String value) {
    switch (value.trim().toUpperCase()) {
      case 'B':
      case 'BE':
      case 'T':
      case 'TH':
      case 'THAI':
        return true;
      default:
        return false;
    }
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
}
