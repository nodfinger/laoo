import 'package:file_picker/file_picker.dart';

Future<FilePickerResult?> pickImage() =>
    FilePicker.platform.pickFiles(type: FileType.image, withData: true);
