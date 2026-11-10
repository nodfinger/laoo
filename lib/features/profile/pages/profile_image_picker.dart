import 'package:file_picker/file_picker.dart';

import 'profile_image_picker_stub.dart'
    if (dart.library.js_interop) 'profile_image_picker_web.dart'
    as platform;

Future<FilePickerResult?> pickProfileImage() => platform.pickImage();
