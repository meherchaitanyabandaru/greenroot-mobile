import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:greenroot_mobile/core/media/image_policy.dart';
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

Uint8List _plainJpeg(int w, int h) =>
    Uint8List.fromList(img.encodeJpg(img.Image(width: w, height: h), quality: 80));

XFile _file(Uint8List b, [String name = 'a.jpg']) => XFile.fromData(b, name: name);

final _ad = ImagePolicy.defaults[ImageCategory.marketAd]!; // 400–1600, JPEG only
final _proof = ImagePolicy.defaults[ImageCategory.deliveryProof]!; // 480–2048
final _logo = ImagePolicy.defaults[ImageCategory.nurseryBranding]!; // PNG allowed
final _licence = ImagePolicy.defaults[ImageCategory.driverLicence]!; // ≥600

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

  test('an upright photo that already meets the policy goes untouched (no double compression)', () async {
    final small = _plainJpeg(800, 600);
    final p = await preparePhoto(_file(small), _proof);
    expect(p.bytes, small, reason: 'byte for byte the original');
    expect(p.mimeType, 'image/jpeg');
  });

  test('a sideways photo is turned upright, even when small (the old 1 MB bypass kept it sideways)', () async {
    final im = img.Image(width: 800, height: 600);
    im.exif.imageIfd.orientation = 6; // "rotate 90°" as cameras store it
    final sideways = Uint8List.fromList(img.encodeJpg(im, quality: 80));
    expect(sideways.length, lessThan(1024 * 1024));
    final p = await preparePhoto(_file(sideways), _proof);
    final out = img.decodeJpg(p.bytes)!;
    expect([out.width, out.height], [600, 800]);
    expect(out.exif.imageIfd.orientation ?? 1, 1);
  });

  test('a big photo is scaled to the policy side and compressed once at its quality', () async {
    final big = _bigJpeg(3000, 2000);
    final p = await preparePhoto(_file(big), _proof);
    final out = img.decodeJpg(p.bytes)!;
    expect(out.width, 2048);
    expect(out.height, closeTo(1365, 1));
    expect(p.bytes.length, lessThanOrEqualTo(_proof.maxBytes));
    expect(p.extension, '.jpg');
  });

  test('a photo too small to read is refused with a retake hint', () async {
    expect(
      () => preparePhoto(_file(_plainJpeg(640, 400)), _licence),
      throwsA(isA<PhotoRejected>().having((e) => e.message, 'message',
          allOf(contains('600 pixels'), contains('Take it again')),),),
    );
  });

  test('transparency stays PNG where allowed; PNG becomes JPEG where not', () async {
    final logo = img.Image(width: 1000, height: 1000, numChannels: 4)
      ..setPixelRgba(0, 0, 0, 0, 0, 0);
    final png = Uint8List.fromList(img.encodePng(logo));
    final asLogo = await preparePhoto(_file(png, 'logo.png'), _logo);
    expect(asLogo.mimeType, 'image/png');
    expect(img.decodePng(asLogo.bytes)!.width, 800);
    final asAd = await preparePhoto(_file(png, 'ad.png'), _ad);
    expect(asAd.mimeType, 'image/jpeg');
  });

  test('a photo that cannot fit the byte limit is refused', () async {
    const tight = ImagePolicy(
      category: ImageCategory.marketAd, maxSide: 1600, minSide: 400, quality: 82, maxBytes: 60 * 1024,);
    expect(
      () => preparePhoto(_file(_bigJpeg(1600, 1200)), tight),
      throwsA(isA<PhotoRejected>().having((e) => e.message, 'message', contains('too large'))),
    );
  });

  test('ad photos get the watermark (a new encode, same size)', () async {
    final src = _plainJpeg(1200, 900);
    final p = await preparePhoto(_file(src), _ad, watermark: true);
    expect(p.bytes, isNot(src));
    final out = img.decodeJpg(p.bytes)!;
    expect([out.width, out.height], [1200, 900]);
  });

  test('HEIC the phone did not convert, videos and documents are refused', () async {
    final heic = Uint8List(2048)..setAll(0, _ftyp('heic'));
    expect(
      () => preparePhoto(_file(heic, 'a.heic'), _proof),
      throwsA(isA<PhotoRejected>().having((e) => e.message, 'message', contains("can't be read"))),
    );
    final video = Uint8List(2048)..setAll(0, _ftyp('isom'));
    expect(
      () => preparePhoto(_file(video, 'clip.jpg'), _proof),
      throwsA(isA<PhotoRejected>()
          .having((e) => e.message, 'message', contains('Videos')),),
    );
    final pdf = Uint8List.fromList('%PDF-1.4 hello'.codeUnits);
    expect(
      () => preparePhoto(_file(pdf, 'doc.png'), _proof),
      throwsA(isA<PhotoRejected>()
          .having((e) => e.message, 'message', contains('Only photos')),),
    );
  });

  test('policies from the API override the defaults; unknown categories are ignored', () {
    final p = ImagePolicy.fromJson({
      'category': 'DRIVER_LICENCE', 'max_side': 3000, 'min_side': 700, 'quality': 92,
      'max_bytes': 5000000, 'allowed_formats': ['JPEG'], 'is_compression_enabled': false,
    })!;
    expect([p.maxSide, p.minSide, p.quality, p.allowsPng, p.compressionEnabled], [3000, 700, 92, false, false]);
    expect(ImagePolicy.fromJson({'category': 'ATTACHMENT', 'max_side': 1, 'min_side': 1, 'quality': 1, 'max_bytes': 1}), isNull);
  });
}
