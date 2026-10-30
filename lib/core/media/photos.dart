// Taking and preparing photos for upload, in one place:
// - opening the camera/gallery never crashes; the user is told why it failed;
// - only photos are accepted (checked from the file itself, so a video or
//   document renamed .jpg is refused);
// - each photo follows its category's image policy (image_policy.dart):
//   turned upright, too-small photos refused with a retake hint, resized to
//   the policy's longest side and compressed once at its quality. A photo
//   that already meets the policy (upright, no EXIF, small enough) goes as it
//   is, so nothing is compressed twice. The API checks every upload again.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../theme/app_colors.dart';
import 'image_policy.dart';

/// Anything this big is not a phone photo; refused before reading it.
const _maxPickedBytes = 40 * 1024 * 1024;

class PhotoRejected implements Exception {
  final String message;
  const PhotoRejected(this.message);
  @override
  String toString() => message;
}

class PreparedPhoto {
  final Uint8List bytes;
  final String mimeType;
  final String extension; // ".jpg"
  const PreparedPhoto(this.bytes, this.mimeType, this.extension);
}

/// A message the user can act on, for an error opening the camera/gallery.
String photoPickErrorMessage(Object error, ImageSource source) {
  final code = error is PlatformException ? error.code : '';
  if (code.contains('access_denied') || code.contains('permission')) {
    return source == ImageSource.camera
        ? 'Camera permission is off. Allow it for GreenRoot in your phone Settings, then try again.'
        : 'Photo access is off. Allow it for GreenRoot in your phone Settings, then try again.';
  }
  if (code == 'no_available_camera') {
    return 'No camera found on this phone. Choose a photo from the gallery instead.';
  }
  return source == ImageSource.camera
      ? "The camera didn't open. Close other apps using it and try again, or choose from the gallery."
      : "The gallery didn't open. Please try again.";
}

void _say(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: AppColors.red600,
      behavior: SnackBarBehavior.floating,
    ),
  );
}

/// Opens the camera or gallery. Never throws: on failure it tells the user why
/// and returns null. With [policy] the phone scales the photo to its longest
/// side natively (cheap, and it turns HEIC into JPEG) without lowering the
/// quality: preparePhoto compresses once.
Future<XFile?> pickPhoto(
  BuildContext context,
  ImageSource source, {
  CameraDevice camera = CameraDevice.rear,
  ImagePolicy? policy,
}) async {
  try {
    return await ImagePicker().pickImage(
      source: source,
      preferredCameraDevice: camera,
      maxWidth: policy?.maxSide.toDouble(),
      maxHeight: policy?.maxSide.toDouble(),
    );
  } on PlatformException catch (e) {
    if (e.code != 'already_active') {
      // A second tap while the picker is open is not an error.
      if (context.mounted) _say(context, photoPickErrorMessage(e, source));
    }
  } catch (e) {
    if (context.mounted) _say(context, photoPickErrorMessage(e, source));
  }
  return null;
}

/// Several photos from the gallery; same rules as [pickPhoto].
Future<List<XFile>> pickPhotos(
  BuildContext context, {
  required int limit,
  ImagePolicy? policy,
}) async {
  try {
    final files = await ImagePicker().pickMultiImage(
      limit: limit < 2 ? null : limit,
      maxWidth: policy?.maxSide.toDouble(),
      maxHeight: policy?.maxSide.toDouble(),
    );
    return files.take(limit).toList();
  } catch (e) {
    if (context.mounted) {
      _say(context, photoPickErrorMessage(e, ImageSource.gallery));
    }
    return const [];
  }
}

/// The image type of [bytes] from its first bytes, or null when it is not a
/// photo we accept (videos, documents, anything else).
({String mime, String ext})? photoType(Uint8List b) {
  bool at(int i, List<int> sig) {
    if (b.length < i + sig.length) return false;
    for (var k = 0; k < sig.length; k++) {
      if (b[i + k] != sig[k]) return false;
    }
    return true;
  }

  if (at(0, [0xFF, 0xD8, 0xFF])) return (mime: 'image/jpeg', ext: '.jpg');
  if (at(0, [0x89, 0x50, 0x4E, 0x47])) return (mime: 'image/png', ext: '.png');
  if (at(0, 'GIF8'.codeUnits)) return (mime: 'image/gif', ext: '.gif');
  if (at(0, 'RIFF'.codeUnits) && at(8, 'WEBP'.codeUnits)) {
    return (mime: 'image/webp', ext: '.webp');
  }
  if (at(4, 'ftyp'.codeUnits) && b.length >= 12) {
    final brand = String.fromCharCodes(b.sublist(8, 12));
    if (const {'heic', 'heix', 'heim', 'heis', 'mif1', 'msf1'}
        .contains(brand)) {
      return (mime: 'image/heic', ext: '.heic');
    }
    if (brand == 'heif') return (mime: 'image/heif', ext: '.heif');
  }
  return null;
}

bool _looksLikeVideo(Uint8List b) =>
    b.length >= 12 &&
    String.fromCharCodes(b.sublist(4, 8)) == 'ftyp' &&
    photoType(b) == null;

