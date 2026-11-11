import 'package:file_picker/file_picker.dart';
import 'ai_image_picker_stub.dart'
    if (dart.library.js_interop) 'ai_image_picker_web.dart'
    as platform;

const int maxAiImageBytes = 3 * 1024 * 1024;

Future<FilePickerResult?> pickAiImage() => platform.pickImage();
