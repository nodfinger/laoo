import 'dart:typed_data';

import 'package:image/image.dart' as img;

final class ProviderCompressedImage {
  const ProviderCompressedImage(this.bytes, this.fileName);

  final Uint8List bytes;
  final String fileName;
}

ProviderCompressedImage compressProviderImage(
  List<int> source,
  String originalName, {
  bool square = false,
  int maxBytes = 1024 * 1024,
}) {
  final decoded = img.decodeImage(Uint8List.fromList(source));
  if (decoded == null) throw const FormatException('ไฟล์ที่เลือกไม่ใช่รูปภาพ');
  img.Image image = img.bakeOrientation(decoded);
  if (square) {
    final side = image.width < image.height ? image.width : image.height;
    image = img.copyCrop(
      image,
      x: (image.width - side) ~/ 2,
      y: (image.height - side) ~/ 2,
      width: side,
      height: side,
    );
  }
  if (image.width > 1600 || image.height > 1600) {
    image = img.copyResize(
      image,
      width: image.width >= image.height ? 1600 : null,
      height: image.height > image.width ? 1600 : null,
      interpolation: img.Interpolation.average,
    );
  }
  var quality = 88;
  var encoded = Uint8List.fromList(img.encodeJpg(image, quality: quality));
  while (encoded.length > maxBytes && quality > 50) {
    quality -= 8;
    encoded = Uint8List.fromList(img.encodeJpg(image, quality: quality));
  }
  while (encoded.length > maxBytes && image.width > 640) {
    image = img.copyResize(
      image,
      width: (image.width * .82).round(),
      interpolation: img.Interpolation.average,
    );
    encoded = Uint8List.fromList(img.encodeJpg(image, quality: 72));
  }
  if (encoded.length > maxBytes) {
    throw const FormatException('ไม่สามารถลดรูปให้เหลือไม่เกิน 1 MB ได้');
  }
  final stem = originalName.replaceFirst(RegExp(r'\.[^.]+$'), '');
  return ProviderCompressedImage(encoded, '$stem.jpg');
}
