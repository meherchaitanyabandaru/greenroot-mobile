import 'dart:typed_data';
import 'card_downloader_stub.dart'
    if (dart.library.html) 'card_downloader_web.dart';

Future<void> downloadCardImage(Uint8List bytes, String filename) =>
    platformDownloadImage(bytes, filename);
