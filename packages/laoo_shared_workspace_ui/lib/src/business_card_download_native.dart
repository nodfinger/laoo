import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

Future<void> saveBusinessCardImage(
  String name,
  String mime,
  Uint8List bytes,
) async {
  await FilePicker.platform.saveFile(
    dialogTitle: 'บันทึกรูปนามบัตร',
    fileName: name,
    bytes: bytes,
  );
}
