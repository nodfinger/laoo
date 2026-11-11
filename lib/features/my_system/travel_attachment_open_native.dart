import 'dart:typed_data';
import '../assistant/assistant_download.dart';

Future<void> openTravelPdf(
  String name,
  Future<Uint8List> Function() load,
) async {
  // The native client has no built-in PDF viewer; retain its save-file fallback.
  await saveAssistantFile(name, 'application/pdf', await load());
}