/// Checks [file] is a photo and makes it meet [policy] (see the top of this
/// file). [watermark] draws "GreenRoot" in the corner (market ads). Throws
/// [PhotoRejected] with a message saying what to do (retake, other photo).
Future<PreparedPhoto> preparePhoto(XFile file, ImagePolicy policy,
    {bool watermark = false,}) async {
  if (await file.length() > _maxPickedBytes) {
    throw const PhotoRejected('This file is too large. Please choose a photo.');
  }
  final original = await file.readAsBytes();
  if (photoType(original) == null) {
    throw PhotoRejected(
      _looksLikeVideo(original)
          ? "Videos can't be uploaded. Please choose a photo."
          : 'Only photos can be uploaded (JPG, PNG, WebP or HEIC).',
    );
  }
  // Decoding a camera photo takes a moment: keep it off the UI thread.
  final r = await compute(_prepare, (
    bytes: original,
    maxSide: policy.maxSide,
    minSide: policy.minSide,
    quality: policy.quality,
    maxBytes: policy.maxBytes,
    allowsPng: policy.allowsPng,
    compress: policy.compressionEnabled,
    watermark: watermark,
  ),);
  switch (r.problem) {
    case _Problem.none:
      return PreparedPhoto(r.bytes!, r.mime!, r.ext!);
    case _Problem.unreadable:
      throw const PhotoRejected(
          "This photo can't be read. Take it again with the camera, or choose a JPG or PNG photo.",);
    case _Problem.tooSmall:
      throw PhotoRejected(
          'This photo is too small to read (at least ${policy.minSide} pixels on its short side). '
          'Take it again closer, in good light.',);
    case _Problem.tooLarge:
      throw PhotoRejected(
          'This photo is still too large after compressing (max ${policy.maxBytes ~/ 1024} KB). '
          'Take it again or choose another one.',);
  }
}

enum _Problem { none, unreadable, tooSmall, tooLarge }

typedef _Job = ({
  Uint8List bytes,
  int maxSide,
  int minSide,
  int quality,
  int maxBytes,
  bool allowsPng,
  bool compress,
  bool watermark,
});

typedef _Result = ({_Problem problem, Uint8List? bytes, String? mime, String? ext});

const _jpegFloor = 50; // lowest quality tried to fit max bytes (the API's floor)

_Result _prepare(_Job j) {
  final decoded = img.decodeImage(j.bytes);
  if (decoded == null) {
    // e.g. HEIC the phone did not convert: the API could not read it either.
    return (problem: _Problem.unreadable, bytes: null, mime: null, ext: null);
  }
  final sideways = (decoded.exif.imageIfd.orientation ?? 1) != 1;
  var image = sideways ? img.bakeOrientation(decoded) : decoded;
  final longest = image.width > image.height ? image.width : image.height;
  final shortest = image.width < image.height ? image.width : image.height;
  if (shortest < j.minSide) {
    return (problem: _Problem.tooSmall, bytes: null, mime: null, ext: null);
  }
  final type = photoType(j.bytes)!;
  final isPng = type.mime == 'image/png';
  final formatOk = type.mime == 'image/jpeg' || (isPng && j.allowsPng);

  // Already meets the policy: send it as it is (no second compression).
  // A photo with EXIF is re-encoded so its GPS and camera data are dropped.
  if (!sideways &&
      longest <= j.maxSide &&
      formatOk &&
      j.bytes.length <= j.maxBytes &&
      !j.watermark &&
      decoded.exif.isEmpty) {
    return (problem: _Problem.none, bytes: j.bytes, mime: type.mime, ext: type.ext);
  }

  if (longest > j.maxSide) {
    image = image.width >= image.height
        ? img.copyResize(image, width: j.maxSide, interpolation: img.Interpolation.average)
        : img.copyResize(image, height: j.maxSide, interpolation: img.Interpolation.average);
  }
  image.exif = img.ExifData(); // no location or camera data in uploads
  if (j.watermark) _drawWatermark(image);

  // Transparency (logos) stays PNG where the policy allows PNG.
  if (isPng && j.allowsPng && image.hasAlpha) {
    final png = Uint8List.fromList(img.encodePng(image, level: 6));
    return png.length <= j.maxBytes
        ? (problem: _Problem.none, bytes: png, mime: 'image/png', ext: '.png')
        : (problem: _Problem.tooLarge, bytes: null, mime: null, ext: null);
  }
  // One JPEG encode at the policy's quality; lower only if it must fit (and
  // only when compression is on: off keeps near-original quality).
  var q = j.compress ? j.quality : 95;
  while (true) {
    final jpg = Uint8List.fromList(img.encodeJpg(image, quality: q));
    if (jpg.length <= j.maxBytes) {
      return (problem: _Problem.none, bytes: jpg, mime: 'image/jpeg', ext: '.jpg');
    }
    if (!j.compress || q - 10 < _jpegFloor) {
      return (problem: _Problem.tooLarge, bytes: null, mime: null, ext: null);
    }
    q -= 10;
  }
}

/// "GreenRoot" at the bottom-right with a soft shadow (market ad photos).
void _drawWatermark(img.Image src) {
  const watermark = 'GreenRoot';
  final font = img.arial24;
  final textW = watermark.codeUnits
      .fold<int>(0, (w, c) => w + (font.characters[c]?.xAdvance ?? 0));
  final x = src.width - textW - 14;
  final y = src.height - font.lineHeight - 14;
  img.drawString(src, watermark,
      font: font, x: x + 1, y: y + 1, color: img.ColorRgba8(0, 0, 0, 110),);
  img.drawString(src, watermark,
      font: font, x: x, y: y, color: img.ColorRgba8(255, 255, 255, 200),);
}
