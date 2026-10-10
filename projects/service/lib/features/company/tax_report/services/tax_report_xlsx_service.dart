import 'dart:typed_data';
import 'package:archive/archive.dart';

/// Generates a one-sheet OpenXML workbook locally; no external export service.
class TaxReportXlsxService {
  const TaxReportXlsxService._();

  static Uint8List build(Map<String, dynamic> report) {
    final archive = Archive();
    String xml(String value) => value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
    String inline(String column, int row, Object? value) =>
        '<c r="$column$row" t="inlineStr"><is><t xml:space="preserve">${xml('${value ?? ''}')}</t></is></c>';
    String number(String column, int row, Object? value) {
      final n = num.tryParse('$value') ?? 0;
      return '<c r="$column$row"><v>$n</v></c>';
    }

    final cells = StringBuffer();
    void row(int index, List<String> values) {
      const columns = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J'];
      cells.write('<row r="$index">');
      for (var i = 0; i < values.length; i++) {
        cells.write(inline(columns[i], index, values[i]));
      }
      cells.write('</row>');
    }

    row(1, [
      report['type'] == 'SALE' ? 'รายงานภาษีขาย' : 'รายงานภาษีซื้อ',
      'เดือน ${report['month']}/${report['year']}',
      '${report['companyName'] ?? ''}',
      'เลขภาษี ${report['companyTaxId'] ?? ''}',
      report['branchId'] == null
          ? 'ภาพรวมทุกสาขา'
          : '${report['branchName']} ${report['branchTaxCode']}',
    ]);
    row(2, [
      'ข้อมูลเพื่อการตรวจสอบ ไม่ใช่แบบ ภ.พ.30',
      'เฉพาะใบกำกับภาษีส่วนกลาง ยังไม่รวม POS, School Food, Rental และใบเพิ่ม–ลดหนี้',
    ]);
    row(3, [
      'ลำดับ',
      'วันที่ใบ',
      'เลขใบกำกับฯ',
      'คู่ค้า',
      'เลขภาษีคู่ค้า',
      'สาขาคู่ค้า',
      'มูลค่าก่อนภาษี',
      'VAT',
      'สิทธิ์ภาษีซื้อ',
      'วันที่รับ',
    ]);
    final items = (report['rows'] as List)
        .map((v) => Map<String, dynamic>.from(v as Map))
        .toList();
    for (var i = 0; i < items.length; i++) {
      final r = items[i], index = i + 4;
      cells.write('<row r="$index">');
      cells.write(number('A', index, i + 1));
      cells.write(inline('B', index, r['invoiceDate']));
      cells.write(inline('C', index, r['invoiceCode']));
      cells.write(inline('D', index, r['counterparty']));
      cells.write(inline('E', index, r['taxId']));
      cells.write(inline('F', index, r['counterpartyTaxBranchCode']));
      cells.write(number('G', index, r['taxBase']));
      cells.write(number('H', index, r['taxAmount']));
      cells.write(inline('I', index, r['claimStatus']));
      cells.write(inline('J', index, r['receivedDate']));
      cells.write('</row>');
    }
    final summary = Map<String, dynamic>.from(report['summary'] as Map);
    final total = items.length + 4;
    cells.write(
      '<row r="$total">${inline('F', total, 'รวม')}${number('G', total, summary['taxBase'])}${number('H', total, summary['taxAmount'])}</row>',
    );
    if (report['type'] == 'SALE') {
      final ratedRow = total + 1, zeroRow = total + 2;
      cells.write(
        '<row r="$ratedRow">${inline('F', ratedRow, 'มูลค่ามีอัตราภาษี')}${number('G', ratedRow, summary['ratedTaxBase'])}</row>',
      );
      cells.write(
        '<row r="$zeroRow">${inline('F', zeroRow, 'มูลค่าอัตรา 0%')}${number('G', zeroRow, summary['zeroRatedTaxBase'])}</row>',
      );
    }
    final sheet =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
        '<sheetData>$cells</sheetData></worksheet>';
    archive.addFile(
      ArchiveFile.string(
        '[Content_Types].xml',
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
            '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
            '<Default Extension="xml" ContentType="application/xml"/>'
            '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
            '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
            '</Types>',
      ),
    );
    archive.addFile(
      ArchiveFile.string(
        '_rels/.rels',
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
            '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
            '</Relationships>',
      ),
    );
    archive.addFile(
      ArchiveFile.string(
        'xl/workbook.xml',
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
            '<sheets><sheet name="VAT Report" sheetId="1" r:id="rId1"/></sheets></workbook>',
      ),
    );
    archive.addFile(
      ArchiveFile.string(
        'xl/_rels/workbook.xml.rels',
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
            '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>'
            '</Relationships>',
      ),
    );
    archive.addFile(ArchiveFile.string('xl/worksheets/sheet1.xml', sheet));
    return ZipEncoder().encodeBytes(archive);
  }
}
