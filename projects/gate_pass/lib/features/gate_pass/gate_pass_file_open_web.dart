// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:typed_data';

Future<void> openGatePassFile(
  String name,
  Future<Uint8List> Function() load,
) async {
  final isPdf = name.toLowerCase().endsWith('.pdf');
  final preview = isPdf ? html.window.open('', '_blank') : null;
  try {
    final bytes = await load();
    final url = html.Url.createObjectUrlFromBlob(
      html.Blob([
        bytes,
      ], isPdf ? 'application/pdf' : 'application/octet-stream'),
    );
    if (preview != null) {
      preview.location.href = url;
    } else {
      (html.AnchorElement(href: url)..download = name).click();
    }
    Future<void>.delayed(
      const Duration(minutes: 5),
      () => html.Url.revokeObjectUrl(url),
    );
  } catch (_) {
    preview?.close();
    rethrow;
  }
}
