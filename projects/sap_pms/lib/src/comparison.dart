import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

class SheetData {
  SheetData(this.headers, this.rows, this.date1904);
  final List<String> headers;
  final List<List<String>> rows;
  final bool date1904;
}

class ComparisonRow {
  const ComparisonRow({
    required this.status,
    required this.number,
    required this.date,
    required this.pmsStatus,
    required this.result,
    required this.details,
  });
  final String status, number, date, pmsStatus, result, details;
}

class PmsSapComparison {
  static String _cellText(XmlElement cell, List<String> shared) {
    final type = cell.getAttribute('t');
    final text =
        cell.descendants
            .whereType<XmlElement>()
            .where((x) => x.name.local == 'v')
            .map((x) => x.innerText)
            .firstOrNull ??
        '';
    if (type == 's') {
      final index = int.tryParse(text);
      if (index == null || index < 0 || index >= shared.length)
        throw const FormatException('ไฟล์ Excel มีข้อมูลข้อความไม่สมบูรณ์');
      return shared[index];
    }
    if (type == 'inlineStr')
      return cell.descendants
          .whereType<XmlElement>()
          .where((x) => x.name.local == 't')
          .map((x) => x.innerText)
          .join();
    return text;
  }

  static SheetData read(Uint8List bytes) {
    if (bytes.isEmpty || bytes.length > 20 * 1024 * 1024)
      throw const FormatException('ไฟล์ต้องมีขนาดไม่เกิน 20 MB');
    final archive = ZipDecoder().decodeBytes(bytes);
    if (archive.files.fold<int>(0, (total, file) => total + file.size) >
        100 * 1024 * 1024) {
      throw const FormatException('ข้อมูลภายในไฟล์ Excel มีขนาดใหญ่เกินกำหนด');
    }
    String readXml(String path) {
      final file = archive.findFile(path);
      if (file == null) throw FormatException('ไม่พบ $path ในไฟล์ Excel');
      return utf8.decode(file.content as List<int>);
    }

    final workbook = XmlDocument.parse(readXml('xl/workbook.xml'));
    final properties = workbook.descendants
        .whereType<XmlElement>()
        .where((x) => x.name.local == 'workbookPr')
        .firstOrNull;
    final date1904 =
        properties?.getAttribute('date1904') == '1' ||
        properties?.getAttribute('date1904') == 'true';
    final sheet = workbook.descendants
        .whereType<XmlElement>()
        .where((x) => x.name.local == 'sheet')
        .firstOrNull;
    if (sheet == null) throw const FormatException('ไฟล์ไม่มีแผ่นงาน');
    final relationshipId = sheet.attributes
        .where((x) => x.name.local == 'id')
        .map((x) => x.value)
        .firstOrNull;
    final relations = XmlDocument.parse(readXml('xl/_rels/workbook.xml.rels'));
    final relation = relations.descendants
        .whereType<XmlElement>()
        .where(
          (x) =>
              x.name.local == 'Relationship' &&
              x.getAttribute('Id') == relationshipId,
        )
        .firstOrNull;
    final target = relation?.getAttribute('Target');
    if (target == null || target.contains('..'))
      throw const FormatException('ไม่พบแผ่นงานแรกในไฟล์ Excel');
    final sheetPath = target.startsWith('/')
        ? target.substring(1)
        : target.startsWith('xl/')
        ? target
        : 'xl/$target';
    final sharedFile = archive.findFile('xl/sharedStrings.xml');
    final shared = sharedFile == null
        ? <String>[]
        : XmlDocument.parse(utf8.decode(sharedFile.content as List<int>))
              .descendants
              .whereType<XmlElement>()
              .where((x) => x.name.local == 'si')
              .map(
                (si) => si.descendants
                    .whereType<XmlElement>()
                    .where((x) => x.name.local == 't')
                    .map((x) => x.innerText)
                    .join(),
              )
              .toList();
    final document = XmlDocument.parse(readXml(sheetPath));
    final rows = <List<String>>[];
    for (final row in document.descendants.whereType<XmlElement>().where(
      (x) => x.name.local == 'row',
    )) {
      final values = <String>[];
      for (final cell in row.children.whereType<XmlElement>().where(
        (x) => x.name.local == 'c',
      )) {
        final reference = cell.getAttribute('r') ?? '';
        final letters = RegExp(r'^[A-Za-z]+').stringMatch(reference);
        if (letters == null) continue;
        var column = 0;
        for (final code in letters.toUpperCase().codeUnits) {
          column = column * 26 + code - 64;
        }
        if (column > 256)
          throw const FormatException('ไฟล์มีคอลัมน์เกินขอบเขตที่รองรับ');
        while (values.length < column) {
          values.add('');
        }
        values[column - 1] = _cellText(cell, shared).trim();
      }
      if (values.any((x) => x.isNotEmpty)) rows.add(values);
    }
    if (rows.isEmpty) throw const FormatException('ไฟล์ไม่มีข้อมูล');
    return SheetData(rows.first, rows.skip(1).toList(), date1904);
  }

