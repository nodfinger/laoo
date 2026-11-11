// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:typed_data';

Future<void> openTravelPdf(
  String name,
  Future<Uint8List> Function() load,
) async {
  // Open during the click so the browser does not block the preview after I/O.
  final preview = html.window.open('', '_blank');
  try {
    final bytes = await load();
    final url = html.Url.createObjectUrlFromBlob(
      html.Blob([bytes], 'application/pdf'),
    );
    preview.location.href = url;
    Future<void>.delayed(
      const Duration(minutes: 5),
      () => html.Url.revokeObjectUrl(url),
    );
  } catch (_) {
    preview.close();
    rethrow;
  }
}
