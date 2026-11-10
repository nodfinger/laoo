import 'package:file_picker/file_picker.dart';
import 'package:file_picker/_internal/file_picker_web.dart';

Future<FilePickerResult?> pickImage() {
  final picker = FilePicker.platform;
  if (picker is FilePickerWeb) {
    return picker.pickFiles(
      type: FileType.image,
      withData: true,
      cancelUploadOnWindowBlur: false,
    );
  }
  return picker.pickFiles(type: FileType.image, withData: true);
}
