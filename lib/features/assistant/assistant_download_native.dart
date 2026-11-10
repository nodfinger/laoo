import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

Future<void> saveAssistantFile(
  String name,
  String mime,
  Uint8List bytes,
) async {
  await FilePicker.platform.saveFile(
    dialogTitle: 'บันทึกรายงาน',
    fileName: name,
    bytes: bytes,
  );
}
