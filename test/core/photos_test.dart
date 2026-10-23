import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:greenroot_mobile/core/media/photos.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

Uint8List _ftyp(String brand) => Uint8List.fromList(
      [0, 0, 0, 24, ...'ftyp'.codeUnits, ...brand.codeUnits, 0, 0, 0, 0],
    );

/// A noisy photo-like JPEG: noise does not compress, so it is large.
Uint8List _bigJpeg(int w, int h) {
  final rnd = Random(1);
  final im = img.Image(width: w, height: h);
  for (final p in im) {
    p
      ..r = rnd.nextInt(256)
      ..g = rnd.nextInt(256)
      ..b = rnd.nextInt(256);
  }
  return Uint8List.fromList(img.encodeJpg(im, quality: 95));
}

void main() {
  test('photoType reads the file, not its name', () {
    expect(photoType(Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0]))?.mime,
        'image/jpeg',);
    expect(photoType(Uint8List.fromList([0x89, 0x50, 0x4E, 0x47, 0, 0]))?.mime,
        'image/png',);
    expect(
        photoType(Uint8List.fromList(
            [...'RIFF'.codeUnits, 0, 0, 0, 0, ...'WEBP'.codeUnits],),)?.mime,
        'image/webp',);
    expect(photoType(_ftyp('heic'))?.mime, 'image/heic');
    expect(photoType(_ftyp('isom')), isNull); // mp4 video
    expect(photoType(Uint8List.fromList('%PDF-1.4'.codeUnits)), isNull);
  });

  test('a small photo is uploaded untouched', () async {
    final small = Uint8List.fromList(
        img.encodeJpg(img.Image(width: 400, height: 300), quality: 80),);
    final p = await preparePhoto(XFile.fromData(small, name: 'a.jpg'));
    expect(p.bytes, same(small));
    expect(p.mimeType, 'image/jpeg');
  });

  test('a big photo is scaled to 2048px and recompressed', () async {
    final big = _bigJpeg(3000, 2000);
    expect(big.length, greaterThan(1024 * 1024));
    final p = await preparePhoto(XFile.fromData(big, name: 'b.jpg'));
    final out = img.decodeJpg(p.bytes)!;
    expect(out.width, 2048);
    expect(out.height, closeTo(1365, 1));
    expect(p.bytes.length, lessThan(big.length));
    expect(p.mimeType, 'image/jpeg');
    expect(p.extension, '.jpg');
  });

  test('videos and documents are refused', () async {
    final video = Uint8List(2048)..setAll(0, _ftyp('isom'));
    expect(
      () => preparePhoto(XFile.fromData(video, name: 'clip.jpg')),
      throwsA(isA<PhotoRejected>()
          .having((e) => e.message, 'message', contains('Videos')),),
    );
    final pdf = Uint8List.fromList('%PDF-1.4 hello'.codeUnits);
    expect(
      () => preparePhoto(XFile.fromData(pdf, name: 'doc.png')),
      throwsA(isA<PhotoRejected>()
          .having((e) => e.message, 'message', contains('Only photos')),),
    );
  });
}
