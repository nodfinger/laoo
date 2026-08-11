abstract final class CompanySetupConstants {
  static const yearFormatAd = 'AD';
  static const yearFormatBe = 'BE';

  static const yearFormatOptions = <String>[
    yearFormatBe,
    yearFormatAd,
  ];

  static String yearFormatLabel(String value) => switch (value) {
        yearFormatBe => 'พ.ศ. (BE)',
        yearFormatAd => 'ค.ศ. (AD)',
        _ => 'ค.ศ. (AD)',
      };
}
