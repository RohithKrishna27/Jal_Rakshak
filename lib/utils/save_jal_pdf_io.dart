import 'dart:io';
import 'dart:typed_data';

import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

/// Saves the PDF to device storage: prefers **Downloads/JalRakshak/reports/** when
/// the OS allows writing there; otherwise **app documents** (always allowed, no
/// extra permissions on modern Android/iOS).
Future<String> saveJalPdfToLocalStorage(Uint8List bytes, String filename) async {
  var safe = filename.replaceAll(RegExp(r'[^\w\-.]+'), '_');
  if (!safe.toLowerCase().endsWith('.pdf')) {
    safe = '$safe.pdf';
  }

  Future<String> writeUnder(Directory base) async {
    final dir = Directory('${base.path}/JalRakshak/reports');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final file = File('${dir.path}/$safe');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  try {
    final downloads = await getDownloadsDirectory();
    if (downloads != null) {
      return await writeUnder(downloads);
    }
  } catch (_) {}

  final root = await getApplicationDocumentsDirectory();
  return await writeUnder(root);
}

/// Opens the saved file with the system viewer (PDF app).
Future<void> openJalLocalPdf(String path) async {
  await OpenFile.open(path);
}