  static String _at(List<String> row, int index) =>
      index < row.length ? row[index].trim() : '';
  static DateTime? _date(String raw, bool date1904) {
    final number = double.tryParse(raw);
    if (number != null && number >= 0 && number < 100000)
      return (date1904 ? DateTime.utc(1904) : DateTime.utc(1899, 12, 30)).add(
        Duration(days: number.floor()),
      );
    final isoParts = RegExp(
      r'^(\d{4})-(\d{2})-(\d{2})(?:[T ].*)?$',
    ).firstMatch(raw);
    if (isoParts != null) {
      final year = int.parse(isoParts[1]!);
      final month = int.parse(isoParts[2]!);
      final day = int.parse(isoParts[3]!);
      final iso = DateTime.tryParse(raw);
      if (iso == null) return null;
      final original = DateTime.utc(year, month, day);
      if (original.year != year ||
          original.month != month ||
          original.day != day)
        return null;
      return original;
    }
    final parts = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(raw);
    if (parts == null) return null;
    final year = int.parse(parts[3]!);
    final normalizedYear = year > 2400 ? year - 543 : year;
    final month = int.parse(parts[2]!);
    final day = int.parse(parts[1]!);
    final value = DateTime.utc(normalizedYear, month, day);
    return value.year == normalizedYear &&
            value.month == month &&
            value.day == day
        ? value
        : null;
  }

  static String _dateText(DateTime? d, String original) => d == null
      ? (original.isEmpty ? '-' : original)
      : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  static bool _equal(String a, String b) {
    if (a == b) return true;
    if (RegExp(r'^[+-]?0\d').hasMatch(a) || RegExp(r'^[+-]?0\d').hasMatch(b))
      return false;
    final x = num.tryParse(a.replaceAll(',', ''));
    final y = num.tryParse(b.replaceAll(',', ''));
    return x != null && y != null && x == y;
  }

