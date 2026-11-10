import 'package:file_picker/file_picker.dart';
import 'service_attachment_picker_stub.dart'
    if (dart.library.js_interop) 'service_attachment_picker_web.dart'
    as platform;

Future<FilePickerResult?> pickServiceAttachmentImages() =>
    platform.pickImages();
