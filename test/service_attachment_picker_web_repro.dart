import 'dart:js_interop';
import 'package:file_picker/file_picker.dart';
import 'package:file_picker/_internal/file_picker_web.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:laoo_service/features/service_request/pages/service_attachment_picker.dart';

@JS('eval')
external JSAny? evaluate(JSString source);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FilePickerWeb.registerWith(webPluginRegistrar);
  evaluate('''
    HTMLInputElement.prototype.click = function() {
      const input = this;
      window.dispatchEvent(new Event('focus'));
      setTimeout(() => {
        const transfer = new DataTransfer();
        transfer.items.add(new File([new Uint8Array([1, 2, 3])], 'test.png', {type: 'image/png'}));
        Object.defineProperty(input, 'files', {value: transfer.files});
        input.dispatchEvent(new Event('change'));
      }, 1200);
    };
  '''.toJS);
  final picker = FilePicker.platform as FilePickerWeb;
  final original = await picker.pickFiles(type: FileType.custom, allowedExtensions: ['png'], withData: true);
  final corrected = await pickServiceAttachmentImages();
  evaluate('''
    HTMLInputElement.prototype.click = function() {
      const input = this;
      setTimeout(() => input.dispatchEvent(new Event('cancel')), 10);
    };
  '''.toJS);
  final cancelled = await pickServiceAttachmentImages();
  final result = 'original=${original?.files.length ?? 0};corrected=${corrected?.files.length ?? 0};cancelled=${cancelled == null}';
  evaluate(('document.body.setAttribute("data-picker-result", "$result")').toJS);
}
