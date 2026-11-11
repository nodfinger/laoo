abstract final class TravelAccessScope {
  static const self = 'SELF';
  static const department = 'DEPARTMENT';
  static const division = 'DIVISION';
  static const values = [self, department, division];
}

abstract final class TravelAccessMode {
  static const everyone = 'ALL';
  static const supervisor = 'HEAD';
  static const values = [everyone, supervisor];
}
