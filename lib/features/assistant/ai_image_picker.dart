import 'package:file_picker/file_picker.dart';
import 'ai_image_picker_stub.dart'
    if (dart.library.js_interop) 'ai_image_picker_web.dart'
    as platform;

Future<FilePickerResult?> pickAiImage() => platform.pickImage();
