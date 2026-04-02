import 'dart:typed_data';

/// Web / unsupported: use [Printing.sharePdf] in the UI instead.
Future<String> saveJalPdfToLocalStorage(Uint8List bytes, String filename) async {
  throw UnsupportedError('PDF save to device is only available on mobile/desktop.');
}

Future<void> openJalLocalPdf(String path) async {}