  static List<ComparisonRow> compare(
    SheetData pms,
    SheetData sap, {
    DateTime? from,
    DateTime? to,
  }) {
    final keyIndex = pms.headers.indexWhere(
      (value) => value.trim() == 'เลขที่เอกสาร',
    );
    final statusIndex = pms.headers.indexWhere(
      (value) => value.trim().toLowerCase() == 'pmsstatus',
    );
    var dateIndex = pms.headers.indexWhere(
      (value) => value.trim() == 'วันที่เอกสาร',
    );
    if (dateIndex < 0)
      dateIndex = pms.headers.indexWhere(
        (value) => value.trim() == 'วันที่สร้างเอกสาร',
      );
    if (keyIndex < 0 || statusIndex < 0 || dateIndex < 0) {
      throw const FormatException(
        'ไฟล์ PMS ต้องมีคอลัมน์เลขที่เอกสาร วันที่เอกสารหรือวันที่สร้างเอกสาร และ PmsStatus',
      );
    }
    if (keyIndex >= sap.headers.length ||
        _at(sap.headers, keyIndex) != 'เลขที่เอกสาร') {
      throw const FormatException(
        'ไฟล์ SAP ต้องมีคอลัมน์เลขที่เอกสารในตำแหน่งเดียวกับ PMS',
      );
    }
    final pm = <String, List<List<String>>>{},
        sm = <String, List<List<String>>>{};
    for (final row in pms.rows) {
      final key = _at(row, keyIndex);
      if (key.isNotEmpty) (pm[key] ??= []).add(row);
    }
    for (final row in sap.rows) {
      final key = _at(row, keyIndex);
      if (key.isNotEmpty) (sm[key] ??= []).add(row);
    }
    final result = <ComparisonRow>[];
    for (final row in pms.rows) {
      final key = _at(row, keyIndex),
          rawDate = _at(row, dateIndex),
          status = _at(row, statusIndex);
      final date = _date(rawDate, pms.date1904);
      if (date != null &&
          ((from != null &&
                  date.isBefore(
                    DateTime.utc(from.year, from.month, from.day),
                  )) ||
              (to != null &&
                  date.isAfter(DateTime.utc(to.year, to.month, to.day)))))
        continue;
      String kind = 'normal', summary = 'ข้อมูลตรงกัน', detail = '-';
      if (key.isEmpty || date == null || num.tryParse(status) == null) {
        kind = 'problem';
        summary = 'ข้อมูล PMS ไม่ครบ';
        detail = key.isEmpty
            ? 'ไม่มีเลขที่เอกสาร'
            : date == null
            ? 'วันที่เอกสารไม่ถูกต้อง'
            : 'สถานะ PMS ไม่ถูกต้อง';
      } else if ((pm[key]?.length ?? 0) > 1 || (sm[key]?.length ?? 0) > 1) {
        kind = 'problem';
        summary = 'เลขที่เอกสารซ้ำ';
        detail = 'ไม่จับคู่รายการที่มีเลขที่ซ้ำ';
      } else if (num.tryParse(status) != 2) {
        kind = 'waiting';
        summary = 'ยังไม่ส่ง SAP';
        detail = 'ไม่ตรวจการพบคู่ใน SAP';
      } else if (!sm.containsKey(key)) {
        kind = 'problem';
        summary = 'ไม่พบใน SAP';
        detail = 'ไม่พบเลขที่เอกสารในไฟล์ SAP';
      } else {
        final other = sm[key]!.single;
        final differences = <String>[];
        for (var i = 0; i < pms.headers.length; i++) {
          if (_at(pms.headers, i).isEmpty ||
              i >= sap.headers.length ||
              _at(sap.headers, i).isEmpty)
            continue;
          final a = _at(row, i), b = _at(other, i);
          final isDate = pms.headers[i].contains('วันที่');
          final dateA = isDate ? _date(a, pms.date1904) : null;
          final dateB = isDate ? _date(b, sap.date1904) : null;
          final equal = dateA != null && dateB != null
              ? dateA == dateB
              : _equal(a, b);
          if (!equal) differences.add('${pms.headers[i]}: PMS $a / SAP $b');
        }
        if (differences.isNotEmpty) {
          kind = 'problem';
          summary = 'ข้อมูลไม่ตรงกัน';
          detail = differences.join('\n');
        }
      }
      result.add(
        ComparisonRow(
          status: kind,
          number: key.isEmpty ? '-' : key,
          date: _dateText(date, rawDate),
          pmsStatus: status.isEmpty ? '-' : status,
          result: summary,
          details: detail,
        ),
      );
    }
    for (final row in sap.rows) {
      final key = _at(row, keyIndex);
      if (key.isNotEmpty && pm.containsKey(key)) continue;
      result.add(
        ComparisonRow(
          status: 'problem',
          number: key.isEmpty ? '-' : key,
          date: '-',
          pmsStatus: '-',
          result: key.isEmpty
              ? 'ข้อมูล SAP ไม่ครบ'
              : (sm[key]?.length ?? 0) > 1
              ? 'เลขที่เอกสาร SAP ซ้ำ'
              : 'ไม่พบใน PMS',
          details: 'รายการจาก SAP ที่ไม่มีคู่ PMS',
        ),
      );
    }
    return result;
  }

  static Uint8List export(List<ComparisonRow> rows) {
    String esc(String value) => value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
    final data = <List<String>>[
      [
        'สถานะ',
        'เลขที่เอกสาร',
        'วันที่เอกสาร PMS',
        'PmsStatus',
        'ผลตรวจสอบ',
        'รายละเอียด',
      ],
      ...rows.map(
        (r) => [
          r.status == 'problem'
              ? 'พบปัญหา'
              : r.status == 'waiting'
              ? 'ยังไม่ส่ง'
              : 'ปกติ',
          r.number,
          r.date,
          r.pmsStatus,
          r.result,
          r.details,
        ],
      ),
    ];
    final lines = StringBuffer();
    for (var i = 0; i < data.length; i++) {
      lines.write('<row r="${i + 1}">');
      for (var j = 0; j < data[i].length; j++) {
        lines.write(
          '<c r="${String.fromCharCode(65 + j)}${i + 1}" t="inlineStr"><is><t xml:space="preserve">${esc(data[i][j])}</t></is></c>',
        );
      }
      lines.write('</row>');
    }
    final archive = Archive();
    void add(String path, String value) =>
        archive.addFile(ArchiveFile.string(path, value));
    add(
      '[Content_Types].xml',
      '<?xml version="1.0" encoding="UTF-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/></Types>',
    );
    add(
      '_rels/.rels',
      '<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>',
    );
    add(
      'xl/workbook.xml',
      '<?xml version="1.0" encoding="UTF-8"?><workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Comparison" sheetId="1" r:id="rId1"/></sheets></workbook>',
    );
    add(
      'xl/_rels/workbook.xml.rels',
      '<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/></Relationships>',
    );
    add(
      'xl/worksheets/sheet1.xml',
      '<?xml version="1.0" encoding="UTF-8"?><worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>$lines</sheetData></worksheet>',
    );
    return ZipEncoder().encodeBytes(archive);
  }
}
