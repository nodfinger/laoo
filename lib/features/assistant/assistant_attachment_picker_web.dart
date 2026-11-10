import 'package:file_picker/file_picker.dart';
import 'package:file_picker/_internal/file_picker_web.dart';

Future<FilePickerResult?> pickImages() {
  final picker = FilePicker.platform;
  if (picker is FilePickerWeb) {
    // The plugin's focus-based timeout may fire before Chrome emits change.
    // Rely on the file input's native cancel event on web instead.
    return picker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
      allowMultiple: true,
      withData: true,
      cancelUploadOnWindowBlur: false,
    );
  }
  return picker.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
    allowMultiple: true,
    withData: true,
  );
}
