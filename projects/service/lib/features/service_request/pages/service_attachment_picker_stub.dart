import 'package:file_picker/file_picker.dart';

Future<FilePickerResult?> pickImages() => FilePicker.platform.pickFiles(
  type: FileType.custom,
  allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
  allowMultiple: true,
  withData: true,
);
