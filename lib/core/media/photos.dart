// Taking and preparing photos for upload, in one place:
// - opening the camera/gallery never crashes; the user is told why it failed;
// - only photos are accepted (checked from the file itself, so a video or
//   document renamed .jpg is refused);
// - big photos are shrunk before upload, small ones go as they are.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../theme/app_colors.dart';

/// Upload limit for photos (the API refuses more).
const maxPhotoUploadBytes = 10 * 1024 * 1024;

/// Anything this big is not a phone photo; refused before reading it.
const _maxPickedBytes = 40 * 1024 * 1024;

/// Photos up to this size are uploaded untouched (already compact).
const _keepAsIsBytes = 1024 * 1024;

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
/// and returns null. [maxSide]/[quality] ask the phone to shrink the photo
/// natively — only for screens that always want a small image (selfie, ads).
Future<XFile?> pickPhoto(
  BuildContext context,
  ImageSource source, {
  CameraDevice camera = CameraDevice.rear,
  double? maxSide,
  int? quality,
}) async {
  try {
    return await ImagePicker().pickImage(
      source: source,
      preferredCameraDevice: camera,
      maxWidth: maxSide,
      maxHeight: maxSide,
      imageQuality: quality,
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
  double? maxSide,
  int? quality,
}) async {
  try {
    final files = await ImagePicker().pickMultiImage(
      limit: limit < 2 ? null : limit,
      maxWidth: maxSide,
      maxHeight: maxSide,
      imageQuality: quality,
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

/// Checks [file] is a photo and makes it upload-ready. Photos up to 1 MB go
/// unchanged; bigger ones are turned upright, scaled so the longest side is at
/// most [maxSide] px and saved as JPEG 85 (PNG with transparency stays PNG).
/// On a phone screen the result looks the same. Throws [PhotoRejected].
Future<PreparedPhoto> preparePhoto(XFile file, {int maxSide = 2048}) async {
  if (await file.length() > _maxPickedBytes) {
    throw const PhotoRejected('This file is too large. Please choose a photo.');
  }
  final original = await file.readAsBytes();
  final type = photoType(original);
  if (type == null) {
    throw PhotoRejected(
      _looksLikeVideo(original)
          ? "Videos can't be uploaded. Please choose a photo."
          : 'Only photos can be uploaded (JPG, PNG, WebP or HEIC).',
    );
  }
  if (original.length <= _keepAsIsBytes) {
    return PreparedPhoto(original, type.mime, type.ext);
  }

  final shrunk = await compute(_shrink, (original, maxSide));
  if (shrunk != null && shrunk.bytes.length < original.length) {
    return PreparedPhoto(shrunk.bytes, shrunk.mime, shrunk.ext);
  }
  // Undecodable here (e.g. HEIC) or no smaller: send as is if allowed.
  if (original.length > maxPhotoUploadBytes) {
    throw const PhotoRejected(
      'This photo is too large (max 10 MB). Please choose a smaller one.',
    );
  }
  return PreparedPhoto(original, type.mime, type.ext);
}

typedef _Shrunk = ({Uint8List bytes, String mime, String ext});

_Shrunk? _shrink((Uint8List, int) args) {
  final (bytes, maxSide) = args;
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  var image =
      img.bakeOrientation(decoded); // camera photos are often stored sideways
  final longest = image.width > image.height ? image.width : image.height;
  if (longest > maxSide) {
    image = image.width >= image.height
        ? img.copyResize(
            image,
            width: maxSide,
            interpolation: img.Interpolation.average,
          )
        : img.copyResize(
            image,
            height: maxSide,
            interpolation: img.Interpolation.average,
          );
  }
  if (image.hasAlpha && photoType(bytes)?.mime == 'image/png') {
    return (
      bytes: Uint8List.fromList(img.encodePng(image, level: 6)),
      mime: 'image/png',
      ext: '.png'
    );
  }
  return (
    bytes: Uint8List.fromList(img.encodeJpg(image, quality: 85)),
    mime: 'image/jpeg',
    ext: '.jpg'
  );
}
