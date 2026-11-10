import 'package:file_picker/file_picker.dart';

import 'employee_image_picker_stub.dart'
    if (dart.library.js_interop) 'employee_image_picker_web.dart'
    as platform;

Future<FilePickerResult?> pickEmployeeImage() => platform.pickImage();
