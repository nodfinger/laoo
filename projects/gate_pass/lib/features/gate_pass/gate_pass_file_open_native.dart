import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

Future<void> openGatePassFile(
  String name,
  Future<Uint8List> Function() load,
) async {
  await FilePicker.platform.saveFile(fileName: name, bytes: await load());
}
