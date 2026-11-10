@TestOn('browser')
library;

import 'dart:js_interop';

import 'package:file_picker/_internal/file_picker_web.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:laoo/features/profile/pages/profile_image_picker.dart';

@JS('eval')
external JSAny? evaluate(JSString source);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  FilePickerWeb.registerWith(webPluginRegistrar);

  test(
    'keeps waiting for the selected profile image after window focus',
    () async {
      evaluate(
        '''
      window.originalPickerClick = HTMLInputElement.prototype.click;
      HTMLInputElement.prototype.click = function() {
        const input = this;
        window.dispatchEvent(new Event('focus'));
        setTimeout(() => {
          const files = new DataTransfer();
          files.items.add(new File([new Uint8Array([1, 2, 3])], 'avatar.png', {type: 'image/png'}));
          Object.defineProperty(input, 'files', {value: files.files});
          input.dispatchEvent(new Event('change'));
        }, 1200);
      };
    '''
            .toJS,
      );
      try {
        final result = await pickProfileImage();
        expect(result?.files.single.name, 'avatar.png');
        expect(result?.files.single.bytes, [1, 2, 3]);
      } finally {
        evaluate(
          'HTMLInputElement.prototype.click = window.originalPickerClick'.toJS,
        );
      }
    },
  );
}
