abstract final class CompanySetupConstants {
  static const cConstRunItem = '002';
  static const cConstRunCus = '001';
  static const employeeNameFull = 'FULL';
  static const employeeNameNick = 'NICK';
  static const employeeNameBoth = 'BOTH';
  static const employeeNameOptions = <String>[
    employeeNameFull,
    employeeNameNick,
    employeeNameBoth,
  ];
  static String employeeNameLabel(String value) => switch (value) {
    employeeNameNick => 'เฉพาะชื่อเล่น',
    employeeNameBoth => 'ชื่อจริงและชื่อเล่น',
    _ => 'เฉพาะชื่อจริง',
  };
  static const yearFormatAd = 'AD';
  static const yearFormatBe = 'BE';

  static const yearFormatOptions = <String>[yearFormatBe, yearFormatAd];

  static String yearFormatLabel(String value) => switch (value) {
    yearFormatBe => 'พ.ศ. (BE)',
    yearFormatAd => 'ค.ศ. (AD)',
    _ => 'ค.ศ. (AD)',
  };
}
