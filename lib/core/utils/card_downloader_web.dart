import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Saves [bytes] as a PNG download in the browser.
Future<void> platformDownloadImage(Uint8List bytes, String filename) async {
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: 'image/png'),
  );
  final url = web.URL.createObjectURL(blob);
  (web.document.createElement('a') as web.HTMLAnchorElement)
    ..href = url
    ..download = filename
    ..click();
  web.URL.revokeObjectURL(url);
}
