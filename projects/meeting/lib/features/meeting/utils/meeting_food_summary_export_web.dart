import 'dart:convert';
import 'dart:html' as html;

void downloadFoodSummary(String fileName, String content) {
  final blob = html.Blob([
    utf8.encode('\uFEFF$content'),
  ], 'text/csv;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..click();
  html.Url.revokeObjectUrl(url);
}
