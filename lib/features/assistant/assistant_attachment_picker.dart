import 'package:file_picker/file_picker.dart';
import 'assistant_attachment_picker_stub.dart'
    if (dart.library.js_interop) 'assistant_attachment_picker_web.dart'
    as platform;

Future<FilePickerResult?> pickAssistantImages() => platform.pickImages();
