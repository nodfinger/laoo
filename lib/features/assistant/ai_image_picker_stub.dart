import 'package:file_picker/file_picker.dart';

Future<FilePickerResult?> pickImage() => FilePicker.platform.pickFiles(
  type: FileType.custom,
  allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
  withData: true,
);
