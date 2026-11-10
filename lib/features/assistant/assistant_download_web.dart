// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

Future<void> saveAssistantFile(
  String name,
  String mime,
  Uint8List bytes,
) async {
  final url = html.Url.createObjectUrlFromBlob(html.Blob([bytes], mime));
  try {
    final anchor = html.AnchorElement(href: url)..download = name;
    anchor.click();
  } finally {
    html.Url.revokeObjectUrl(url);
  }
}
